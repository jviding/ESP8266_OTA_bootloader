#!/bin/bash
# ESP8266 Bare-Metal Build Script
# ----------------------------------------
# Smallest possible build pipeline for ESP8266 bare-metal work:
#   1. Compile C code into an object file
#   2. Link it into an ELF using a custom linker script
#   3. Convert the ELF into a flashable ESP8266 image
#   4. Flash the image to ESP8266 over USB
#

echo "Build & Deploy"

echo "[1/5] Compile object file"
#
# -c : Compile only; do not link.
#    Produces app.o containing:
#       - machine code for each function
#       - relocation entries describing how symbols must be fixed up at link time
#
xtensa-lx106-elf-gcc -c app.c -o app.o

echo "[2/5] Link into a minimal ELF"
#
# -nostdlib
#   Do NOT link against: libc, libgcc, or crt0.o / startupfiles
#   NOTICE: There will be NO memory initialization logic!
#
# -Wl,-T,app.ld          
#   Pass "-T app.ld" to the linker.
#   This tells ld to use app.ld as the linker script.
#
# -Wl,-e,call_user_start 
#   Pass "-e call_user_start" to the linker.
#   This sets the ELF entry point to the symbol call_user_start.
#   The ESP8266 bootloader jumps to this address after loading the image.
# 
xtensa-lx106-elf-gcc -nostdlib -Wl,-T,app.ld -Wl,-e,call_user_start app.o -o app.elf

echo "[3/5] Convert ELF to ESP8266 flashable image"
#
# elf2image
#   - Reads the ELF file
#   - Extracts loadable segments (.text, .data)
#   - Applies ESP8266 image header format
#   - Writes a .bin file suitable for flasing
#
# The .bin file contains:
#   - ESP8266 image header (entry point, flash mode, flash size)
#   - Segment table
#   - Checksums
#
esptool.py elf2image app.elf

echo "[4/5] Flash the image to ESP8266"
#
# Flash the image to address 0x00000
# The ESP8266 ROM bootloader loads the first image from this address
#
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin

echo "[5/5] Clean up"
# Remove the intermediate files.
rm app.o app.elf app.elf-0x00000.bin

echo "Done."
