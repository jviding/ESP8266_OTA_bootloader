#include <stdint.h>

void wait() {
    /*
        Busy-wait delay loop

        Why 'volatile' on the loop counter?
            - Prevents the compiler from optimizing the loop away.
            - Forces each increment and comparison to actually occur.
            -> Ensures the loop runs the full number of iterations.

        Why 'asm volatile ("nop")'?
            - Prevents the compiler from treating the loop body as empty.
            - Forces a real CPU instruction inside each iteration.
            -> Makes the delay predictable on a bare-metal system.

        Note:
            - The 'nop' alone does NOT guarantee the loop runs 500.000 times.
            - The 'volatile' counter is what preserves the loop structure.
    */
    for (volatile uint32_t i = 0; i < 500000; ++i) {
        asm volatile ("nop");
    }
}

// Entry point, as defined in the linker script
/*
    The ESP8266 ROM bootloader loads this program from flash and then
    jumps to the address specified as the ELF entry point.

    Our linker script (app.ld) sets:
        ENTRY(call_user_start)

    This makes 'call_user_start' the first function executed after the
    bootloader finishes loading the image into IRAM/DRAM.
    
    Important details:
        - The ROM bootloader sets up a valid stack pointer.
        - It loads .text and .data segments into memory.
        - It does NOT initialize .bss or run any C runtime startup code.
          (This program works only because it uses no global variables.)
    
    From this point onward, execution is entirely bare-metal:
        - No interrupts
        - No SDK
        - No runtime initialization
        - Only direct hardware register access

    'call_user_start' is the true beginning of the program.
*/
void call_user_start(void) {
    /*
        Initialize GPIO

        These addresses are Memory-Mapped I/O (MMIO) registers.
        Reading or writing them directly controls hardware.

        The compiler normally assumes that memory behaves like RAM:
            - Reads may be cached
            - Writes may be reordered or removed
            - Repeated strokes may be optimized away

        MMIO does NOT behave like RAM:
            - Every read returns live hardware state
            - Every write triggers a hardware side effect
            - Ordering of access matters

        'volatile' tells the compiler:
            - Do NOT cache these values
            - Do NOT reorder accesses
            - Do NOT remove reads or writes
            - Always emit real load/store instructions

        Without 'volatile', the compiler might optimize away
        the GPIO writes, and the LED would not blink.   
    */
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
