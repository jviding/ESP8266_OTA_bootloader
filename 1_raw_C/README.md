# ESP8266 Bare-Metal LED Blink
This project explores bare-metal programming on the ESP8266 without high-level <br />
frameworks or SDK abstractions. It features a minimal LED blink implementation <br />
written in C, a custom linker script defining memory layout, and a lightweight <br />
build pipeline.

Beyond blinking an LED, this project serves as a practical guide to inspecting, <br />
disassembling, and analyzing ELF executables and raw binary files to understand <br />
how a program translates directly onto the Xtensa architecture.


## Build & Deploy
Run the pipeline with:
> \$ sh build.sh

Ensure the build tools are available via env (PATH). <br />
Add user in the *dialout* group, for */dev/ttyUSBx* access.

## Project structure
Constitutes of:
\- **C source** - code to manipulate the GPIO registers
\- **Linker script** - defines memory layout and entry point
\- **Build script** - compiles, links, and flashes the ESP8266 image

Requires:
\- Xtensa LX106 toolchain (xtensa-lx106-elf-*)
\- esptool.py


## Inspect & Analyze
See **inspect.sh** for inspection tools. <br />


**Section Headers** <br />
> xtensa-lx106-elf-objdump -h app.elf

We can see the .text section is 0x8F bytes, and VMA=LMA means the <br />
program is executed directly from where it's loaded (IRAM region).

```
Idx Name   Size      VMA       LMA       File off  Algn
  0 .text  0000008f  40100000  40100000  00001000  2**2
           CONTENTS, ALLOC, LOAD, READONLY, CODE
```

Section contains actual data (CONTENTS), memory must be allocated on the    <br />
target device (ALLOC), and this section be physically written there (LOAD). <br />
This region cannot be written to at runtime (READONLY) and it contains CPU  <br />
machine instructions (CODE) rather than passive data. 






For example, to disassemble the ELF:

> \$ xtensa-lx106-elf-objdump -d app.elf

Everything is placed inside a single **.text** section, where:

> 0x40100000-0x4010000c : Literal pool (4x 32-bit words)                            <br />
> 0x40100010-0x40100045 : Function wait()            // Xtensa machine instructions <br />
> 0x40100048-0x40100091 : Function call_user_start() // Xtensa machine instructions

Literal pool contains the constants referenced by l32r instructions.

The literal pool contains constants referenced by l32r instructions.
Because these are in peripheral MMIO space, not in RAM, they work without initialization.
In simple terms, they don't depend on .data, .bss, stack, or interrupts.

The literal pool contains constants referenced by l32r instructions. <br />
The rest is the actual program code starting at call_user_start.
