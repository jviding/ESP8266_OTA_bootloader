#include <stdint.h>

void __attribute__((section(".irom0.text"))) waits() {
    /*for (volatile uint32_t i = 0; i < 500000; ++i) {
        asm volatile ("nop");
    }*/
    asm volatile (
        "movi   a2, 1000\n\t"     // Load 1000 into a2
        "slli   a2, a2, 10\n\t"   // a2 = 1000 << 10 = 1,024,000 iterations
        "1:\n\t"
        "addi   a2, a2, -1\n\t"   // Decrement loop counter
        "bnez   a2, 1b\n\t"       // Loop until counter reaches 0
        ::: "a2"
    );
}
