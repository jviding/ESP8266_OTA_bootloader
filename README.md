# ESP8266 OTA Bootloader
This project explores bare-metal programming on the ESP8266, focusing on the fundamental concepts
required to build a custom software bootloader on the Xtensa architecture. The final bootloader
will support asymmetric partitioning and Over-the-Air (OTA) updates. To eliminate unnecessary
abstraction, the project avoids high-level frameworks and SDKs, operating directly on the hardware.

Organized as a series of exercises, each installment dives into a specific low-level concept. While
developed for the Xtensa LX106, the principles covered apply broadly across processor architectures.


## 1. ELF files
Inspect, disassemble, and analyze ELF executables and raw binary files to understand how compiled
code maps onto the Xtensa architecture.

## 2. Sectioning
Configure bare-metal memory layouts, stack allocation, and section mapping on the Xtensa LX106
using linker scripts.

## 3. Call0
Explore C and assembly interoperation, parameter passing, and register preservation under the
Xtensa Call0 ABI rules.

## 4. TBD


