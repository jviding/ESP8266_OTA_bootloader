ENTRY(call_user_start)
/*
  Defines the program's entry point.

  This tells the linker to mark 'call_user_start' as the first
  instruction to be executed after the bootloader has finished
  loading the program image.

  'call_user_start' is defined in our C source (app.c), and 
  it's the true beginning of the bare-metal program.
*/


MEMORY
{
  iram1_0_seg :   org = 0x40100000, len = 0x8000
}
/*
  Defines the program's memory region(s).

  iram1_0_seg:
    - 'org' is the origin address (start of IRAM region)
    - 'len' is the size of the region (32 KB here)
    - This matches the ESP8266 IRAM mapping used by the ROM

  The ESP8266 will execute our code directly from IRAM, so 
  we will place the .text section inside this region.
*/


PHDRS
{
  iram1_0_phdr PT_LOAD;
}
/*
  Defines program headers.

  PT_LOAD tells the ROM bootloader that this segment must be loaded
  into memory before execution. The ESP8266 ROM bootloader reads
  these headers to know which sections to copy into IRAM/DRAM.
*/


SECTIONS
{
  .text : ALIGN(4)
  {
    *(.literal .text .literal.* .text.*)
  } >iram1_0_seg :iram1_0_phdr
}
/*
  Places the .text section (and literal pools) into IRAM.

  .text : ALIGN(4)
    - Ensures the section starts at a 4-byte boundary.
    - Required because Xtensa instructions and literal pools
      must be word-aligned.

  *(.literal .text .literal.* .text.*)
    - Xtensa uses literal pools for 32-bit constants.
    - The compiler emits them into .literal and .literal.*.
    - The code itself goes into .text and .text.*.
    - This merges both into a single contiguous block.

  >iram1_0_seg
    - Places the merged .text section into the IRAM region
      defined earlier.

  :iram1_0_phdr
    - Associates this section with the PT_LOAD program header.
    - Ensures the bootloader copies it into IRAM before jumping
      to the entry point.

  Summary:
    - This section layout is what makes the ESP8266 able to
      execute this bare‑metal program directly from IRAM.
*/