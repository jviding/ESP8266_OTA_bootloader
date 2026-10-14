# ESP8266 Bare-Metal LED Blink
This is the fifth project in series to explore bare-metal programming on the ESP8266 without 
high-level frameworks or SDK abstractions. In the previous project, code was copied from Flash 
to IRAM and executed. Because running from IRAM broke the PC-relative instruction references, 
standard Xtensa instructions like l32r became unsafe without manual relocations.

In this project, we call internal ROM functions to program the Memory Management Unit (*MMU*),
enabling transparent eXecute In Place (*XIP*) directly from Flash using the chip's internal
hardware cache (*SRAM*). The code executed from Flash are the functions to toggle the LED.

Build and deploy:
> sh build.sh


## Hardware Architecture: The 1 MB Virtual Window
The Xtensa LX106 CPU inside the ESP8266 is a 32-bit core capable of addressing up to 4 GB of
virtual address space. However, Espressif implemented a fixed hardware memory map to keep the
silicon die size minimal:

```
0x00000000 - 0x3FFFFFFF  [Unmapped / Peripherals]
0x3FFE8000 - 0x3FFFFFFF  [DRAM / Data RAM (80 KB)]
0x40000000 - 0x4000FFFF  [Internal ROM (64 KB)]
0x40100000 - 0x4010BFFF  [IRAM / Instruction RAM (48 KB)]
0x40200000 - 0x402FFFFF  [XIP Flash MMU Window (1 MB)]  <-- Fixed 1 MB slot
0x60000000 - 0x60001FFF  [DPORT Hardware Registers]
```

Instruction execution directly from external SPI Flash (*XIP*) is strictly constrained to a
single 1 MB virtual window mapped between *0x40200000* to *0x402FFFFF*.


## Tag SRAM
Because external SPI Flash is far too slow (20-40 MHz over SPI) to supply instructions at full CPU
speed (80 or 160 MHz), execution relies on a fast, on-chip 16 KB or 32 KB Instruction Cache SRAM.

```
[ CPU Core ] ───(Fetch 0x40201234)───► [ Cache Controller & Tag RAM ]
                                                 │
                                     ┌───────────┴───────────┐
                                 (Cache Hit)             (Cache Miss)
                                     │                       │
                                     ▼                       ▼
                              [ SRAM Cache ]     [ SPI Controller Engine ]
```

1. The cache memory is divided into 32-byte lines.
2. Each line is tracked by an entry in Tag RAM, containing a Valid Bit (a boolean indicating 
    whether the cache line holds valid data) and an Address Tag.

**Why the 1 MB Window Exists in Silicon**

The 1 MB virtual execution window is not an arbitrary software limit; it is a physical hardware
constraint driven by manifacturing cost:
- To support a virtual execution window larger than 1 MB simultaneously, every single entry in
  the Tag RAM array would require wider address bits.
- The hardware would need wider silicon comparators on every instruction fetch cycle.
- Restricting the window to 1 MB minimized Tag SRAM and logic gate count, keeps the ESP8266 
   silicon die size ultra-small and cheap to manufacture for sub-$1 IoT boards.


## SPI Flash Mapping Math: Regions vs. Sub-Regions
Because SPI Flash chips are typically 4 MB, 8 MB, or 16 MB in size, accessing code beyond 
the 1 MB mark requires sliding the MMU viewport across physical Flash using 2 MB *Regions* 
and 1 MB *Sub-Regions*.

SPI Flash is divided into 2 MB physical blocks:
```
- Region 0 : 0x000000 - 0x1FFFFF
- Region 1 : 0x200000 - 0x3FFFFF
- Region 2 : 0x400000 - 0x5FFFFF
- Region 3 : 0x600000 - 0x7FFFFF
```

Each 2MB region contains two 1 MB sub-regions:
```
- Sub-Region 0 : Lower 1 MB of the region
- Sub-Region 1 : Upper 1 MB of the region
```

For example, when an application binary is flashed to offset 0x10000 (64 KB):
```
- 0x10000 < 0x200000 -> Region = 0
- 0x10000 < 0x100000 -> Sub-Region = 0
```

If a program or dataset spans beyond 1 MB, or if execution needs to jump to another 1 MB
block in Flash, the MMU window must be dynamically slid to point to that new Flash region.


## Memory Management Unit (MMU) Mechanics
The Xtensa CPU cannot fetch instructions across the SPI bus directly. Instead, the Cache
Controller and MMU sit between the CPU Instruction Bus and the SPI controller peripheral.

The ESP8266 MMU page registers (such as *0x60000218* and *0x6000021C*) do not use complex
multi-level page tables like x86 or ARM MMUs. Instead, they perform a linear base-offset
translation shift:
```
Physical Flash Address = Virtual Address - Virtual Base + Flash Offset
```

**Cache Size Trade-Offs**

