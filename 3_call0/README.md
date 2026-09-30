# ESP8266 Bare-Metal LED Blink
This is the third project in series to explore bare-metal programming on the ESP8266
without high-level frameworks or SDK abstractions. This project transitions from
isolated assembly to a hybrid system: an assembly-based execution loop that
interoperates with C functions using function arguments and return values.

Build and deploy:
> sh build.sh


## Xtensa Call0 ABI & Register rules
Function arguments are passed in registers *a2* through *a7*. These registers are 
caller-saved (volatile) and any function is legally allowed to overwrite them. So,
if arguments are reused, they must be re-loaded into *a2*-*a7* before every *call0*.
```
l32i  a2, a3, 0        # a2 = *gpio_enable_reg
movi  a3, 4            # a3 = gpio_num
call0 gpio_enable      # gpio_enable(*gpio_enable_reg, gpio_num) 
```

Scalar return values are returned in register *a2*.
```
call0 bss_check        # uint32_t bss_check(void)
bnez  a2, .L_continue  # Branch if a2 != 0, skip the trap
ill                    # Illegal opcode: CPU traps here if check failed
```

**Caller-Saved (*a2*-*a7*)**: "*I (the caller) must save these if I need them after*
*a function call, because the callee will overwrite them.*"

**Callee-Saved (*a12*-*a15*, *a1*)**: "*I (the callee) must save these to the stack*
*before using them, and restore them back to their original values before returning.*"

Callee-saved registers act as superfast local storage. Keeping persistent values
directly inside the CPU core's registers across function calls avoids expensive 
RAM operations (e.g., *l32i*, *s32i*) to the stack.


### Hardware trapping with *ill*
Unlike high-level operating systems that call *exit()* or print stack traces to stderr,
bare-metal hardware has no OS to catch errors. Using the *ill* (Illegal Opcode) instruction
on bare-metal triggers an immediate hardware exception, halting execution safely instead of 
letting corrupted memory states propagate into hardware peripherals.


## Section: .bss & Manual zeroing
Our linker script assigns the uninitialized global variable, *uint32_t GPIO_MASK*, to the 
*.bss* section. Because *.bss* occupies zero bytes (marked as *NOBITS* in ELF binaries)
in the Flash binary and is only allocated memory at runtime, our assembly startup code 
needs to manually zero out the designated DRAM region. To enable this zeroing loop, our
linker script defines boundary symbols *_bss_start* and *_bss_end*.
```
.bss : ALIGN(4)
  {
    _bss_start = .;
    *(.bss)
    *(.bss.*)
    *(COMMON)         // 1.
    . = ALIGN(4);     // 2.
    _bss_end = .;
  } >dram0_0_seg :dram0_0_bss_phdr
```

1. By default, standard C compilers emit uninitialized global variables as COMMON symbols
rather than placing them directly into *.bss*. If a linker script omits *\*(COMMON)*
inside the *.bss* section output block, these variables float outside *.bss* and are
skipped during zeroing, causing silent, hard-to-debug runtime bugs.

2. Xtensa's *s32i* (store 32-bit) instruction requires a 4-byte aligned memory address and
writes 4 full bytes at a time. Aligning *.bss* to a 4-byte boundary ensures that 32-bit
zeroing loops do not trigger unaligned store exceptions or write past the end of *.bss*,
preventing memory corruption in adjacent DRAM variables.
