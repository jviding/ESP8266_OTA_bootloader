#include <stdint.h>

#define GPIO_PIN                4
#define GPIO_ENABLE_ADDR        (*(volatile uint32_t*)0x60000310)
#define GPIO_OUT_SET_ADDR       (*(volatile uint32_t*)0x60000304)
#define GPIO_OUT_CLEAR_ADDR     (*(volatile uint32_t*)0x60000308)


void __attribute__((section(".irom0.text"))) wait(void) {
    for (volatile uint32_t i = 0; i < 500000; ++i) {
        asm volatile ("nop");
    }
}

void __attribute__((section(".irom0.text"))) gpio_enable(void) {
    GPIO_ENABLE_ADDR |= (1 << GPIO_PIN);
}

void __attribute__((section(".irom0.text"))) gpio_set_high(void) {
    GPIO_OUT_SET_ADDR = (1 << GPIO_PIN);
}

void __attribute__((section(".irom0.text"))) gpio_set_low(void) {
    GPIO_OUT_CLEAR_ADDR = (1 << GPIO_PIN);
}
