# ESP8266 Bare-Metal LED Blink
This is the second project in series to explore bare-metal programming on the ESP8266
without high-level frameworks or SDK abstractions. The LED blink implementation has now
been written in Assembly (app.s), the linker script (app.ld) has been upgraded, and the
build pipeline (build.sh) bypasses the CPP and GCC drivers.

Build and deploy:
> sh build.sh

Beyond those changes, this project provides practical insight into bare-metal memory
mapping and call stack management on Xtensa LX106. Our linker script now segregates
output into *.text* (IRAM execution), *.literal* (IRAM pointer pool), and *.rodata*
(DRAM constants). Additionally, we implemented explicit stack frame prologues and
epilogues in assembly to manage caller/callee-saved registers manually, adhering
to the Xtensa Call0 ABI to prevent nested *call0* instructions from clobbering the
return address register (*a0*).


# Implicit Sectioning
In our previous project, the linked ELF used an inline *.literal* pool because our 
linker script merged **(.literal)* directly inside the *.text* output section. In 
larger codebases, scattering literal pools inline throughout *.text* ensures that
*l32r* (PC-relative load) instructions stay within their hardware range limit of 
256 KB relative to the target data.

To support inline pools, the Xtensa toolchain emits *.xt.lit* metadata sections to
track literal boundaries embedded within executable code blocks. Inspection tools
such as *objdump* utilize this *.xt.lit* table to differentiate raw constants from
valid opcodes, preventing data words inside *.text* from being incorrectly
disassembled as instructions.

If we inspect the ELF from our previous project:
```
> xtensa-lx106-elf-objdump -h app.elf

Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         0000008f  40100000  40100000  00001000  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
  3 .xt.lit       00000008  00000000  00000000  000010f8  2**0
                  CONTENTS, READONLY

> xtensa-lx106-elf-objdump -d app.elf

Disassembly of section .text:

40100000 <wait-0x10>:
40100000: 1f a1 07 00                   # Disassembled as data word
...	
40100010 <wait>:
40100010: e0c112    addi a1, a1, -32    # Disassembled as instruction
...
...
```

# Explicit Sectioning
In this project, we write our constants (data words) to the *.rodata* output 
section, mapped directly to Flash via the read-only DRAM bus alias (0x3ffe8000).
We then store 32-bit Flash pointers to those constants in a standalone *.literal*
output section placed in IRAM immediately preceding our *.text* output section:
```
Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .rodata       00000010  3ffe8000  3ffe8000  00002000  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, DATA
  1 .literal      00000010  40100000  40100000  00001000  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
  2 .text         00000084  40100010  40100010  00001010  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
```

Because our assembly build pipeline invokes *as* directly without compiler-driven
literal transformations, no *.xt.lit* metadata section is generated. Consequently,
*objdump* now lacks the metadata required to mask data words in *.literal*, and
attempts to decode raw 32-bit address pointers as instruction opcodes:
```
Disassembly of section .literal:

40100000 <.literal>:                # Explicit .literal section
40100000: 00    .byte 00
40100001: 80    .byte 0x80
40100002: fe    .byte 0xfe
...

Disassembly of section .text:       # Followed by .text section

40100010 <wait>:
40100010: e0c112    addi a1, a1, -32
...
```



# asm

Loading with l32i and l32r and what's the .n



# Prologue
Function prologue prepares the call stack whenever a function is called (*call0*) so 
that it can safely store local variables, call sub-functions without losing track of 
where to return, and restore the CPU state when finished.

```
    addi    a1,  a1, -32        // 1. a1 = a1 - 32
    s32i.n  a0,  a1,  28        // 2. Write value in a0 to address [a1 + 28]
    s32i.n  a15, a1,  24        // 3. Write value in a15 to address [a1 + 24]
    mov.n   a15, a1             // 4. Move value in a1 to a15 
```
**1.** In the Xtensa ABI (Application Binary Interface), **a1** is the dedicated Stack
Pointer (SP). Because the stack grows *downward* (from high memory addresses to low 
memory addresses), substracting 32 bytes allocates a private 32-byte region on RAM for 
this function's temporary use.

**2.** Register **a0** holds the Return Address (where CPU needs to jump back to after
finishing this function). If this function calls another function, a0 will be 
overwritten. Saving a0 onto the stack at offset 28 ensures the function can safely
make nested calls without forgetting where to return.

**3.** Register **a15** acts as the Frame Pointer (FP). Since the current function is
about to change a15 to point to its own stack frame, it must first back up the
caller's frame pointer at offset 24 so it can be restored when returning.

**4.** Establish **a15** as the fixed base address (Frame Pointer) for the current
call. Even if the stack pointer (a1) moves dynamically later (e.g., allocating
variable-length arrays via *alloca()*), a15 stays fixed, allowing the debugger or
function to reliably reference local variables and parameters.



# Epilogue
How works?

Explain memw
When needed? Why?

What is ill?
40100045:	000000        	ill






