.section .text, "ax"

    .align 4
    .global call_user_start
    .type   call_user_start, @function
call_user_start:

    // 1. Set stack pointer to end of DRAM
    .extern __stack
    movi a1, __stack

    // 2. C ABI Requirement: Align stack pointer (16-byte alignment)
    movi a2, 0xFFFFFFF0
    and a1, a1, a2

    // 3. Disable HW watchdog
    // WDT_CTL @ 0x60000900, clear bit0
    movi a2, 0x60000900
    l32i a3, a2, 0
    movi a4, 0xfffffffe
    and a3, a3, a4
    s32i a3, a2, 0

    // 4. Disable SW watchdog
    // RTC_WDT @ 0x60000700, clear bit31
    movi a2, 0x60000700
    l32i a3, a2, 0
    movi a4, 0x7fffffff
    and a3, a3, a4
    s32i a3, a2, 0

    // 5. Set CPU Clock to 80 MHz (Crucial for C timing)
    movi a2, 0x3FF00000
    movi a3, 0x00088000
    s32i a3, a2, 0

    // 6. Copy .data section from Flash to DRAM
    // To handle initialized C variables (e.g., int x = 5)
    .extern _data_start, _data_end, _idata_start
    movi a6, _data_start     // Destination (DRAM address)
    movi a7, _idata_start    // Source (Flash address)
    movi a8, _data_end       // End of Destination
.Ldata_loop:
    bge a6, a8, .Ldata_done  // If destination >= end, copy is done
    l32i a3, a7, 0           // Load word from Flash
    s32i a3, a6, 0           // Store word to DRAM
    addi a6, a6, 4           // Increment destination pointer
    addi a7, a7, 4           // Increment source pointer
    j .Ldata_loop
.Ldata_done:

    // 7. Clear BSS section
    // To zero out uninitialized global and static C variables.
    .extern _bss_start, _bss_end
    movi a3, _bss_start      // Current BSS pointer
    movi a4, _bss_end        // BSS End
    movi a5, 0               // Value to write (zero)
.Lbss_loop:
    bge a3, a4, .Lbss_done   // If current pointer >= end pointer, BSS is done
    s32i a5, a3, 0           // Write 0 to current address
    addi a3, a3, 4           // Increment pointer by 4 bytes (1 word)
    j .Lbss_loop
.Lbss_done:

    // 8. Transfer control to C entry point (user_main)
    // Note: Manual l32r/j setup caused relocation errors with literal pool.
    // Rely on the assembler's built-in expansion of 'movi' instead, for a 32-bit
    // address to correctly handle the literal pool placement.
    .extern user_main
    movi a2, user_main

    // Jump register (jx) for a clean, non-returning transfer to
    // avoid conflicts with the C function's prologue.    
    jx a2            

    // Unreachable loop, user_main contains the main program loop.
loop:
    j loop
