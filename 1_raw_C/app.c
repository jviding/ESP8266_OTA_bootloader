#include <stdint.h>

// Inline to avoid a new call frame and memory corruption
static inline __attribute__((always_inline)) void wait() { 
    for (volatile uint32_t i = 0; i < 500000; ++i) {
        asm volatile ("nop");
    }
}

// Entry point placed in .text section
void call_user_start(void) __attribute__((section(".text")));
void call_user_start(void) {

    // Initialize GPIO
    volatile uint32_t* GPIO_ENABLE =    (uint32_t*)0x60000310;
    volatile uint32_t* GPIO_OUT_SET =   (uint32_t*)0x60000304;
    volatile uint32_t* GPIO_OUT_CLEAR = (uint32_t*)0x60000308;
    *GPIO_ENABLE |= (1 << 4);  // Set GPIO4 as output

    // Main loop
    while (1) {
        *GPIO_OUT_CLEAR = (1 << 4); // Set GPIO4 Low
        wait(); 
        *GPIO_OUT_SET = (1 << 4);   // Set GPIO4 High
        wait(); 
    }
}
