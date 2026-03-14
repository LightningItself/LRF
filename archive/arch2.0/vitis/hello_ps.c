#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xaxidma.h"
#include "xscugic.h"
#include "xil_exception.h"

#include "lwip/sockets.h"
#include "lwip/inet.h"
#include "lwip/netdb.h"
#include "netif/xadapter.h"

#define IMAGE_DIM           512
#define FRAME_SIZE_BYTES    (IMAGE_DIM * IMAGE_DIM)
#define NUM_FRAMES          31
#define FRAMES_PER_FUSION   16
#define DDR_BASE_ADDR       0x10000000

#define TCP_PORT            5001
#define MAX_CLIENTS         1

typedef struct {
    XAxiDma dma_inst;
    void* fused_frame_buffer;
} FusionSystem_t;

FusionSystem_t fusion_sys;
XScuGic Intc;

// TCP
int server_sock = -1, client_sock = -1;

volatile int mm2s_done = 0;
volatile int s2mm_done = 0;

static inline void* get_frame_ptr(int index) {
    return (void*)(DDR_BASE_ADDR + (index * FRAME_SIZE_BYTES));
}

static inline int old_frame_index(int new_idx) {
    int old_idx = new_idx - FRAMES_PER_FUSION;
    return (old_idx < 0) ? 0 : old_idx;
}

void dma_mm2s_isr(void *Callback) {
    XAxiDma *dma = (XAxiDma *)Callback;
    u32 status = XAxiDma_IntrGetIrq(dma, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrAckIrq(dma, status, XAXIDMA_DMA_TO_DEVICE);
    if (status & XAXIDMA_IRQ_IOC_MASK) mm2s_done = 1;
    if (status & XAXIDMA_IRQ_ERROR_MASK) xil_printf("MM2S error\n");
}

void dma_s2mm_isr(void *Callback) {
    XAxiDma *dma = (XAxiDma *)Callback;
    u32 status = XAxiDma_IntrGetIrq(dma, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq(dma, status, XAXIDMA_DEVICE_TO_DMA);
    if (status & XAXIDMA_IRQ_IOC_MASK) s2mm_done = 1;
    if (status & XAXIDMA_IRQ_ERROR_MASK) xil_printf("S2MM error\n");
}

int dma_init_interrupt(int dma_id) {
    XAxiDma_Config *cfg = XAxiDma_LookupConfig(dma_id);
    if (!cfg) return -1;
    if (XAxiDma_CfgInitialize(&fusion_sys.dma_inst, cfg) != XST_SUCCESS) return -1;
    if (XAxiDma_HasSg(&fusion_sys.dma_inst)) return -1;

    fusion_sys.fused_frame_buffer = malloc(FRAME_SIZE_BYTES);
    if (!fusion_sys.fused_frame_buffer) return -1;

    return 0;
}

int setup_interrupts(XScuGic *IntcPtr, XAxiDma *dma) {
    XScuGic_Config *CfgPtr = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    if (!CfgPtr) return -1;

    XScuGic_CfgInitialize(IntcPtr, CfgPtr, CfgPtr->CpuBaseAddress);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 IntcPtr);
    Xil_ExceptionEnable();

    XScuGic_Connect(IntcPtr, XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_INTR,
                    (Xil_InterruptHandler)dma_mm2s_isr, dma);
    XScuGic_Connect(IntcPtr, XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_INTR,
                    (Xil_InterruptHandler)dma_s2mm_isr, dma);

    XScuGic_Enable(IntcPtr, XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_INTR);
    XScuGic_Enable(IntcPtr, XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_INTR);

    XAxiDma_IntrEnable(dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrEnable(dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    return 0;
}

int tcp_init() {
    struct sockaddr_in server_addr, client_addr;
    int addr_len = sizeof(client_addr);

    server_sock = lwip_socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock < 0) {
        xil_printf("TCP socket create failed\n");
        return -1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(TCP_PORT);
    server_addr.sin_addr.s_addr = INADDR_ANY;

    if (lwip_bind(server_sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        xil_printf("TCP bind failed\n");
        return -1;
    }

    if (lwip_listen(server_sock, MAX_CLIENTS) < 0) {
        xil_printf("TCP listen failed\n");
        return -1;
    }

    xil_printf("Waiting for TCP client...\n");
    client_sock = lwip_accept(server_sock, (struct sockaddr*)&client_addr, (socklen_t*)&addr_len);
    if (client_sock < 0) {
        xil_printf("TCP accept failed\n");
        return -1;
    }

    xil_printf("TCP client connected\n");
    return 0;
}

int tcp_receive_frame(unsigned char* dst, int len) {
    int received = 0;
    while (received < len) {
        int ret = lwip_recv(client_sock, dst + received, len - received, 0);
        if (ret <= 0) return -1;
        received += ret;
    }
    return 0;
}

int tcp_send_frame(unsigned char* src, int len) {
    int sent = 0;
    while (sent < len) {
        int ret = lwip_send(client_sock, src + sent, len - sent, 0);
        if (ret <= 0) return -1;
        sent += ret;
    }
    return 0;
}

int send_frame_via_dma_interrupt(void* frame_addr) {
    Xil_DCacheFlushRange((UINTPTR)frame_addr, FRAME_SIZE_BYTES);
    mm2s_done = 0;
    if (XAxiDma_SimpleTransfer(&fusion_sys.dma_inst, (UINTPTR)frame_addr,
        FRAME_SIZE_BYTES, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) return -1;
    while (!mm2s_done);
    return 0;
}

int receive_fused_frame_via_dma_interrupt() {
    Xil_DCacheInvalidateRange((UINTPTR)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES);
    s2mm_done = 0;
    if (XAxiDma_SimpleTransfer(&fusion_sys.dma_inst, (UINTPTR)fusion_sys.fused_frame_buffer,
        FRAME_SIZE_BYTES, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) return -1;
    while (!s2mm_done);
    return 0;
}

void fusion_system_interrupt() {
    int fusion_cnt = 0;

    while (1) {
        if (receive_fused_frame_via_dma_interrupt() != 0) return;

        for (int i = 0; i < FRAMES_PER_FUSION; i++) {
            int new_idx = fusion_cnt + i;
            int old_idx = old_frame_index(new_idx);

            void* new_frame = get_frame_ptr(new_idx % NUM_FRAMES);
            void* old_frame = get_frame_ptr(old_idx % NUM_FRAMES);

            if (send_frame_via_dma_interrupt(old_frame) != 0) return;
            if (send_frame_via_dma_interrupt(new_frame) != 0) return;

            // Overwrite logic
            if (fusion_cnt >= FRAMES_PER_FUSION) {
                int overwrite_idx = (new_idx - FRAMES_PER_FUSION) % NUM_FRAMES;
                void* overwrite_ptr = get_frame_ptr(overwrite_idx);
                if (tcp_receive_frame((unsigned char*)overwrite_ptr, FRAME_SIZE_BYTES) != 0) {
                    xil_printf("TCP receive failed\n");
                    return;
                }
            }
        }

        if (tcp_send_frame((unsigned char*)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES) != 0) {
            xil_printf("TCP send failed\n");
            return;
        }

        fusion_cnt++;
        if (fusion_cnt >= NUM_FRAMES) fusion_cnt = 0;
    }
}

int main() {
    xil_printf("System Init\n");

    if (tcp_init() != 0) return -1;
    if (dma_init_interrupt(XPAR_AXIDMA_0_DEVICE_ID) != 0) return -1;
    if (setup_interrupts(&Intc, &fusion_sys.dma_inst) != 0) return -1;

    fusion_system_interrupt();
    return 0;
}