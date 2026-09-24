#!/bin/bash
# This pipeline is explained in:
# ../1_ELF_files/build.sh

echo "Build & Deploy"

echo "[1/5] Compile object file"
xtensa-lx106-elf-gcc -c app.S -o app.o

echo "[2/5] Link into a minimal ELF"
xtensa-lx106-elf-gcc -nostdlib -Wl,-T,app.ld -Wl,-e,call_user_start app.o -o app.elf

echo "[3/5] Convert ELF to ESP8266 flashable image"
esptool.py elf2image app.elf

echo "[4/5] Flash the image to ESP8266"
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin

echo "[5/5] Clean up"
rm app.o app.elf app.elf-0x00000.bin

echo "Done."