- 16 KB Mode (*SOC_CACHE_SIZE = 0*) - Preferred - Gives 16 KB more RAM. The unused half
  of the 32 KB SRAM block is reclaimed and converted into usable Data RAM (*0x3FFE8000* -
  *0x3FFEFFFF*), boosting DRAM from 64 KB to 80 KB.
- 32 KB Mode (*SOC_CACHE_SIZE = 1*) - Used only for large, loop-heavy applications with
  massive code footprints where execution speed inside Flash is heavily bottlenecked by
  cache misses, and where data memory fits comfortably under 64 KB.


## Bootloader & Pipeline Sequence
When the ESP8266 chip resets, internal mask ROM (*0x40000000*) executes first. It reads 
strapping pins (GPIO0, GPIO2, GPIO15) to select the boot mode.

During SPI Flash boot, ROM code initializes the SPI0/SPI1 hardware registers 
(*0x60000200* / *0x60000100*), sends standard SPI commands (*0x03* or *0x3B*), and loads
the first-stage bootloader into IRAM (*0x40100000*). The SPI controller is left running.

**Bootloader Execution Steps**

1. Disable interrupts immediately.
```
rsil a2, 3      # Raise interrupt level to 3 to mask software/hardware IRQs
```
Prevents unexpected interrupts (e.g., timer pulses) from jumping to unmapped
memory while registers are being reconfigured.

2. Clear *.bss* variables in DRAM (*0x3FFE8000*) to zero.

3. Select boot image.

Read partition table, select boot partition, load image header to DRAM using the 
ROM *SPIRead()* service (0x40004B1C), validate header magic bytes, verify header, 
and process the LOAD segments (IRAM, DRAM).

4. Configure MMU and prepare for hand-off.
```
1. Disable cache:
 - Stop cache controller
 - Wait for SPI reads finish
 - Detach AHB bus

2. Configure cache:
 - Cache_Read_Enable(0, 0, 0); // Args: sub_region, region, cache_size

3. Re-enable cache:
 - Reconnect AHB bus
 - Re-enable cache controller
```

5. Hand off execution to the code in Flash.


## Binary Reverse Engineering
Because ESP8266 bare-metal hardware features are not fully covered by official technical 
reference manuals, register addresses and teardown sequences are best double-checked 
directly from official SDK binaries. One effective approach is to compile a minimal 
app using the ESP8266 Non-OS/RTOS SDK and inspect the disassembly.

Inspecting *Cache_Read_Disable_2* disassembly:
```
40104068 <Cache_Read_Disable_2>:
40104068:	f05131      l32r	a3, 401001ac <_init_end+0x12c>  # Load register address
4010406b:	0020c0      memw
4010406e:	0328      	l32i.n	a2, a3, 0                       # Load value at register address
40104070:	ffae42      movi	a4, 0xfffffeff                  # Load bitmask (~0x100)
40104073:	102240      and	    a2, a2, a4                      # Clear bit 8
40104076:	0020c0      memw
40104079:	006322      s32i	a2, a3, 0                       # Write back to register
...
```

Espressif created the *_2* suffix variants to shadow and patch hardware timing bugs in the 
original Mask ROM routines (e.g., *Cache_Read_Disable* and *Cache_Read_Enable*). The early 
Mask ROM routines did not safely handle in-flight SPI hardware transfers or bus decoupling 
steps before toggling the cache power bit. Calling the ROM version during active XIP execution 
could cause memory bus lockups or corrupt cache lines. The SDK *_2* helper functions override 
the ROM implementation by inserting explicit polling loops on *0x600002F8* (*SPI_BUSY_REG*) 
and cleanly toggling *0x60000208* (*SPI_ENABLE_AHB*).


**Decoding Literal Pools (PC-Relative Load Constants)**

The *l32r a3, 401001ac* instruction fetches the 32-bit hardware register address stored 
inside the literal pool at *0x401001ac*. However, disassembling literal pool locations 
as raw executable code produces gibberish because the disassembler tries to interpret 
raw 32-bit address data as Xtensa instruction opcodes (*excw*):
```
401001ab:	000c40        	excw
401001ae:	f83ff0        	excw
```

Because Xtensa LX106 uses *Little-Endian* byte ordering, reading hexadecimal values 
manually across instruction boundaries is error-prone. We can inspect the exact literal 
pool bytes cleanly using *hexdump* or *objdump -s*.

> xtensa-lx106-elf-objdump -s -j .iram0.text app.elf

Outputs:
```
Contents of section .iram0.text:
  ...
  40100190 e8030000 00000000 a08cfe3f 20cb0000  ...........? ...
  401001a0 10d30040 6c92fe3f a4de2140 0c00f03f  ...@l..?..!@...?
  401001b0 f8020060 08020060 fffffdff 00000200  ...`...`........
  ...
```

Here we find the word stored in *0x401001ac*:
```
401001a0 -> 10d30040 
401001a4 -> 6c92fe3f 
401001a8 -> a4de2140 
401001ac -> 0c00f03f -> Little-Endian -> 0x3ff0000c (DPORT_CACHE_CTRL_REG)
```
