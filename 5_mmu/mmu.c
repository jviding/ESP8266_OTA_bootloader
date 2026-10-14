#include <stdint.h>

/*
 * DPORT System Cache Control Register
 * - Bit 8: L1 Instruction Cache Enable switch.
 * - Controls whether the CPU's on-chip SRAM cache unit is powered and active. 
 */

#define DPORT_CACHE_CTRL_REG  (*(volatile uint32_t *)0x3FF0000C)

/*
 * DPORT AHB-to-SPI Bridge Routing Register
 * - Bit 17: SPI_ENABLE_AHB switch.
 * - Controls the internal hardware multiplexer connecting the CPU instruction
 *   bus (virtual addresses 0x40200000 - 0x402FFFFF) to the SPI Flash controller. 
 */
#define DPORT_SPI_CACHE_REG   (*(volatile uint32_t *)0x60000208)

/*
 * SPI Controller Flash Status Register
 * - Bit 0 (and higher status bits): Indicates if the SPI Flash hardware engine
 *   is currently reading or writing bytes across the external SPI bus lines.
 * - Value 0 = Idle / Ready; Non-Zero = Busy transferring data. 
 */
#define SPI_BUSY_REG          (*(volatile uint32_t *)0x600002F8)

/*
 * Mask ROM Service Function (Cache_Read_Enable)
 */
typedef void (*rom_cache_read_enable_fn)(uint8_t sub_region, uint8_t region, uint8_t cache_size);
#define Cache_Read_Enable ((rom_cache_read_enable_fn)0x40004678)


void init_mmu_and_cache(void) {

    /* -----------------------------------------
     * STEP 1: DISABLE CACHE & SAFE BUS TEARDOWN
     * ----------------------------------------- */
    
    /*
     * Clear Bit 8 of DPORT_CACHE_CTRL_REG.
     * Immediately halts the L1 Cache Controller. The CPU stops processing
     * instruction fetches from Tag RAM or serving hits from the 16 KB SRAM.
     */
    DPORT_CACHE_CTRL_REG &= ~(1 << 8);

    /*
     * Hardware Safety Spin-Loop:
     * Wait for SPI_BUSY_REG to return 0.
     * Prevents cutting off or re-routing the AHB bus while an active 32-byte
     * cache line fill is mid-transfer over the physical SPI pins. Interrupting
     * an active transaction would leave the Flash chip stuck in read mode.
     */
    while (SPI_BUSY_REG != 0) {
        __asm__ __volatile__("nop");
    }

    /*
     * Clear Bit 17 of DPORT_SPI_CACHE_REG.
     * Unhooks the CPU's AHB instruction bus from the SPI Flash peripheral.
     * The virtual execution window (0x40200000) is now safely isolated.
     */
    DPORT_SPI_CACHE_REG &= ~(1 << 17);

    /* ----------------------------------
     * STEP 2: PROGRAM MMU PAGE REGISTERS
     * ---------------------------------- */

    /*
     * Execute the internal Mask ROM function at 0x40004678.
     * Passes (sub_region=0, region=0, cache_size=0):
     *  - Maps physical Flash offset 0x000000 - 0x0FFFFF into DPORT MMU registers
     *    0x60000218 / 0x6000021C.
     *  - Selects 16KB Cache mode, leaving 80KB of DRAM available at 0x3FFE8000.
     *  - Flushes internal Tag RAM valid bits.
     */
    Cache_Read_Enable(0, 0, 0);

    /* ----------------------------------------------
     * STEP 3: RE-ENABLE BUS ROUTING & POWER ON CACHE
     * ---------------------------------------------- */

    /*
     * Set Bit 17 of DPORT_SPI_CACHE_REG.
     * Reconnects the AHB instruction bus to the SPI controller. Instruction
     * fetches targeting 0x40200000 are now mapped to Region 0 / Sub-Region 0.
     */
    DPORT_SPI_CACHE_REG |= (1 << 17);

    /*
     * Set Bit 8 of DPORT_CACHE_CTRL_REG.
     * Enables the L1 Instruction Cache hardware. The CPU can now fetch 
     * and cache code directly from external Flash (XIP).
     */
    DPORT_CACHE_CTRL_REG |= (1 << 8);


    /* --------------------------------------------------
     * STEP 4: PIPELINE & MEMORY SYNCHRONIZATION BARRIERS
     * -------------------------------------------------- */

    /* 
     * Executing dual Xtensa pipeline barriers:
     * - "memw"  (Memory Write Barrier): Guarantees that all register writes to 
     *           0x3FF0000C and 0x60000208 physically reach memory-mapped hardware 
     *           before any subsequent instructions execute.
     * - "isync" (Instruction Fetch Synchronize): Flushes the CPU's instruction 
     *           prefetch buffer, ensuring the CPU refetches fresh instructions 
     *           from the updated 0x40200000 MMU mapping rather than executing 
     *           stale instructions from the pipeline.
     * - "memory" clobber tells GCC not to reorder memory reads/writes across 
     *           this boundary.
     */
    asm volatile ("memw\n\tisync" ::: "memory");
}
