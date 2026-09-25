# =========================
# *** CONSTANTS IN DRAM ***
# =========================
    .section .rodata, "a"
    .align 4

.L_DELAY_COUNT:           .word   0x0007A120    # 500.000
.L_GPIO_ENABLE:           .word   0x60000310
.L_GPIO_OUT_SET:          .word   0x60000304
.L_GPIO_OUT_CLEAR:        .word   0x60000308


# ====================
# *** LITERAL POOL ***
# ====================
    .section .literal
    .align 4

.L_DELAY_COUNT_ADDR:      .word   .L_DELAY_COUNT
.L_GPIO_ENABLE_ADDR:      .word   .L_GPIO_ENABLE
.L_GPIO_OUT_SET_ADDR:     .word   .L_GPIO_OUT_SET
.L_GPIO_OUT_CLEAR_ADDR:   .word   .L_GPIO_OUT_CLEAR


# ===================
# *** void wait() ***
# ===================
    .text
    .align 4
    .global wait
    .type   wait, @function
wait:
    # PROLOGUE: Stack Frame Setup
    addi    a1,  a1, -32                # Reserve 32 bytes on stack frame
    s32i.n  a15, a1,  28                # Save caller's frame pointer (return address)
    mov.n   a15, a1                     # Set a15 as local frame pointer

    # uint32_t i = 0
    movi.n  a2, 0                       # Load the immediate integer value 0 into a2
    memw                                #  sync
    s32i.n  a2, a15, 0                  # Store i at [a15 + 0]
    j       .L_wait_loop_check

.L_wait_loop_body:
    # asm volatile ("nop");
    nop.n

    # ++i 
    memw
    l32i.n  a2, a15, 0                  # Read i from stack
    addi.n  a2, a2,  1                  # Increment i++
    memw
    s32i.n  a2, a15, 0                  # Write i back to stack (volatile)

.L_wait_loop_check:
    memw
    l32i.n  a2, a15, 0                  # Read i from stack
    l32r    a3, .L_DELAY_COUNT_ADDR     # Load Counter address into a3
    l32i    a4, a3,  0                  # Load Counter value from [a3]
    bgeu    a4, a2, .L_wait_loop_body   # If 500000 >= i, loop again

    # EPILOGUE: Stack Frame Cleanup & Return
    mov.n   a1,  a15                    # Restore stack pointer
    l32i.n  a15, a1, 28                 # Restore caller's frame pointer
    addi    a1,  a1, 32                 # Release reserved stack space
    ret.n                               # Return to caller


# ==============================
# *** void call_user_start() ***
# ==============================
    .text
    .align  4
    .global call_user_start
    .type   call_user_start, @function
call_user_start:
    # PROLOGUE: Stack Frame Setup
    addi    a1,  a1, -32
    s32i.n  a0,  a1,  28
    s32i.n  a15, a1,  24
    mov.n   a15, a1

    # Load GPIO register addresses onto local stack frame
    l32r    a2, .L_GPIO_ENABLE_ADDR
    l32i    a3, a2,  0
    s32i.n  a3, a15, 0                  # [a15 + 0] = GPIO_ENABLE

    l32r    a2, .L_GPIO_OUT_SET_ADDR
    l32i    a3, a2,  0
    s32i.n  a3, a15, 4                  # [a15 + 4] = GPIO_OUT_SET

    l32r    a2, .L_GPIO_OUT_CLEAR_ADDR
    l32i    a3, a2,  0
    s32i.n  a3, a15, 8                  # [a15 + 8] = GPIO_OUT_CLEAR

    # *GPIO_ENABLE |= (1 << 4);
    l32i.n  a2, a15, 0                  # Load GPIO_ENABLE address
    memw
    l32i.n  a3, a2,  0                  # Read current register value
    movi.n  a2, 16                      # Bit 4 mask (1 << 4 = 16) 
    or      a3, a3,  a2                 # Set bit 4
    l32i.n  a2, a15, 0
    memw
    s32i.n  a3, a2, 0                   # Write to GPIO_ENABLE

.L_main_loop:
    # *GPIO_OUT_CLEAR = (1 << 4);
    l32i.n  a2, a15, 8                  # Load GPIO_OUT_CLEAR address
    movi.n  a3, 16                      # Bitmask (1 << 4)
    memw
    s32i.n  a3, a2,  0                  # Write to GPIO_OUT_CLEAR

    # wait();
    call0   wait

    # *GPIO_OUT_SET = (1 << 4);
    l32i.n  a2, a15, 4                  # Load GPIO_OUT_SET
    movi.n  a3, 16                      # Bitmask (1 << 4)
    memw
    s32i.n  a3, a2,  0                  # Write to GPIO_OUT_SET

    # wait();
    call0   wait

    # Repeat while(1)
    j       .L_main_loop
