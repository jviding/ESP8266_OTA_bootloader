#!/bin/bash

# Set xtensa path
PATH_xtensa="/home/jasu/.arduino15/packages/esp8266/tools"


xtensa_lx106_elf_gcc="$PATH_xtensa/xtensa-lx106-elf-gcc/3.1.0-gcc10.3-e5f9fec/bin/xtensa-lx106-elf-gcc"


echo "Building..."

echo "[1/3] Compile object file"
"$xtensa_lx106_elf_gcc" -c app.c -o app.o

echo "[2/3] Compile simple elf"
"$xtensa_lx106_elf_gcc" -nostdlib -Wl,-T,app.ld -Wl,-e,call_user_start app.o -o app.elf

echo "[3/3] Clean up"
rm app.o

echo "Build completed."
