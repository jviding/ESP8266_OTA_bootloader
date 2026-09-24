# ESP8266 Bare-Metal LED Blink
This project explores bare-metal programming on the ESP8266 without high-level frameworks 
or SDK abstractions. It features a minimal LED blink implementation written in C, a custom 
linker script defining memory layout, and a lightweight build pipeline.

Beyond blinking an LED, this project serves as a practical guide to inspecting, disassembling, 
and analyzing ELF executables and raw binary files to understand how a program translates 
directly onto the Xtensa architecture.


## Build & Deploy
Run the pipeline with:
> \$ sh build.sh

Ensure the build tools are available via env (PATH). <br />
Add user in the *dialout* group, for */dev/ttyUSBx* access.

## Project structure
Constitutes of:                                                       <br />
\- **C source** - code to manipulate the GPIO registers               <br />
\- **Linker script** - defines memory layout and entry point          <br />
\- **Build script** - compiles, links, and flashes the ESP8266 image

Requires:                                       <br />
\- Xtensa LX106 toolchain (xtensa-lx106-elf-*)  <br />
\- esptool.py


## Inspect & Analyze
See *inspect.sh* for selected inspection tools.

### Section Headers
Command:
> xtensa-lx106-elf-objdump -h app.elf

Outputs:
```
Idx Name   Size      VMA       LMA       File off  Algn
  0 .text  0000008f  40100000  40100000  00001000  2**2
           CONTENTS, ALLOC, LOAD, READONLY, CODE
```

Read as:

Section contains actual data (CONTENTS), memory must be allocated on the target device (ALLOC), 
and this section be physically written there (LOAD). This region cannot be written to at 
runtime (READONLY) and it contains CPU machine instructions (CODE) rather than passive data. 

So, our linker script placed our program in this *.text* section, the program is 0x8F bytes, 
and VMA=LMA means it's executed directly from where it's loaded (IRAM region).

### Disassemble
Command:
> xtensa-lx106-elf-objdump -d app.elf

Translates machine code back into Xtensa LX106 assembly instructions and allows us to 
verify section placement, check literal pools, and debug arbitrary crash addresses.

Outputs:
```
40100000 <wait-0x10>:                                   // *** Literal pool ***
40100000: 1f a1 07 00                                   // Value defined for the for-loop
40100004: 10 03 00 60                                   // Value defined for GPIO
... 	
40100010 <wait>:                                        // *** Function: wait() ***
...
40100032: 0f28     l32i.n  a2, a15, 0                   // Load current loop counter 'i'
40100034: fff331   l32r    a3, 40100000 <wait-0x10>     // Load literal from 0x40100000 into a3
40100037: e6b327   bgeu    a3, a2, 40100021 <wait+0x11> // Branch if 500000 >= i
4010003a: f03d     nop.n                                //   nop
...
40100043: f00d     ret.n                                //   return
...
40100048 <call_user_start>:                             // *** Function: call_user_start() ***
...
40100051: ffec21   l32r    a2, 40100004 <wait-0xc>      // Load literal from 0x40100004 into a2
40100054: 0f29     s32i.n  a2, a15, 0                   // Store to RAM address [a15 + 0 bytes]
40100056: ffec21   l32r    a2, 40100008 <wait-0x8>      // Load ...
40100059: 1f29     s32i.n  a2, a15, 4                   // Store to RAM address [a15 + 4 bytes]
4010005b: ffec21   l32r    a2, 4010000c <wait-0x4>      // Load ...
4010005e: 2f29     s32i.n  a2, a15, 8                   // Store to RAM address [a15 + 8 bytes]
...
4010007d: fff905   call0   40100010 <wait>              // Call function wait()
40100080: 1f28     l32i.n  a2, a15, 4                   // Load GPIO register address into a2
40100082: 031c     movi.n  a3, 16                       // Load bitmask (1 << 4) into a3
40100084: 0020c0   memw                                 //   sync
40100087: 0239     s32i.n  a3, a2, 0                    // Write bitmask to register address [a2]
40100089: fff845   call0   40100010 <wait>              // Call function wait()
...
```

### Symbol Table
Command:
> xtensa-lx106-elf-nm app.elf

Outputs:
```
40100048 T call_user_start
40100010 T wait
```

**T/t**: Text section symbol (function in code section). As we see in the disassembled code, 
above, these are the addresses of our two functions in the program.

### ELF File Structure Details
Command:
> xtensa-lx106-elf-readelf -h app.elf

Outputs the **ELF File Header**, displaying such as architecture target, endianness (Little-Endian 
for Xtensa), and the entry point address (here it would be 0x40100048 for call_user_start).

Command:
> xtensa-lx106-elf-readelf -l app.elf

Outputs **Program Headers / Segments**, displaying how sections are grouped into LOAD segments
by the linker for flashing onto hardware. This is essential for bare-metal flash tools
(esptool.py), which parse segments rather than raw sections.

### Notice
Sections divide the binary logically based on content type (*.text* for code, *.data* for 
initialized variables, *.bss* for uninitialized data). But a loader or hardware flasher doesn't 
care about individual sections or function names - it only needs to know where to copy chunks of 
bytes in memory at runtime. To make loading efficient, the linker groups multiple **Sections** 
with similar permissions (e.g., combining *.text* and *.literal* into one executable block) into
a single **Segment**.

**objdump -h** (The Linking View: Sections) - Displays the section header table, which tells
the exact size and VMA (Virtual Memory Address) / LMA (Load Memory Address) of individual sections.
These sections have flags like CONTENTS, ALLOC, LOAD, READONLY, and CODE.

**readelf -l** (The Execution View: Segments) - Displays the program headers, which shows the
LOAD segments (continuous blocks of data to be copied from the binary file into RAM) and the
Section-to-Segment Mapping (which sections got packaged into which loadable segment).
