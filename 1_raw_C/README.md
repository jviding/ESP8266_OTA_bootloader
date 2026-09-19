# Raw C
Simple ESP8266 Bare-Metal LED Blink. <br />
Runs without the espressif SDK or framework.

Constitutes of: <br />
- **Linker script** - defines memory layout and entry point <br />
- **C source** - code to manipulate the GPIO registers      <br />
- **Build script** - compiles, links, and produces a flashable image

Build requires the Xtensa LX106 toolchain (xtensa-lx106-elf-*).

## Build & Flash
Build a flashable ESP8266 image:
> \$ sh build.sh

Flash the image over USB:
> \$ esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin

## Inspect & Analyze
Inspection tools are listed in **inspect.sh**.

Example: disassemble the ELF
> \$ xtensa-lx106-elf-objdump -d app.elf

### Section layout
This bare-metal build places everything inside a single **.text** section:

> .text {
>
>>   0x40100000-0x4010000c : Literal pool (4x 32-bit words)
>>
>>   0x40100010-0x40100091 : Xtensa machine instructions
>
> }

The literal pool contains constants referenced by l32r instructions. <br />
The rest is the actual program code starting at call_user_start.
