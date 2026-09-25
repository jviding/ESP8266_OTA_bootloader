ENTRY(call_user_start)

MEMORY
{
  iram1_0_seg :   org = 0x40100000, len = 0x8000   /* 32 KB IRAM                    */
  drom0_0_seg :   org = 0x3FFE8000, len = 0x100000 /* 1 MB Flash mapped to Data Bus */

  /* irom0_0_seg :   org = 0x40200000, len = 0xec000  */
  /* ~1 MB Mapped Flash */
}

PHDRS
{
  iram1_0_phdr PT_LOAD;
  drom0_0_phdr PT_LOAD;

  /* irom0_0_phdr PT_LOAD; */
}

SECTIONS
{
  /* ==================================== */
  /* Output section for constants in IROM */
  /* ==================================== */
  .rodata : ALIGN(4)
  {
    *(.rodata)
    *(.rodata.*)
  } >drom0_0_seg :drom0_0_phdr
  
  /* >irom0_0_seg :irom0_0_phdr */


  /* ========================================== */
  /* Output section for 32-bit literals in IRAM */
  /* ========================================== */
  .literal : ALIGN(4)
  {
    *(.literal)
    *(.literal.*)
  } >iram1_0_seg :iram1_0_phdr


  /* ======================================= */
  /* Output section for instructions in IRAM */
  /* ======================================= */
  .text : ALIGN(4)
  {
    *(.text)
    *(.text.*)
  } >iram1_0_seg :iram1_0_phdr
}
