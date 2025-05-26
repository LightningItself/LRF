#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_printf.h"

//tcp includes
#include "lwip/sockets.h"
#include "lwip/inet.h"
#include "lwip/netdb.h"

#define IMAGE_DIM 512
#define FRAME_SIZE_BYTES (IMAGE_DIM * IMAGE_DIM)
#define NUM_FRAMES 31
#define FRAMES_PER_FUSION 16
#define DDR_BASE_ADDR 0x10000000  // base address in DDR for frame buffers

#define TCP_PORT 5001
#define MAX_CLIENTS 1

typedef struct {
    XAxiDma dma_inst;
    void* fused_frame_buffer;
} FusionSystem_t;

FusionSystem_t fusion_sys;

int server_sock = -1, client_sock = -1;

// ----------------- DMA ------------------------

static inline void* get_frame_ptr(int index) {
    return (void*)(DDR_BASE_ADDR + (index * FRAME_SIZE_BYTES));
}

int fusion_system_init(int dma_device_id) {
    XAxiDma_Config *cfg;
    int status;

    cfg = XAxiDma_LookupConfig(dma_device_id);
    if (!cfg) {
        xil_printf("No DMA config found.\n");
        return -1;
    }

    status = XAxiDma_CfgInitialize(&fusion_sys.dma_inst, cfg);
    if (status != XST_SUCCESS) {
        xil_printf("DMA init failed.\n");
        return -1;
    }

    if (XAxiDma_HasSg(&fusion_sys.dma_inst)) {
        xil_printf("SG mode not supported.\n");
        return -1;
    }

    XAxiDma_IntrDisable(&fusion_sys.dma_inst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&fusion_sys.dma_inst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    fusion_sys.fused_frame_buffer = malloc(FRAME_SIZE_BYTES);
    if (!fusion_sys.fused_frame_buffer) {
        xil_printf("Failed to allocate fused frame buffer\n");
        return -1;
    }

    return 0;
}

static inline int old_frame_index(int new_idx) {
    int old_idx = new_idx - FRAMES_PER_FUSION;
    return (old_idx < 0) ? 0 : old_idx;
}

int send_frame_via_dma(void* frame_addr) {
    Xil_DCacheFlushRange((UINTPTR)frame_addr, FRAME_SIZE_BYTES);
    int status = XAxiDma_SimpleTransfer(&fusion_sys.dma_inst, (UINTPTR)frame_addr, FRAME_SIZE_BYTES, XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("Failed to start DMA MM2S\n");
        return -1;
    }
    while (XAxiDma_Busy(&fusion_sys.dma_inst, XAXIDMA_DMA_TO_DEVICE)) {}
    return 0;
}

int receive_fused_frame_via_dma() {
    Xil_DCacheInvalidateRange((UINTPTR)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES);
    int status = XAxiDma_SimpleTransfer(&fusion_sys.dma_inst, (UINTPTR)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES, XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        xil_printf("Failed to start DMA S2MM\n");
        return -1;
    }
    while (XAxiDma_Busy(&fusion_sys.dma_inst, XAXIDMA_DEVICE_TO_DMA)) {}
    return 0;
}

// ----------------- TCP ------------------------

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

    xil_printf("Waiting for client connection...\n");
    client_sock = lwip_accept(server_sock, (struct sockaddr*)&client_addr, (socklen_t*)&addr_len);
    if (client_sock < 0) {
        xil_printf("TCP accept failed\n");
        return -1;
    }

    xil_printf("Client connected\n");
    return 0;
}

int tcp_receive_frame(unsigned char* dst, int len) {
    int received = 0;
    while (received < len) {
        int ret = lwip_recv(client_sock, dst + received, len - received, 0);
        if (ret <= 0) {
            xil_printf("TCP recv error or client disconnected\n");
            return -1;
        }
        received += ret;
    }
    return 0;
}

int tcp_send_frame(unsigned char* src, int len) {
    int sent = 0;
    while (sent < len) {
        int ret = lwip_send(client_sock, src + sent, len - sent, 0);
        if (ret <= 0) {
            xil_printf("TCP send error or client disconnected\n");
            return -1;
        }
        sent += ret;
    }
    return 0;
}

// ----------------- Main Logic ------------------------

void fusion_system() {
    int fusion_cnt = 0;
    int frame_cnt = 0;

    xil_printf("Starting fusion system...\n");

    while (1) {
        for (int pair_idx = 0; pair_idx < FRAMES_PER_FUSION; pair_idx++) {
            int new_idx = fusion_cnt + pair_idx;
            int old_idx = old_frame_index(new_idx);

            void* new_frame_ptr = get_frame_ptr(new_idx % NUM_FRAMES);
            void* old_frame_ptr = get_frame_ptr(old_idx % NUM_FRAMES);

            if (send_frame_via_dma(new_frame_ptr) != 0) return;
            if (send_frame_via_dma(old_frame_ptr) != 0) return;

            if (fusion_cnt > 15) {
                int overwrite_idx = (new_idx - FRAMES_PER_FUSION) % NUM_FRAMES;
                void* overwrite_ptr = get_frame_ptr(overwrite_idx);
                if (tcp_receive_frame((unsigned char*)overwrite_ptr, FRAME_SIZE_BYTES) != 0) {
                    xil_printf("TCP receive failed at %d\n", overwrite_idx);
                    return;
                }
            }

            frame_cnt += 2;
        }

        fusion_cnt++;
        if (fusion_cnt >= NUM_FRAMES) fusion_cnt = 0;

        if (receive_fused_frame_via_dma() != 0) return;

        if (tcp_send_frame((unsigned char*)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES) != 0) {
            xil_printf("Failed to send fused frame\n");
            return;
        }
    }
}

int main() {
    xil_printf("Initializing system...\n");

    if (tcp_init() != 0) {
        xil_printf("TCP init failed\n");
        return -1;
    }

    if (fusion_system_init(XPAR_AXIDMA_0_DEVICE_ID) != 0) {
        xil_printf("DMA init failed\n");
        return -1;
    }

    fusion_system();
    return 0;
}