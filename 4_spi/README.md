# ESP8266 Bare-Metal LED Blink
This is the fourth project in series to explore bare-metal programming on the ESP8266
without high-level frameworks or SDK abstractions. Code and constants are now stored in
SPI Flash (*IROM*), manually fetched into *DRAM* using built-in ROM functions (*SPIRead*),
copied to instruction memory (*IRAM*), and executed via the Xtensa *Call0* ABI.

Build and deploy:
> sh build.sh


## Dual-Binary Structure & Flash Offsets
Because the initial hardware boot sequence loads code from specific offsets, this
project generates two binary payloads:

1. *app.elf-0x00000.bin* (IRAM/DRAM Payload): Flash offset 0x00000. Contains initialization
code loaded directly into internal RAM by the chip's silicon ROM bootloader on power-up.
2. *app.elf-0x10000.bin* (IROM Flash Payload): Flash offset 0x10000. Holds flash-bound
functions and read-only data. The primary executable fetches these into RAM at runtime.


## Linker Script Symbol Placement
To let the application know how many bytes to fetch via SPI at runtime, the linker script
computes the section size and emits a 32-bit header word at the very start of *.irom0.text*:

```
.irom0.text {
    _irom0_text_start = .;                        /* Set start boundary address         */
    LONG(_irom0_text_end - _irom0_text_start);    /* Emit 32-bit size at offset +0x0    */
    ...                                           /* Literals, code, and byte alignment */
    _irom0_text_end = .;                          /* Set end boundary address           */
} >irom0_0_seg :irom0_0_phdr
```


