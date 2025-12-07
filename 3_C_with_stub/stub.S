.section .text, "ax"

    .align 4
    .global call_user_start
    .type   call_user_start, @function
call_user_start:

    // Clear BSS section
    // Zero out uninitialized global and static C variables.
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

    // Transfer control to C entry point (user_main)
    .extern user_main
    movi a2, user_main

    // Jump register (jx) for a clean, non-returning transfer
    // to avoid conflicts with the C function's prologue.    
    jx a2            

    // Unreachable loop, user_main contains the main program loop.
loop:
    j loop
