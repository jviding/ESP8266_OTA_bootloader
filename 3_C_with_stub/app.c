#include <stdint.h>
#include <stdbool.h>

// Initialized variable to be placed in .data section
int g_initialized_data = 0xBEEFBEEF;

// Uninitialized variable to be placed in .bss section
int g_uninitialized_bss;


void wait() { 
    for (volatile uint32_t i = 0; i < 1500000; ++i) {
        asm volatile ("nop");
    }
}

void user_main(void) {
    // Initialize GPIO
    volatile uint32_t* GPIO_ENABLE =    (uint32_t*)0x60000310;
    volatile uint32_t* GPIO_OUT_SET =   (uint32_t*)0x60000304;
    volatile uint32_t* GPIO_OUT_CLEAR = (uint32_t*)0x60000308;
    *GPIO_ENABLE |= (1 << 4);  // Set GPIO4 as output

    bool memory_check_ok = true;
    g_initialized_data != 0xBEEFBEEF && (memory_check_ok = false);
    g_uninitialized_bss != 0 && (memory_check_ok = false);

    // Indicate error by setting GPIO4 high and halting
    if (!memory_check_ok) {
        *GPIO_OUT_SET = (1 << 4);   // Set GPIO4 High
        while (1);
    }

    // Blink GPIO4
    while (1) {
        *GPIO_OUT_CLEAR = (1 << 4); // Set GPIO4 Low
        wait(); 
        *GPIO_OUT_SET = (1 << 4);   // Set GPIO4 High
        wait(); 
    }
}