## Physical Binary Inspection
Using *hexdump*, we can inspect raw binary payloads to verify data ordering and memory
offsets (accounting for Xtensa's *Little-Endian* byte ordering):

> hexdump -C app.elf-0x10000.bin | grep -i -C 2 "ef be ad de"

Example output:

```
00000000  ef be ad de 20 00 00 00  12 c1 f0 f9 31 fd 01 22  |.... .......1.."|
00000010  a7 d0 60 22 11 0b 22 56  a2 ff 3d f0 1d 0f f8 31  |..`".."V..=....1|
00000020  12 c1 10 0d f0 00 00 00                           |........|
```

- *0x00000000* - Our *.irom0.rodata* constant, *0xDEADBEEF*. 
- *0x00000004* - Our *.irom0.text* payload size, *0x00000020* (20 bytes).
- *0x00000008* - Beginning of the wait() function.


## Flash Virtual Memory Mapping Constraints
The ESP8266 CPU accesses SPI Flash in read-only mode via a virtual memory window starting
at *0x40200000*. In the linker script, *irom0* is placed at *0x40210000* (0x10000 offset).

```
MEMORY
{
  ...
  irom0_0_seg :   org = 0x40210000, len = 0x40000
}
```

Why Offset *0x10000*?

**Toolchain Conventions**: *esptool* expects physical address *0x00000* to be reserved for
stage-1 IRAM image headers. If we tried placing our *.irom0* section at VMA *0x40200000*, 
esptool would simply ignore it and not produce the second binary with our Flash payload.

**MMU Page Alignment**: The internal SPI Flash MMU maps memory in 64 KB blocks. As long as
the secondary binary is aligned to a 64 KB boundary (*0x10000*, *0x20000*, etc.), the
hardware MMU can map physical flash to virtual memory addresses space smoothly.


## ROM Function Resolution: SPIRead
*SPIRead* is a low-level driver routine baked into the ESP8266 internal mask ROM 
(*0x400000000*). It executes direct hardware SPI transaction to read raw bytes from
physical Flash offsets into RAM. Because ROM functions (e.g., *SPI*, *UART*, *GPIO*) are 
unlinked in standard bare-metal applications, we resolve the symbol manually in our  
linker script (mirroring the official SDK's *eagle.rom.addr.v6.ld* layout):

```
PROVIDE ( SPIRead = 0x40004b1c );
```

**Memory Bus Limitation: *StoreProhibited* Fault**

*SPIRead* uses 32-bit hardware FIFO operations that issue store instructions (*s32i*) 
over the CPU Data Bus. The Xtensa LX106 architecture treats IRAM (*0x40100000*) strictly 
as instruction memory space. Attempting to pass an IRAM address directly as a destination 
buffer to *SPIRead* triggers a CPU hardware exception (*StoreProhibited* / Memory 
Protection Exception).

Solution: Always read Flash content into a temporary 4-byte-aligned buffer in DRAM 
(*0x3FFE8000*), then copy from DRAM to IRAM using 32-bit word transfers before passing 
execution.


**CPU Branch Distance Limitation: Relocation error**

The Xtensa *call0* instruction relies on an 18-bit signed PC-relative immediate value, 
restricting direct function calls to a 512 KB reach. Because the distance between IRAM 
(0x40100000) and the Boot ROM symbol (0x40004B1C) is approximately 1 MB, direct linkage 
fails with a *call target out of range* relocation error.

Solution: Here, we solve this by instructing GCC to load absolute 32-bit addresses into 
registers via literal pools (*l32r*) and execute indirect calls (*callx0*). This enables
function calls across the full 4 GB memory space:

```
xtensa-lx106-elf-gcc -mlongcalls -c spi.c -o spi.o
```


## ESP8266 Bare-Metal Memory Map
Developing bare-metal software on the ESP8266 requires a clear mental model of its 
Harvard-architecture memory map. The internal bus structure strictly segregates Instruction 
Memory (accessed via the instruction bus) and Data Memory (accessed via the data bus), 
imposing strict rules on where code can be executed and where data can be written.

User-Accessible Memory Regions:

|Memory Region |Virtual Address Range   |Size  |Bus & Access Rules        |
|--------------|------------------------|------|--------------------------|
|DRAM (dram0)  |0x3FFE8000 - 0x3FFFC000 |80 KB |Data Bus (R/W)            |
|IRAM (iram1)  |0x40100000 - 0x40108000 |32 KB |Instruction Bus (R/W/X)   |
|IROM (irom0)  |0x40200000 - 0x40300000 |1 MB  |CPU MMU Window (Read-Only)|

Reserved & System Regions:

**Factory Boot ROM** (0x40000000 - 0x40010000 | 64 KB): Mask ROM burned into silicon
during manufacturing. Contains initial stage-0 hardware boot routines, peripheral 
primitive drivers, and utility functions like *SPIRead* and *ets_printfs*.

**Memory-Mapped I/O / MMU** (0x60000000 - 0x60001200 | 4 KB): Hardware peripheral
control registers. Direct bitwise reads and writes to these physical addresses control
hardware blocks such as GPIO, UART, SPI, and system timers.

Key Architectural Takeaways

**Dual-Bus Isolation**: IRAM (*0x40100000*) lives on the Instruction Bus. Attempting to
write directly to IRAM using standard data store instructions (*s32i*) triggers a CPU
hardware exception (*StoreProhibited*). Data must first be loaded into DRAM (0x3FFE8000)
and moved using 32-bit word transfers.

**Flash MMU Mapping**: The CPU cannot execute raw SPI Flash memory directly. It accesses
Flash through an internal MMU window mapped at 0x40200000. The MMU operates on 64 KB 
block boundaries, which dictates physical partition alignment in linker scripts.


## Stack & Heap Management in DRAM
When managing dynamic buffers and flash fetch targets in DRAM (0x3FFE8000), stack and heap 
collisions must be strictly avoided:

```
[0x3FFE8000] High Data / Static BSS
    ¦
    ¦ (Heap grows UPWARD)
    ¦
[ Free DRAM Memory Pool ]
    ¦
    ¦ (Stack grows DOWNWARD)
    ¦
[0x3FFFC000] Top of Stack
```

**Data/BSS & Heap**: Placed at the lower boundary of DRAM (0x3FFE8000). The Heap grows 
upwards toward higher addresses.

**Stack**: Placed at the upper boundary of DRAM (0x3FFFC000). The CPU stack frame grows 
downwards toward lower addresses.

**Buffer Safety Rules**: Allocations must be monitored to avoid collitions with the
downward-growing Stack and the upward-growing Heap.
