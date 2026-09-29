#include <stdint.h>

volatile uint32_t GPIO_MASK;        // Volatile to force l32i

uint32_t bss_check(void) {
    return GPIO_MASK == 0 ? 1 : 0;  // Verify BSS was cleared
}

void wait() {
    for (volatile uint32_t i = 0; i < 500000; ++i) {
        asm volatile ("nop");
    }
}

void gpio_enable(volatile uint32_t *gpio_enable_reg, uint32_t gpio_num) {
    GPIO_MASK = (1 << gpio_num);
    *gpio_enable_reg |= GPIO_MASK;
}

void set_gpio_high(volatile uint32_t *gpio_set_reg) {
    *gpio_set_reg = GPIO_MASK;
}

void set_gpio_low(volatile uint32_t *gpio_clear_reg) {
    *gpio_clear_reg = GPIO_MASK;
}
