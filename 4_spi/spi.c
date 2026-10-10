#include <stdint.h>

/* ---------------------------------------------------
*  ESP8266 ROM FUNCTION POINTER - SPIRead (0x40004B1C)
*  ---------------------------------------------------
* Static, precompiled function hardcoded into the ESP8266 internal Boot ROM 
* (0x40000000 address range). Performs a raw hardware SPI transaction to read
* bytes from physical Flash chip offsets directly into RAM.
*
* The SPIRead symbol address (0x40004b1c) is provided by our linker script.
*
* A direct 'call0' instruction on Xtensa LX106 has a PC-relative reach of 512 KB.
* Because the distance between IRAM (0x40100000) and Boot ROM (0x40004B1C) is ~1 MB,
* we compile in build.sh with the `-mlongcalls` compiler flag. This forces GCC to 
* emit an `l32r` + `callx0` instruction sequence, allowing an indirect call across 
* the full 32-bit address space and preventing a relocation error.
*/
extern int SPIRead(uint32_t flash_addr, uint32_t *buf, uint32_t size);


/* ---------------------
*  BARE-METAL FLASH READ
*  --------------------- */
uint32_t get_irom_val(uint32_t flash_offset) {
    /* 
     * HARDWARE CONSTRAINT: SPIRead uses 32-bit hardware FIFO registers.
     * The destination RAM buffer MUST be 4-byte aligned in memory, otherwise
     * unaligned memory writes will cause a hardware LoadStoreAlignment exception. 
     */
    __attribute__((aligned(4))) uint32_t read_buffer = 0;

    /*
     * Execute Physical SPI Flash Read
     * Arguments:
     *   - flash_addr: Physical byte offset on SPI Flash
     *   - buf:        4-byte aligned RAM pointer to receive data
     *   - size:       Number of bytes to transfer (4 bytes)
     */
    SPIRead(flash_offset, &read_buffer, 4);

    /*
     * Return the 32-bit value read from Flash
     */
    return read_buffer;
}
