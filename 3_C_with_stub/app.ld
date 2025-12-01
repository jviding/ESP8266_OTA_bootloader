MEMORY
{
  dram0_0_seg :                         org = 0x3FFE8000, len = 0x14000
  iram1_0_seg :                         org = 0x40100000, len = 0x8000
  irom0_0_seg :                         org = 0x40240000, len = 0x3C000
}

PHDRS
{
  dram0_0_phdr PT_LOAD;
  dram0_0_bss_phdr PT_LOAD;
  iram1_0_phdr PT_LOAD;
  irom0_0_phdr PT_LOAD;
}

ENTRY(call_user_start)

SECTIONS
{

  .data : ALIGN(4)
  {
    _data_start = ABSOLUTE(.);
    *(.data)
    *(.data.*)
    _data_end = ABSOLUTE(.);
  } >dram0_0_seg :dram0_0_phdr

  .rodata : ALIGN(4)
  {
    _rodata_start = ABSOLUTE(.);
    *(.rodata)
    *(.rodata.*)
    _rodata_end = ABSOLUTE(.);
  } >dram0_0_seg :dram0_0_phdr

  .bss ALIGN(8) (NOLOAD) : ALIGN(4)
  {
    . = ALIGN (8);
    _bss_start = ABSOLUTE(.);
    *(.bss)
    *(.bss.*)
    . = ALIGN (8);
    _bss_end = ABSOLUTE(.);
  } >dram0_0_seg :dram0_0_bss_phdr

  /* --- STACK DEFINITION --- /
  /* The __stack symbol will hold the value 0x3FFFC000 */
  . = ALIGN(16);
  __stack = ORIGIN(dram0_0_seg) + LENGTH(dram0_0_seg);

  .text : ALIGN(4)
  {
    _stext = .;
    _text_start = ABSOLUTE(.);
    . = ALIGN (16);
    *(.literal .text .literal.* .text.*)
    _text_end = ABSOLUTE(.);
    _etext = .;
  } >iram1_0_seg :iram1_0_phdr

  .irom0.text :
  {
    _idata_start = LOADADDR(.data);
    . = ALIGN (4);
  } > irom0_0_seg :irom0_0_phdr
}
