ENTRY(call_user_start)

MEMORY
{
  iram1_0_seg :   org = 0x40100000, len = 0x8000
}

PHDRS
{
  iram1_0_phdr PT_LOAD;
}

SECTIONS
{
  .text : ALIGN(4)
  {
    *(.literal .text .literal.* .text.*)
  } >iram1_0_seg :iram1_0_phdr
}
