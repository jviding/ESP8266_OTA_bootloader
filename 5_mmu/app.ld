ENTRY(call_user_start)

MEMORY
{
  iram1_0_seg :   org = 0x40100000, len = 0x8000  /* 32 KB IRAM */
  irom0_0_seg :   org = 0x40210000, len = 0x80000 /* MMU Mapped Flash Page 1+ */
}

PHDRS
{
  iram1_0_phdr PT_LOAD;
  irom0_0_phdr PT_LOAD;
}

SECTIONS
{
  .irom0.text : ALIGN(4)
  {
    *(.irom0.literal .irom0.literal.*)
    *(.irom0.text .irom0.text.*)
  } >irom0_0_seg :irom0_0_phdr

  .text : ALIGN(4)
  {
    *(.literal .literal.*)
    *(.text .text.*)
  } >iram1_0_seg :iram1_0_phdr
}
