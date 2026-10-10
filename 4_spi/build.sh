#!/bin/bash

echo "Build & Deploy"

echo "[1/5] Compile object files"
#
# -mlongcalls : Forces the compiler to emit l32r + callx0 sequences for all 
#               function calls, preventing out-of-range relocation errors 
#               when linking against far-away symbols in ROM or Flash. 
#
#               See spi.c for more details.
#
xtensa-lx106-elf-as app.s -o app.o
xtensa-lx106-elf-gcc -c gpio.c -o gpio.o
xtensa-lx106-elf-gcc -mlongcalls -c spi.c -o spi.o
xtensa-lx106-elf-gcc -c wait.c -o wait.o

echo "[2/5] Link into a minimal ELF"
xtensa-lx106-elf-ld -T app.ld app.o gpio.o spi.o wait.o -o app.elf

echo "[3/5] Convert ELF to ESP8266 flashable image"
esptool.py elf2image app.elf

echo "[4/5] Flash the image to ESP8266"
#
# 0x00000 : Silicon ROM loads this into IRAM at startup.
# 0x10000 : Raw Flash memory location where .irom0.* resides.
#
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash \
    0x00000 app.elf-0x00000.bin \
    0x10000 app.elf-0x10000.bin

echo "[5/5] Clean up"
rm app.o gpio.o spi.o wait.o app.elf app.elf-0x00000.bin app.elf-0x10000.bin

echo "Done."

# picocom -b 74880 /dev/ttyUSB0 # -b 115200
# [ctrl+A ctrl+X] to exit
