#include <stdint.h>

/* ---------------------------------------------------
*  ESP8266 ROM FUNCTION POINTER - SPIRead (0x40004B1C)
*  ---------------------------------------------------
* Static, precompiled function hardcoded into the ESP8266 internal Boot ROM 
* (0x40000000 address range). Performs a raw hardware SPI transaction to read
* bytes from physical Flash chip offsets directly into RAM.
*
* The address was discovered from the official ESP8266_RTOS_SDK linker script.
* Bare-metal SPI is not well covered by the official ESP8266 technical documentation.
*/
typedef int (*rom_spi_read_fn)(uint32_t flash_addr, uint32_t *buf, uint32_t size);
#define SPIRead ((rom_spi_read_fn)0x40004B1C)

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
