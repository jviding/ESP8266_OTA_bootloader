# Raw C
Simple ESP8266 bare-metal app to blink a led. <br />
Runs raw without the espressif framework.

Main differences to 2_raw_asm:          <br />
- Linker script expanded                <br />
- Assembly stub jumps to C program      <br />
- Stackpointer alignment                <br />
- Literal pool management               <br />
- Memory management for .bss and .data sections

Requires Xtensa toolchain.

# Highlights
- C program compiles now normally.              <br />
- Stub transfers execution to C program.        <br />
- Stub initializes C variables (.bss and .data).

# Instructions
1) Install Xtensa and set its path in build.sh. <br />
2) Execute build.sh, to generate app.elf.       <br />
3) Add image headers:                           <br />
\$ esptool.py elf2image app.elf                 <br />
4) Flash:                                       <br />
\$ esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin

# Debugging
Useful snippets in inspect.sh
