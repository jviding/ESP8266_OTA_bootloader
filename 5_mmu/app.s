# ==============================
# *** void call_user_start() ***
# ==============================
    .section .literal
    .align 4

.L_OFFSET:                          .word   0x00010000
.L_GPIO_ENABLE_FUNC:                .word   gpio_enable
.L_GPIO_SET_FUNC:                   .word   gpio_set_high
.L_GPIO_CLEAR_FUNC:                 .word   gpio_set_low
.L_WAIT_FUNC:                       .word   wait

    .text
    .align 4
    .global call_user_start
    .type   call_user_start, @function

call_user_start:
    # --- Disable interrupts ---
    rsil a2, 3                      # Raise level to 3

    # --- MMU Cache Enable ---
    l32r a2, .L_OFFSET              # Set 2nd binary physical offset
    call0 init_mmu_and_cache        # Enable MMU

    # --- Re-enable interrupts ---
    rsil a2, 0                      # Set level back to 0

    # --- GPIO enable ---
    l32r a2, .L_GPIO_ENABLE_FUNC
    callx0 a2

.L_loop:
    # --- LED blink ---
    l32r a2, .L_GPIO_CLEAR_FUNC
    callx0 a2                       # Set GPIO Low
    l32r a2, .L_WAIT_FUNC
    callx0 a2                       # wait()
    l32r a2, .L_GPIO_SET_FUNC
    callx0 a2                       # Set GPIO High
    l32r a2, .L_WAIT_FUNC
    callx0 a2                       # wait()
    j .L_loop
