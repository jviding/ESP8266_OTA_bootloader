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
  .data : ALIGN(4)
  {
    *(.data)
    *(.data.*)
  } >dram0_0_seg :dram0_0_phdr

  .bss ALIGN(8) (NOLOAD) : ALIGN(4)
  {
    _bss_start = ABSOLUTE(.);
    *(.bss)
    *(.bss.*)
    _bss_end = ABSOLUTE(.);
  } >dram0_0_seg :dram0_0_bss_phdr

  .text : ALIGN(4)
  {
    *(.literal .text .literal.* .text.*)
  } >iram1_0_seg :iram1_0_phdr
}
