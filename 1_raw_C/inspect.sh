#!/bin/bash

# Call with:
# > sh inspect.sh <filename>

## READELF

# 1. Inspect ELF header
xtensa-lx106-elf-readelf -h $1

# 2. Inspect section headers
xtensa-lx106-elf-readelf -S $1

# 3. Inspect program headers
xtensa-lx106-elf-readelf -l $1

# 4. Inspect symbol table
xtensa-lx106-elf-readelf -s $1


## NM

# 1. List symbol table
# To verify function is present and its address
xtensa-lx106-elf-nm $1 #| grep 'call_user_start'


## OBJDUMP

# 1. Inspect sections layout
xtensa-lx106-elf-objdump -h $1

# 2. Disassemble
xtensa-lx106-elf-objdump -d $1

# 3. Disassemble all sections
xtensa-lx106-elf-objdump -h $1 -d $1 | less

# 4. Display sections contents
xtensa-lx106-elf-objdump -h $1 -s $1
