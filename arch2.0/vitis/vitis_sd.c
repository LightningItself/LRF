#include <stdio.h>
#include <string.h>
#include "sleep.h"
#include <stdint.h>
#include "lwip/err.h"
#include "lwip/tcp.h"
#if defined (__arm__) || defined (__aarch64__)
#include "xil_printf.h"
#endif


#include "xaxidma.h"
#include "xparameters.h"
#include "xil_cache.h"
#include "xaxidma_hw.h"


#define IMAGE_SIZE     (520 * 520)
#define NUM_IMAGES     17

#define DDR_BASE_ADDR  ((volatile uint8_t *)0x01000000)
#define AVG_IMAGE_ADDR (volatile uint8_t *)(DDR_BASE_ADDR + (NUM_IMAGES * IMAGE_SIZE))
#define FUSED_IMAGE_ADDR  (volatile uint8_t *)(AVG_IMAGE_ADDR + IMAGE_SIZE)
#define PACKED_BUFFER_ADDR (volatile uint8_t *)(FUSED_IMAGE_ADDR + IMAGE_SIZE )  // Align to 4 bytes
#define UNPACKED_BUFFER_ADDR (volatile uint8_t *)(PACKED_BUFFER_ADDR + (4 * IMAGE_SIZE) )  // Align to 4 bytes

XAxiDma AxiDma;

volatile int avg_done = 0;
volatile int new_index = 0;
volatile int old_index = 0;
volatile int processing_done = 0;
volatile int fused_count = 0;       // Tracks the number of fused images
volatile int final_fused_ready = 0; // Set to 1 when all 16 images are fused
uint32_t pixel_index; 
uint32_t tx_buffer; // Buffer to store packed pixels
uint16_t rx_buffer; // Buffer to store received pixels
uint8_t avg_pixel;
uint8_t fused_pixel;
struct tcp_pcb *global_tpcb = NULL;  // Add this at the top


err_t send_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) {
    static int sentSize = 0;
    int size;
    static char *bufferPntr = (char *)(FUSED_IMAGE_ADDR); 

    if (final_fused_ready) {
            size = (IMAGE_SIZE - sentSize >= tcp_sndbuf(tpcb)) ? tcp_sndbuf(tpcb) : (IMAGE_SIZE - sentSize);
            
            if (size == 0) {
            xil_printf("TCP buffer full! Waiting...\n\r");
             return ERR_OK;
            }
 
            err = tcp_write(tpcb, (void *)bufferPntr, size, 1);
            if (err != ERR_OK) {
               xil_printf("tcp_write failed: err = %d\n\r", err);
               return err;
            }
          
            tcp_output(tpcb);  // Immediately send the data

            bufferPntr += size;
            sentSize += size;
            
        if (sentSize == IMAGE_SIZE) {
            xil_printf("Processed image sent successfully!\n\r");
            final_fused_ready = 0; // Reset flag after sending
            sentSize = 0;
            bufferPntr = (char *)(FUSED_IMAGE_ADDR);
            
        }
    }
    return ERR_OK;
}

// void compute_and_store_average() {
    

//     for (pixel_index = 0; pixel_index < IMAGE_SIZE; pixel_index++) {
//          uint32_t sum = 0;

//         for (int sum_index = 0; sum_index < 16; sum_index++) {
//              volatile uint8_t  *img_addr = (volatile uint8_t *) (DDR_BASE_ADDR + (sum_index * IMAGE_SIZE));
//              sum += *(img_addr + pixel_index);   // Read 8-bit pixel

//         }

//         *((volatile uint8_t *)(AVG_IMAGE_ADDR + pixel_index)) = (sum >> 4);   // Store in DDR
       
//     }
//     avg_done = 1;
//     xil_printf("avg_done %d\n\r", avg_done );
//     memcpy((void *)FUSED_IMAGE_ADDR, (void *)(AVG_IMAGE_ADDR - 2*IMAGE_SIZE), IMAGE_SIZE);    // 16th image is stored as first fused image 
// }

