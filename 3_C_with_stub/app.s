# =========================
# *** CONSTANTS IN DRAM ***
# =========================
    .section .rodata, "a"
    .align 4

.L_DELAY_COUNT:           .word   0x0007A120    # 500.000
.L_GPIO_ENABLE:           .word   0x60000310
.L_GPIO_OUT_SET:          .word   0x60000304
.L_GPIO_OUT_CLEAR:        .word   0x60000308


# ==============================
# *** void call_user_start() ***
# ==============================
    .section .literal
    .align 4

.L_GPIO_ENABLE_ADDR:      .word   .L_GPIO_ENABLE
.L_GPIO_OUT_SET_ADDR:     .word   .L_GPIO_OUT_SET
.L_GPIO_OUT_CLEAR_ADDR:   .word   .L_GPIO_OUT_CLEAR

    .text
    .align 4
    .global call_user_start
    .type   call_user_start, @function

call_user_start:
    # --- Clear BSS section ---
    movi a2, _bss_start                 # Current BSS pointer
    movi a3, _bss_end                   # BSS end
    movi a4, 0                          # Value to write (zero)
.Lbss_loop:
    bgeu a2, a3, .Lbss_done             # If current ptr >= end ptr, BSS done
    s32i a4, a2, 0                      # Write 0 to current address
    addi a2, a2, 4                      # Increment pointer by 4 bytes (1 word)
    j .Lbss_loop
.Lbss_done:

    l32r a3, .L_GPIO_ENABLE_ADDR
    l32i a2, a3, 0                      # a2 = *gpio_enable_reg
    movi a3, 4                          # a3 = gpio_num
    call0 gpio_enable                   # gpio_enable(*gpio_enable_reg, gpio_num)  

.Lloop:
    l32r a3, .L_GPIO_OUT_CLEAR_ADDR
    l32i a2, a3, 0                      # a2 = *gpio_clear_reg
    call0 set_gpio_low                  # set_gpio_low(*gpio_clear_reg)

    call0 wait                          # wait()
    
    l32r a3, .L_GPIO_OUT_SET_ADDR
    l32i a2, a3, 0                      # a2 = *gpio_set_reg
    call0 set_gpio_high                 # set_gpio_high(*gpio_set_reg)
    
    call0 wait                          # wait()
    j .Lloop




    # Clear BSS section
    # Zero out uninitialized global and static C variables.
    #.extern _bss_start, _bss_end
    #movi a3, _bss_start      # Current BSS pointer
    #movi a4, _bss_end        # BSS End
    #movi a5, 0               # Value to write (zero)
#.Lbss_loop:
    #bge a3, a4, .Lbss_done   # If current pointer >= end pointer, BSS is done
    #s32i a5, a3, 0           # Write 0 to current address
    #addi a3, a3, 4           # Increment pointer by 4 bytes (1 word)
    #j .Lbss_loop
#.Lbss_done: