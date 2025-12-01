#!/bin/bash

PATH_xtensa="/home/jasu/.arduino15/packages/esp8266/tools/xtensa-lx106-elf-gcc/3.1.0-gcc10.3-e5f9fec/bin"

xtensa_lx106_elf_objdump="$PATH_xtensa/xtensa-lx106-elf-objdump"
xtensa_lx106_elf_readelf="$PATH_xtensa/xtensa-lx106-elf-readelf"
xtensa_lx106_elf_nm="$PATH_xtensa/xtensa-lx106-elf-nm"

## READELF

# 1. Inspect ELF header
#"$xtensa_lx106_elf_readelf" -h $1

# 2. Inspect section headers
#"$xtensa_lx106_elf_readelf" -S $1

# 3. Inspect program headers
#"$xtensa_lx106_elf_readelf" -l $1

# 4. Inspect symbol table
#"$xtensa_lx106_elf_readelf" -s $1 #| grep 'call_user_start'


## NM

# 5. List symbol table
# To verify function is present and its address
#"$xtensa_lx106_elf_nm" $1 #| grep 'call_user_start'


## OBJDUMP

# 6. Inspect sections layout
#"$xtensa_lx106_elf_objdump" -h $1

# 7. Disassemble all sections
#"$xtensa_lx106_elf_objdump" -d $1 | less