void dma_transfer() {

    xil_printf("new index %d\n\r", new_index );
    xil_printf("old index %d\n\r", old_index );
    

    for(pixel_index = 0; pixel_index < IMAGE_SIZE; pixel_index++) {
       // Compute addresses
        UINTPTR avg_addr   = (UINTPTR)AVG_IMAGE_ADDR + pixel_index;
        UINTPTR new_addr   = (UINTPTR)DDR_BASE_ADDR + ((new_index )* IMAGE_SIZE) + pixel_index;
        UINTPTR fused_addr = (UINTPTR)FUSED_IMAGE_ADDR + pixel_index;
        UINTPTR old_addr   = (UINTPTR)DDR_BASE_ADDR + (old_index * IMAGE_SIZE) + pixel_index;
        UINTPTR tx_buffer_addr  = (UINTPTR)(PACKED_BUFFER_ADDR + (4 * pixel_index)); // Buffer to store packed pixels

       // Read pixels from DDR
        uint8_t avg_pixel   = Xil_In8(avg_addr);
        uint8_t new_pixel   = Xil_In8(new_addr);
        uint8_t fused_pixel = Xil_In8(fused_addr);
        uint8_t old_pixel   = Xil_In8(old_addr);
        
        // Pack 4 pixels into a 32-bit word
        tx_buffer = (old_pixel << 24) | (fused_pixel << 16) | (new_pixel << 8) | avg_pixel;
		
         // Store packed data in DDR
        Xil_Out32((UINTPTR)(tx_buffer_addr), tx_buffer);   
        if (pixel_index == 0 || pixel_index == IMAGE_SIZE - 1) {
         xil_printf(" tx_buffer: 0x%08X\n\r",  tx_buffer);
         xil_printf("Data: 0x%08X\r\n", *((volatile uint32_t*)PACKED_BUFFER_ADDR));     
        }  
                      
    }
    
    Xil_DCacheFlushRange((UINTPTR)PACKED_BUFFER_ADDR, 4*IMAGE_SIZE);
    Xil_DCacheFlushRange((UINTPTR)UNPACKED_BUFFER_ADDR, 4*IMAGE_SIZE);

    
    // Start DMA transfers
    int status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)UNPACKED_BUFFER_ADDR, 4*IMAGE_SIZE, XAXIDMA_DEVICE_TO_DMA);
        if (status != XST_SUCCESS) {
           xil_printf("Device to DMA transfer failed\n\r");
        } 
       
    
    status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)PACKED_BUFFER_ADDR, 4*IMAGE_SIZE, XAXIDMA_DMA_TO_DEVICE);
        if (status != XST_SUCCESS) {
           xil_printf("DMA to Device transfer failed\n\r");
        } 

        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE));
         xil_printf("DMA_TO_DEVICE completed.\n\r");

        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA));
         xil_printf("DEVICE_TO_DMA completed.\n\r");
 
      
      
       // Step 7: Invalidate the output buffer after DMA completes
     Xil_DCacheInvalidateRange((UINTPTR)UNPACKED_BUFFER_ADDR, 4 * IMAGE_SIZE);
     xil_printf("fused count %d\n\r", fused_count);

    // Process received data    
    for (pixel_index = 0; pixel_index < IMAGE_SIZE; pixel_index++) {
       
       UINTPTR  rx_buffer_addr  = (UINTPTR)(UNPACKED_BUFFER_ADDR + (4*pixel_index)); // Buffer to store packed pixels
        
        // Store packed data in DDR
       // Xil_Out32((UINTPTR)(rx_buffer_addr), rx_buffer);  
        rx_buffer = Xil_In32((UINTPTR)(rx_buffer_addr)); 

        if (pixel_index == 0 || pixel_index == IMAGE_SIZE - 1) {
         xil_printf("rx_buffer: 0x%08X\n\r",  rx_buffer);
         xil_printf("Data: 0x%08X\r\n", *((volatile uint32_t*)UNPACKED_BUFFER_ADDR));     
        }  

        // Extract pixels
        avg_pixel = (rx_buffer >> 8) & 0xFF;  // Extract MSB (average pixel)
        fused_pixel = rx_buffer & 0xFF;       // Extract LSB (fused pixel)
        
        // Write back results to DDR
        Xil_Out8((UINTPTR)(AVG_IMAGE_ADDR + pixel_index), avg_pixel);
        Xil_Out8((UINTPTR)(FUSED_IMAGE_ADDR + pixel_index), fused_pixel);
        
    }
    processing_done = 1;  // Processing complete
    
    old_index = (old_index + 1) % (NUM_IMAGES );   
    fused_count++;
    
   
    
	// Once 16 images are fused, set the flag to send the final result
    if (fused_count == 16) {
        final_fused_ready = 1;
        xil_printf("final_fused_ready %d\n\r",final_fused_ready);
        fused_count = 0; // Reset for next cycle
        if (global_tpcb) {
           send_callback(NULL, global_tpcb, NULL, ERR_OK);  
        }

    }
}

