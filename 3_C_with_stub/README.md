# Raw C
Simple ESP8266 bare-metal app to blink a led. <br />
Runs raw without the espressif framework.

Constitutes of:      <br />
- Linker script      <br />
- Assembly stub      <br />
- C program          <br />
- Build commands

Build requires the Xtensa toolchain.

# Highlights
- Use literals from linker script.              <br />
- C program compiles now normally.              <br />
- Stub transfers execution to C program.        <br />
- Stub zeroes out .bss section.

Note: ROM bootloader seems to copy .data to DRAM. <br />
While .bss section appears to not be zeroed out.


# Instructions
1) Install Xtensa and set its path in build.sh. <br />
2) Build generates app.elf.                     <br />
\$ sh build.sh                                  <br />
3) Add image headers:                           <br />
\$ esptool.py elf2image app.elf                 <br />
4) Flash:                                       <br />
\$ esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin

# Debugging
Useful snippets in inspect.sh
