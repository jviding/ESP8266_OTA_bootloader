# ================================
# *** CONSTANT IN FLASH (IROM) ***
# ================================
    .section .irom0.rodata, "a", @progbits
    .align 4
    .global g_irom_val
    .type   g_irom_val, @object

.L_IROM_VAL:              .word   0xDEADBEEF   # Store in Flash (IROM)

# ==============================
# *** void call_user_start() ***
# ==============================
    .section .literal
    .align 4

.L_VAL_EXPECTED:          .word   0xDEADBEEF   # Expected value in Flash (IROM)

.L_SPI_READ_ADDR:         .word   0x40004B1C   # ROM SPIRead address
.L_FLASH_OFFSET:          .word   0x00010000   # Physical SPI Flash offset
.L_DRAM_TARGET_ADDR:      .word   0x3FFF8000   # Target VM address in DRAM
.L_IRAM_TARGET_ADDR:      .word   0x40105000   # Target VM address in IRAM

.L_GPIO_ENABLE:           .word   0x60000310
.L_GPIO_OUT_SET:          .word   0x60000304
.L_GPIO_OUT_CLEAR:        .word   0x60000308

    .text
    .align 4
    .global call_user_start
    .type   call_user_start, @function

call_user_start:
    # --- GPIO enable ---
    l32r a2, .L_GPIO_ENABLE       # a2 = Gpio enable address
    movi a3, 4                    # a3 = pin 4
    call0 gpio_enable             # gpio_enable(a2, a3)

    # =====================
    # --- Test SPI Read ---       # Read .L_IROM_VAL with C function
    # =====================
    l32r a2, .L_FLASH_OFFSET      # Load SPI Flash offset
    call0 get_irom_val            # SPI Read from offset
    l32r a3, .L_VAL_EXPECTED      # Load Expected value
    bne  a2, a3, .L_halt          # If read != expected, trap CPU

    # =======================
    # --- SPI Copy to RAM ---     # Copy wait() from Flash (IROM) to IRAM
    # =======================
    # -----------------------------------------------
    # STEP 1: Read wait() size from Flash (offset +4)
    # -----------------------------------------------
    l32r a5, .L_SPI_READ_ADDR     # Load ROM SPIRead address
    l32r a2, .L_FLASH_OFFSET      # Load SPI Flash offset
    addi a2, a2, 4                # +4 (target 2nd word = size)            
    l32r a3, .L_DRAM_TARGET_ADDR  # Destination buffer = DRAM
    movi a4, 4                    # Length = 4 bytes (1 word)
    callx0 a5                     # SPIRead(a2, a3, a4)

    # --------------------------------------------------
    # STEP 2: Load size into a12 (Callee-saved register)
    # --------------------------------------------------
    l32r a2, .L_DRAM_TARGET_ADDR
    l32i a12, a2, 0

    # ------------------------------------------------------
    # STEP 3: Read wait() payload (offset +8) to DRAM buffer
    # ------------------------------------------------------
    l32r a5, .L_SPI_READ_ADDR     # Load ROM SPIRead address
    l32r a2, .L_FLASH_OFFSET      # Load SPI Flash offset
    addi a2, a2, 8                # +8 (target 3rd word = code start)
    l32r a3, .L_DRAM_TARGET_ADDR  # Destination buffer = DRAM                 
    mov  a4, a12                  # Load size from a12 into a4
    callx0 a5                     # SPIRead(src, dst, len)

    # ----------------------------------------------------
    # STEP 4: Copy wait() payload from DRAM buffer to IRAM
    # ----------------------------------------------------
    l32r a2, .L_DRAM_TARGET_ADDR  # Source: DRAM buffer
    l32r a3, .L_IRAM_TARGET_ADDR  # Destination: IRAM
    mov  a4, a12                  # Load size from a12 into a4

.L_copy_loop:
    l32i a5, a2, 0
    s32i a5, a3, 0
    addi a2, a2, 4
    addi a3, a3, 4
    addi a4, a4, -4
    bnez a4, .L_copy_loop

    isync                         # Flush/Synchronize instruction pipeline
    
    # -----------------------------
    # STEP 5: Call wait() from IRAM
    # -----------------------------
    l32r a12, .L_IRAM_TARGET_ADDR

.L_loop:
    # --- LED BLINK ---
    l32r a2, .L_GPIO_OUT_CLEAR    # a2 = Gpio clear address
    movi a3, 4                    # a3 = pin 4
    call0 gpio_set_low            # gpio_set_low(a2, a3)

    callx0 a12                    # wait()

    l32r a2, .L_GPIO_OUT_SET      # a2 = Gpio set address
    movi a3, 4                    # a3 = pin 4
    call0 gpio_set_high           # gpio_set_high(a2, a3)
    
    callx0 a12                    # wait()
    j .L_loop

.L_halt:
    ill
