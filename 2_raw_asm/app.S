    .section .text, "ax"

    .align 4
    .global call_user_start
    .type   call_user_start, @function
call_user_start:
    // 1. Set stack pointer
    .extern __stack
    movi a1, __stack

    // 2. Disable HW watchdog
    // WDT_CTL @ 0x60000900, clear bit0
    movi a2, 0x60000900
    l32i a3, a2, 0
    movi a4, 0xfffffffe
    and a3, a3, a4
    s32i a3, a2, 0

    // 3. Disable SW watchdog
    // RTC_WDT @ 0x60000700, clear bit31
    movi a2, 0x60000700
    l32i a3, a2, 0
    movi a4, 0x7fffffff
    and a3, a3, a4
    s32i a3, a2, 0

    // 4. Initialize GPIO
    // GPIO_ENABLE @ 0x60000310, set bit4
    movi a2, 0x60000310
    l32i a3, a2, 0
    movi a4, (1 << 4)
    or a3, a3, a4
    s32i a3, a2, 0

    // GPIO_OUT_SET   @ 0x60000304
    // GPIO_OUT_CLEAR @ 0x60000308
    movi a5, 0x60000304
    movi a6, 0x60000308
    movi a7, (1 << 4)

main_loop:
    // Set GPIO4 low
    s32i a7, a6, 0
    call0 wait

    // Set GPIO4 high
    s32i a7, a5, 0
    call0 wait

    j main_loop

//--------------------------------------------------
// Busy-wait loop
//--------------------------------------------------
    .align 4
wait:
                        // PROLOGUE
    addi a1, a1, -4     // Reserve 4 bytes from the stack
    s32i a0, a1, 0      // Save a0 (return address) on the stack
    
    movi a8, 500
wait_loop:
    call0 wait_1ms
    addi a8, a8, -1
    bnez a8, wait_loop
                        // EPILOGUE
    l32i a0, a1, 0      // Restore a0 (return address)
    addi a1, a1, 4      // Free the reserved stack
    ret

    .align 4
wait_1ms:
    movi a9, 13500          // 40MHz / 3 = 13.500
wait_1ms_loop:
    addi a9, a9, -1         // 1 cycle
    bnez a9, wait_1ms_loop  // ~2 cycles (branch taken)
    ret
