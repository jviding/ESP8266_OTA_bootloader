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

    // 1. Set stack pointer near the top of DRAM
    asm volatile ("movi a1, 0x3ffe8000");

    // 2. Disable watchdogs
    volatile uint32_t* WDT_CTL = (uint32_t*)0x60000900;
    *WDT_CTL &= ~1; // HW
    volatile uint32_t* RTC_WDT = (uint32_t*)0x60000700;
    *RTC_WDT &= ~(1 << 31); // SW

    // 3. Clear BSS section
    extern uint32_t _bss_start;
    extern uint32_t _bss_end;
    for (uint32_t* bss = &_bss_start; bss < &_bss_end; ++bss) {
        *bss = 0;
    }

    // 4. Initialize GPIO
    volatile uint32_t* GPIO_ENABLE =    (uint32_t*)0x60000310;
    volatile uint32_t* GPIO_OUT_SET =   (uint32_t*)0x60000304;
    volatile uint32_t* GPIO_OUT_CLEAR = (uint32_t*)0x60000308;
    *GPIO_ENABLE |= (1 << 4);  // Set GPIO4 as output

    // 5. Main loop
    while (1) {
        *GPIO_OUT_CLEAR = (1 << 4); // Set GPIO4 Low
        wait(); 
        *GPIO_OUT_SET = (1 << 4);   // Set GPIO4 High
        wait(); 
    }
}