err_t recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) {
    static int receivedBytes = 0;
    static int image_count = 0;  // Track total images received
    
    static char *buffPntr = (char *)(DDR_BASE_ADDR ); 
    if (!p) {  
        tcp_close(tpcb);
        tcp_recv(tpcb, NULL);
        return ERR_OK;
    }

   
    int remaining_space = IMAGE_SIZE - receivedBytes;
    int bytes_to_copy = (p->len > remaining_space) ? remaining_space : p->len;
    
    

    memcpy((void *)buffPntr, (void *)(p->payload), bytes_to_copy);   
    receivedBytes += bytes_to_copy;
    
    buffPntr += bytes_to_copy; // Move forward correctly
    
    
    if (receivedBytes == IMAGE_SIZE) {
    xil_printf("new index %d\n\r", new_index ); 
    new_index = (new_index + 1) % (NUM_IMAGES);
    image_count++;
    receivedBytes = 0;
    buffPntr = (char *)(DDR_BASE_ADDR + (new_index * IMAGE_SIZE));

    
    tcp_write(tpcb, "ACK", 3, TCP_WRITE_FLAG_COPY);
    tcp_output(tpcb);
    fflush(stdout);     
   
    if (image_count == 16 && !avg_done) {
       compute_and_store_average();
       
    }
    if (avg_done )  {
       dma_transfer();
    }

  }
    
   
    tcp_recved(tpcb, p->len);
    pbuf_free(p);
    return ERR_OK;
    
}
    

err_t accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err) {
    static int connection = 1;
    global_tpcb = newpcb;  // Store the TCP connection globally
    tcp_recv(newpcb, recv_callback);
    tcp_sent(newpcb, send_callback);
    tcp_arg(newpcb, (void *)(UINTPTR)connection);
    connection++;
    return ERR_OK;
}

void print_app_header() {
    xil_printf("\n\r-----lwIP TCP Server------\n\r");
    xil_printf("TCP packets sent to port 6641 will be processed and responded.\n\r");
}

int start_application() {
    int status;
    
        XAxiDma_Config *AxiDmaConfig;
        AxiDmaConfig = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_BASEADDR);
     if (!AxiDmaConfig) {
        xil_printf("Error: DMA config not found\n\r");
        return -1;
      }


    status = XAxiDma_CfgInitialize(&AxiDma, AxiDmaConfig);
      if (status != XST_SUCCESS) {
           xil_printf("DMA initialization failed...\n\r");
           return -1;
       }
    xil_printf("DMA initialization success...\n\r");

     
    struct tcp_pcb *pcb;
    err_t err;
    unsigned port = 6001;

    pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
    if (!pcb) {
        xil_printf("Error creating PCB. Out of Memory\n\r");
        return -2;
    }

    err = tcp_bind(pcb, IP_ANY_TYPE, port);
    if (err != ERR_OK) {
        xil_printf("Unable to bind to port %d: err = %d\n\r", port, err);
        tcp_close(pcb);
        return -3;
    }

    tcp_arg(pcb, NULL);
    pcb = tcp_listen(pcb);
    if (!pcb) {
        xil_printf("Out of memory while tcp_listen\n\r");
        return -4;
    }

    tcp_accept(pcb, accept_callback);
    xil_printf("TCP image processing server started @ port %d\n\r", port);
    return 0;
}