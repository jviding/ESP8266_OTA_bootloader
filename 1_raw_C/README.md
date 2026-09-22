# ESP8266 Bare-Metal LED Blink
No framework, no Espressif SDK. Just the raw machine instructions.

Constitutes of:                                             <br />
- **C source** - code to manipulate the GPIO registers      <br />
- **Linker script** - defines memory layout and entry point <br />
- **Build script** - compiles, links, and flashes an ESP8266 image

Requires:
- **Xtensa LX106 toolchain** (xtensa-lx106-elf-*)
- **esptool.py**

Make the build tools available via PATH. <br />
Add user in the dialout group, for /dev/ttyUSBx access.


## Build & Delpoy
Run the pipeline with:

> \$ sh build.sh

See **inspect.sh** for tools to inspect the intermediate files. <br />
For example, disassemble the ELF:

> \$ xtensa-lx106-elf-objdump -d app.elf

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
