#!/bin/bash

echo "Build & Deploy"

echo "[1/5] Compile object file"
#
# Previously, we had:
# > xtensa-lx106-elf-gcc -c app.c -o app.o
#
# This means gcc passes the code through the C preprocessor (cpp) before assembling.
#
# The gcc compilation flow:
#  1. Preprocessing (cpp)       - Source Code (.c, .cpp, .h)
#  2. Compilation (gcc, g++)    - Include Header, Expand Macro (.i, .ii)
#  3. Assemble (as)             - Assembly Code (.s)
#  4. Linking (ld)              - Machine Code (.o, .obj)
#
# Now, we bypass the cpp driver, and invoke the assembler directly.
#
xtensa-lx106-elf-as app.s -o app.o

echo "[2/5] Link into a minimal ELF"
#
# Previously, we had:
# > xtensa-lx106-elf-gcc -nostdlib -Wl,-T,app.ld -Wl,-e,call_user_start app.o -o app.elf
#
# This means the gcc driver inserts implicit arch-specific configurations before executing ld.
# The extra flags added by gcc can be seen by adding -v (verbose) flag in the command, above.
#
# Now, we bypass the cpp driver, and invoke the linker directly.
#
xtensa-lx106-elf-ld -T app.ld app.o -o app.elf

echo "[3/5] Convert ELF to ESP8266 flashable image"
esptool.py elf2image app.elf

echo "[4/5] Flash the image to ESP8266"
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 app.elf-0x00000.bin

#echo "[5/5] Clean up"
#rm app.o app.elf app.elf-0x00000.bin

echo "Done."
