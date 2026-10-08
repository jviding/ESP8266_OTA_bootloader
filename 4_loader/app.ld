ENTRY(call_user_start)

MEMORY
{
  iram1_0_seg :   org = 0x40100000, len = 0x8000
  irom0_0_seg :   org = 0x40210000, len = 0x40000
}

PHDRS
{
  iram1_0_phdr PT_LOAD;
  irom0_0_phdr PT_LOAD;
}

SECTIONS
{
  /* ======================= */
  /* FLASH (IROM) / Constant */
  /* ======================= */
  .irom0.rodata : ALIGN(4)
  {
    *(.irom0.rodata .irom0.rodata.*)
  } >irom0_0_seg :irom0_0_phdr

  /* =================== */
  /* FLASH (IROM) / Code */
  /* =================== */
  .irom0.text : ALIGN(4)
  {
    LONG(_irom0_text_end - _irom0_text_start);    /* Emit a 32-bit word containing section byte size */
    _irom0_text_start = .;                        /* Mark absolute start of this section in Flash */
    *(.irom0.literal .irom0.literal.*)
    *(.irom0.text .irom0.text.*)
    . = ALIGN(4);
    _irom0_text_end = .;                          /* Mark absolute end of this section in Flash */
  } >irom0_0_seg :irom0_0_phdr

  /* ==================== */
  /* IRAM / Executed code */
  /* ==================== */
  .text : ALIGN(4)
  {
    *(.literal .literal.*)
    *(.text .text.*)
  } >iram1_0_seg :iram1_0_phdr
}
