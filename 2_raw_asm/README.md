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
epilogues in assembly to manage caller/callee-saved registers manually.


## Implicit Sectioning
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


## Explicit Sectioning
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

40100000 <.literal>:                 # Explicit .literal section
40100000: 00    .byte 00
40100001: 80    .byte 0x80           # Disassembled as instruction
40100002: fe    .byte 0xfe
...

Disassembly of section .text:        # Followed by .text section

40100010 <wait>:
40100010: e0c112  addi a1, a1, -32   # Disassembled as instruction
...
```

So, even with a standalone *.literal* section, *objdump* still attempts to decode
the data words as executable opcodes. This occurs because without *.xt.lit*
metadata to delineate the literal boundaries, *objdump* relies solely on the 
*CODE* attribute the Xtensa assembler tagged the *.literal* section with.

The Xtensa assembler (*as*) automatically tags *.literal* sections with the *CODE*
(*SHF_EXECINSTR*) attribute because *.literal* sections must be IBUS-accessible.
This is due to the *l32r* instruction, which fetches data directly over the CPU's
Instruction Fetch Bus (IBUS), bypassing the standard Load/Store Unit on the Data
Bus (DBUS).


## IBUS (l32r) vs. DBUS (l32i)
The Xtensa LX106 CPU core follows a Harvard Architecture, where instruction
fetching and data access are handled by physically separate memory pathways.

**Instruction Memory Interface (IBUS)**: Connects the core's Instruction Fetch
Unit exclusively to executable memory regions, such as IRAM (0x40100000) and 
mapped IROM (0x40200000).

**Data Memory Interface (DBUS)**: Connects the core's Load/Store Unit to data 
memory regions, such as DRAM (0x3FFE8000 Flash alias) and peripheral MMIO 
registers (0x60000000).

Standard data load instructions like *l32i* route through the Load/Store Unit
over the DBUS. Conversely, *l32r* calculates its target address relative to the
Program Counter (*PC*) and fetches data directly through the IBUS - even though
it is loading a data word from a literal pool rather than executing an opcode.

Because *l32r* reads through the IBUS, the target *.literal* pool must reside 
in IBUS-accessible memory (such as IRAM at *0x40100000*) and adhere to strict 
32-bit word alignment. Furthermore, *l32r* has a maximum PC-relative reach 
limit of 256 KB, requiring literal pools to be placed within range of the 
calling code.


### l32r example
The *l32r* (Load 32-bit PC-relative) instruction calculates its target address
by adding a negative 18-bit word offset to the current Program Counter (PC).
> Target Address = (PC + 3) - (Offset x 4)

For an example, in our disassembled ELF, we have an *l32r* instruction located 
in address *0x40100034*:
```
40100000 <.literal>:
40100000:	00 80 fe 3f   # 0x3FFE8000
...
40100010 <wait>:
...
40100034:	fff331  l32r a3, 40100000 <wait-0x10>
...
```

1. **Calculate base PC**: The length of a standard 24-bit Xtensa instruction is 3 bytes,
which is added to locate the end of the current instruction (the start of the next):
> PC + 3 = 0x40100037

2. **Force 32-bit alignment**: The CPU core masks off the lowest 2 bits (~0x3) to align
to a 4-byte boundary:
> Aligned base = 0x40100037 & ~ 0x3 = 0x40100034

3. **Decode offset**: In the 24-bit opcode *0xFFF331*, the assembler encoded a 16-bit
word offset of 0xFFF3 (which, as a 16-bit signed integer, equals -13). Converted to bytes:
> Offset x 4 = 13 x 4 = 52 bytes (0x34)

```
24-bit Instruction: 0x31F3FF (Little-Endian of 0xFFF331)
Binary:             0011 0001 1111 0011 1111 1111

[ Bits 23:8 ] 16-bit Offset Field  : 0xFFF3  (1111 1111 1111 0011)
[ Bits  7:4 ] Target Register (t)  : 0x1     (0001 -> Register a3)
[ Bits  3:0 ] Opcode Identifier    : 0x1     (0001 -> RI16 Format / L32R)
```

4. **Compute final target address**:
> Target address = (PC + 3) - (Offset x 4) = 0x40100034 - 0x34 = 0x40100000

So, the *l32r* instruction fetches the 32-bit value stored at 0x40100000 (that is within
the 256 KB PC-relative reach) via IBUS and stores that in register *a3*.


## Prologue
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



## Epilogue
How works?

Explain memw
When needed? Why?

What is ill?
40100045:	000000        	ill

