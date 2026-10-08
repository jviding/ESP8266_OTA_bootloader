#include <stdint.h>


void gpio_enable(volatile uint32_t *gpio_enable_reg, uint32_t gpio_num) {
    *gpio_enable_reg |= (1 << gpio_num);
}

void gpio_set_high(volatile uint32_t *gpio_set_reg, uint32_t gpio_num) {
    *gpio_set_reg = (1 << gpio_num);
}

void gpio_set_low(volatile uint32_t *gpio_clear_reg, uint32_t gpio_num) {
    *gpio_clear_reg = (1 << gpio_num);
}
