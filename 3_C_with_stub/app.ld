ENTRY(call_user_start)

MEMORY
{
  dram0_0_seg :   org = 0x3FFE8000, len = 0x14000
  iram1_0_seg :   org = 0x40100000, len = 0x8000
}

PHDRS
{
  dram0_0_phdr PT_LOAD;
  dram0_0_bss_phdr PT_LOAD;
  iram1_0_phdr PT_LOAD;
}

SECTIONS
{
  .rodata : ALIGN(4)
  {
    *(.rodata)
    *(.rodata.*)
  } >dram0_0_seg :dram0_0_phdr

  .bss : ALIGN(4)
  {
    _bss_start = .;
    *(.bss)
    *(.bss.*)
    *(COMMON)         /* GCC emits uninitialized global C variables by default as common. */
    . = ALIGN(4);     /* Pad the end of BSS to a full 4-byte boundary */
    _bss_end = .;
  } >dram0_0_seg :dram0_0_bss_phdr

  .text : ALIGN(4)
  {
    *(.literal)
    *(.literal.*)
    *(.text)
    *(.text.*)
  } >iram1_0_seg :iram1_0_phdr  
}
