#include <stdint.h>

void __attribute__((section(".irom0.text"))) waits() {
    asm volatile (
        "movi   a2, 2000\n\t"     // Load 2000 into a2
        "slli   a2, a2, 10\n\t"   // a2 = 2000 << 10 = 2,048,000 iterations
        "1:\n\t"
        "addi   a2, a2, -1\n\t"   // Decrement loop counter
        "bnez   a2, 1b\n\t"       // Loop until counter reaches 0
        ::: "a2"
    );
}
