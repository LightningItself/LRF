#include <stdio.h>
#include <string.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xaxidma.h"
#include <stdlib.h>
#include "lwip/err.h"
#include "lwip/tcp.h"
#include "netif/xadapter.h"
#include "sleep.h"
#if defined (__arm__) || defined (__aarch64__)
#include "xil_printf.h"
#endif
extern struct netif *echo_netif;
extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
#define IMAGE_DIM           512
#define FRAME_SIZE_BYTES    (IMAGE_DIM * IMAGE_DIM)
#define NUM_FRAMES          300
#define FRAMES_PER_FUSION   16
#define DDR_BASE_ADDR       0x10000000
#define FUSED_FRAME_ADDR    (DDR_BASE_ADDR + (NUM_FRAMES * FRAME_SIZE_BYTES))
#define TCP_PORT            5001
#define TCP_CHUNK_SIZE      8192
struct tcp_pcb *client_pcb;
typedef struct {
    XAxiDma dma_inst;
    void* fused_frame_buffer;
} FusionSystem_t;
FusionSystem_t fusion_sys;
volatile int frame_count = 0;
volatile int bytes_received = 0;
volatile int all_frames_received = 0;
volatile int total_bytes_received = 0;
static int i = 0;
volatile int number = 0;  
static int status = 0;
XTime t1, t2;
static inline void* get_frame_ptr(int index) {
    return (void *)(DDR_BASE_ADDR + (index * FRAME_SIZE_BYTES));
}
static inline void* get_DDR_ptr(int total_bytes_recv) {
    return (void *)(DDR_BASE_ADDR + total_bytes_recv);
}
static inline int old_frame_index(int new_idx) {
    int old_idx = new_idx - FRAMES_PER_FUSION;
    return (old_idx < 0) ? 0 : old_idx;
}
int dma_init()
{
    XAxiDma_Config *cfg;
    int Status;
    cfg = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_BASEADDR);
    if (cfg == NULL) {
        xil_printf("Lookup failed\r\n");
        return -1;
    }
    Status = XAxiDma_CfgInitialize(&fusion_sys.dma_inst, cfg);
    if (Status != XST_SUCCESS) return -1;
    if (XAxiDma_HasSg(&fusion_sys.dma_inst)) {
        xil_printf("SG mode!\r\n");
        return -1;
    }
    fusion_sys.fused_frame_buffer = (void *)FUSED_FRAME_ADDR;
    if (fusion_sys.fused_frame_buffer == NULL) {
        xil_printf("failed in allocation\r\n");
        return -1;
    }
    return 0;
}
int send_frame_via_dma_polling(void *frame_addr)
{
    Xil_DCacheFlushRange((UINTPTR)frame_addr, FRAME_SIZE_BYTES);
    int Status = XAxiDma_SimpleTransfer(&fusion_sys.dma_inst, (UINTPTR)frame_addr, FRAME_SIZE_BYTES,XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("send_frame_via_dma_polling: SimpleTransfer failed\r\n");
        return -1;
    }
    while (XAxiDma_Busy(&fusion_sys.dma_inst, XAXIDMA_DMA_TO_DEVICE));
    return 0;
}
int receive_fused_frame_via_dma_polling() {
    Xil_DCacheInvalidateRange((UINTPTR)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES);
    if (XAxiDma_SimpleTransfer(&fusion_sys.dma_inst, (UINTPTR)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        xil_printf("receive_fused_frame_via_dma_polling: SimpleTransfer failed\r\n");
        return -1;
    }
    while (XAxiDma_Busy(&fusion_sys.dma_inst, XAXIDMA_DEVICE_TO_DMA));
    if(number == 0) {
        XTime_GetTime(&t1);
    }
    number++;
    if(number == (NUM_FRAMES-FRAMES_PER_FUSION+1)) {
        XTime_GetTime(&t2);
    }
    return 0;
}
int tcp_send_frame(unsigned char *frame, int len)
{
    int offset = 0;
    err_t err;
    if (client_pcb == NULL) {
        xil_printf("tcp_send_frame: client_pcb is NULL\r\n");
        return -1;
    }
    while (offset < len) {
        int chunk = len - offset;
        if (chunk > TCP_CHUNK_SIZE) chunk = TCP_CHUNK_SIZE;
        while (tcp_sndbuf(client_pcb) < chunk) {
            xemacif_input(echo_netif); /* Keep TCP alive while waiting for buffer space */
        }
        err = tcp_write(client_pcb, frame + offset, chunk, TCP_WRITE_FLAG_COPY);
        if (err != ERR_OK) {
            xil_printf("tcp_write failed (%d)\r\n", err);
            return -1;
        }
        tcp_output(client_pcb);
        offset += chunk;
    }
    return 0;
}
void fusion_system_polling(void)
{
    int new_idx, old_idx;
    void* new_frame;
    void* old_frame;
    int fusion_count = 0;
    xil_printf("--- Beginning Fusion DMA Transfers ---\r\n");
    for(i = 0; i < (NUM_FRAMES-FRAMES_PER_FUSION+1); i++) {
        for(int j = 0; j <= FRAMES_PER_FUSION; j++) {
            new_idx = i+j;
            old_idx = old_frame_index(i);
            new_frame = get_frame_ptr(new_idx);
            old_frame = get_frame_ptr(old_idx);
            if(j < FRAMES_PER_FUSION) {
                if (send_frame_via_dma_polling(new_frame) != 0) {
                    xil_printf("DMA MM2S failed on new frame %d\r\n", new_idx);
                    return;
                }
                xil_printf("DMA MM2S success on new frame %d\r\n", new_idx);
            }
            else if(j == FRAMES_PER_FUSION) {
                if (send_frame_via_dma_polling(old_frame) != 0) {
                    xil_printf("DMA MM2S failed on old frame %d\r\n", old_idx);
                    return;
                }
                xil_printf("DMA MM2S success on old frame %d\r\n", old_idx);
                if (receive_fused_frame_via_dma_polling() != 0) {
                    xil_printf("DMA S2MM failed on fusion %d\r\n", fusion_count);
                    return;
                }
                if (tcp_send_frame((unsigned char *)fusion_sys.fused_frame_buffer, FRAME_SIZE_BYTES) != 0) {
                    xil_printf("TCP send failed on fusion %d\r\n", fusion_count);
                    return;
                }
                xil_printf("Fusion %d complete and sent.\r\n", fusion_count);
                fusion_count++;
            }
        }
    }
    xil_printf("--- All Fusion Processing Complete ---\r\n");
    double elpased_cycles = (double) (t2-t1);
    double elapsed_seconds = (double)(t2-t1) / (double)COUNTS_PER_SECOND;
    double elapsed_us = elapsed_seconds * 1000000.0;
    double avg_period_us = elapsed_us / (double)(NUM_FRAMES - FRAMES_PER_FUSION);
    double throughput_Bps = FRAME_SIZE_BYTES / (avg_period_us / 1000000.0);
    xil_printf("Elapsed cycles: %lu\r\n", (unsigned long)elapsed_cycles);
    xil_printf("Avg period per fusion: %.2f us\r\n", avg_period_us);
    xil_printf("Avg throughput: %.4f MB/s\r\n", throughput_Bps / 1000000.0);
}
int transfer_data() {
    static int init_start = 0;
    if((!init_start) && all_frames_received) {
        if (dma_init() != 0) {
            xil_printf("DMA Init failed\r\n");
            return -1;
        }
        init_start = 1;
        fusion_system_polling();
    }
    return 0;
}
void print_app_header()
{
    xil_printf("\n\r\n\r----- Fusion Application ------\n\r");
    xil_printf("Waiting for %d frames on port %d...\n\r", NUM_FRAMES, TCP_PORT);
}
err_t recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
    struct pbuf *q;
    unsigned char *ddr_ptr;
    if (!p) {
        xil_printf("recv_callback: connection closed by peer\r\n");
        tcp_close(tpcb);
        tcp_recv(tpcb, NULL);
        return ERR_OK;
    }
    if (all_frames_received) {
        tcp_recved(tpcb, p->tot_len);
        pbuf_free(p);
        return ERR_OK;
    }
    for (q = p; q != NULL; q = q->next) {
        ddr_ptr = (unsigned char *)get_DDR_ptr(total_bytes_received);
        memcpy(ddr_ptr, q->payload, q->len);
        total_bytes_received += q->len;
        bytes_received += q->len;
        while (bytes_received >= FRAME_SIZE_BYTES) {
            bytes_received -= FRAME_SIZE_BYTES;
            frame_count++;
            xil_printf("Stored Frame %d/%d\r\n", frame_count, NUM_FRAMES);
            if (frame_count >= NUM_FRAMES) {
                xil_printf("All %d frames received. Starting Fusion...\r\n", NUM_FRAMES);
                all_frames_received = 1;
                tcp_recv(tpcb, NULL);
                break;
            }
        }
        if (all_frames_received) break;
    }
    tcp_recved(tpcb, p->tot_len);
    pbuf_free(p);
    return ERR_OK;
}
err_t accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
    xil_printf("Client connected\r\n");
    client_pcb = newpcb;
    tcp_recv(client_pcb, recv_callback);
    xil_printf("Passed recv_callback\r\n");
    return ERR_OK;
}
int start_application()
{
    struct tcp_pcb *server_pcb;
    err_t err;
    unsigned port = 5001;
    server_pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
    if (!server_pcb) {  
        xil_printf("Error creating PCB.\r\n");
        return -1;
    }
    xil_printf("Created PCB\r\n");
    err = tcp_bind(server_pcb, IP_ANY_TYPE, port);
    if (err != ERR_OK) {
        xil_printf("Unable to bind to port %d: err = %d\n\r", port, err);
        return -2;
    }
    xil_printf("Binding Done\r\n");
    tcp_arg(server_pcb, NULL);
    server_pcb = tcp_listen(server_pcb);
    if (!server_pcb) {
        xil_printf("tcp_listen failed\r\n");
        return -3;
    }
    xil_printf("Listen\r\n");    
    tcp_accept(server_pcb, accept_callback);
    xil_printf("Passed accept_callback\r\n");  
    return 0;
}