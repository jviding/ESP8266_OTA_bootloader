# Raw C
Simple ESP8266 bare-metal app to blink a led. <br />
Runs raw without the espressif framework.

Constitutes of: <br />
- Linker script <br />
- C program     <br />
- Build commands

Requires Xtensa toolchain.

# Instructions
1) Install Xtensa and set its path in build.sh. <br />
2) Execute build.sh, to generate app.elf.       <br />
3) Add image headers:                           <br />
\$ esptool.py elf2image app.elf                 <br />
4) Flash:                                       <br />
\$ esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin
