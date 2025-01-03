FlashData_t .struct
    vendorID .byte 0
    chipID  .byte 0
.endstruct

FLASH_CHIP .dstruct FlashData_t


flashcart .namespace

WINDOW_FLASH = $6000
; window at $6000 (block 3) is used for flash blocks=> MMU_REG = 8+3
;
; Address $5555 in chip is in block $82 and when block $82 is mapped to $6000 the address $5555
; is seen as $7555
; Address $2AAA in chip is in block $81 and when block $81 is mapped to $6000 the address $2AAA
; is seen as $6AAA


MMU_TEMP .byte 0
MMU_REG = 11

saveMMU .macro mmuReg
    lda \mmuReg
    pha
.endmacro

restoreMMU .macro mmuReg
    pla
    sta \mmuReg
.endmacro

send5555AA .macro
    lda #$82
    sta MMU_REG
    lda #$AA
    sta $7555
.endmacro

send2AAA55 .macro
    lda #$81
    sta MMU_REG
    lda #$55
    sta $6AAA
.endmacro

send5555XX .macro xx
    lda #$82
    sta MMU_REG
    lda #\xx
    sta $7555
.endmacro


getProductId    
    #saveMMU MMU_REG

    ; send command "Software ID Entry"
    #send5555AA
    #send2AAA55
    #send5555XX $90

    lda WINDOW_FLASH
    sta FLASH_CHIP.vendorID
    lda WINDOW_FLASH + 1
    sta FLASH_CHIP.chipID

    ; send command "Software ID Exit"
    #send5555AA
    #send2AAA55
    #send5555XX $F0

    #restoreMMU MMU_REG
    rts


eraseChip
    #saveMMU MMU_REG

    ; send command Chip-Erase
    #send5555AA
    #send2AAA55
    #send5555XX $80
    #send5555AA
    #send2AAA55
    #send5555XX $10

    ; data sheet says that this needs at max 100ms
    jsr wait250ms

    #restoreMMU MMU_REG
    rts


; carry is set if an error occurred
overwrite8KBlock
    ; make sure we address the blocks in the flash cart not normal flash
    ora #$80    
    sta BLOCK_TEMP

    jsr erase8KBlock
    lda BLOCK_TEMP
    jsr program8KBlock
    lda BLOCK_TEMP
    jsr verify8KBlock
    rts


; carry is set if differences are detected
verify8KBlock
    ; make sure we address the blocks in the flash cart not normal flash
    ora #$80
    sta BLOCK_TEMP

    #load16BitImmediate WINDOW_MEM, PTR_SOURCE
    #load16BitImmediate WINDOW_FLASH, PTR_TARGET
    stz COUNT_PAGE

    #saveMMU MMU_REG

    ; bring flash page into view
    lda BLOCK_TEMP
    sta MMU_REG

_compareNextPage
    ldy #0
    ; copy 8K block
_comparePage
    ; verify single page
    lda (PTR_SOURCE), y
    cmp (PTR_TARGET), y
    bne _error
    iny
    bne _comparePage
    ; update source and target addresses
    inc PTR_SOURCE + 1
    inc PTR_TARGET + 1
    ; increment page counter
    inc COUNT_PAGE
    lda COUNT_PAGE
    cmp #32
    bne _compareNextPage

    #restoreMMU MMU_REG
    clc
    rts
_error
    #restoreMMU MMU_REG
    sec
    rts


COUNT_PAGE .byte 0
; accu has to contain flashblock number.
program8KBlock
    ; make sure we address the blocks in the flash cart not normal flash
    ora #$80
    sta BLOCK_TEMP

    #load16BitImmediate WINDOW_MEM, PTR_SOURCE
    #load16BitImmediate WINDOW_FLASH, PTR_TARGET
    stz COUNT_PAGE
    #saveMMU MMU_REG

_copyNextPage
    ldy #0
    ; copy 8K block
_copyPage
    lda (PTR_SOURCE), y
    pha
    ; send Byte-Program command
    #send5555AA
    #send2AAA55
    #send5555XX $A0

    ; switch to target page
    lda BLOCK_TEMP
    sta MMU_REG

    pla
    sta (PTR_TARGET), y
_waitWrite
    cmp (PTR_TARGET), y
    bne _waitWrite
    iny
    bne _copyPage
    ; update source and target addresses
    inc PTR_SOURCE + 1
    inc PTR_TARGET + 1
    ; increment page counter
    inc COUNT_PAGE
    lda COUNT_PAGE
    cmp #32
    bne _copyNextPage

    #restoreMMU MMU_REG
    rts


; accu has to contain flashblock number.
BLOCK_TEMP .byte 0
erase8KBlock
    ; make sure we address the blocks in the flash cart not normal flash
    ora #$80
    sta BLOCK_TEMP

    ldx #0
    jsr erase4KBlock
    ldx #1
    jsr erase4KBlock
    rts


; block number is read from BLOCK_TEMP. X has to contain 0 if lower
; half is cleared else the upper half is cleared.
erase4KBlock
    #saveMMU MMU_REG

    ; send command Chip-Erase
    #send5555AA
    #send2AAA55
    #send5555XX $80
    #send5555AA
    #send2AAA55

    lda BLOCK_TEMP
    sta MMU_REG
    lda #$30
    cpx #0
    bne _upperHalf
    sta WINDOW_FLASH
    bra _wait
_upperHalf
    sta WINDOW_FLASH + $1000
_wait
    ; data sheet says this needs at max 25ms.
    jsr wait50ms

    #restoreMMU MMU_REG
    rts



wait250ms
    lda #15
    bra wait60ThSecond
wait500ms
    lda #30
    bra wait60ThSecond
wait50ms
    lda #3
wait60ThSecond
    sta TIMER_SPEED
    jsr setTimer60thSeconds 
_doKernelStuff
    ; Peek at the queue to see if anything is pending
    lda kernel.args.events.pending ; Negated count
    bpl _doKernelStuff
    ; Get the next event.
    jsr kernel.NextEvent
    bcs _doKernelStuff
    ; Handle the event
    lda myEvent.type    
    cmp #kernel.event.timer.EXPIRED
    beq _evalTimer
    bra _doKernelStuff
_evalTimer
    lda myEvent.timer.cookie
    cmp TIMER_COOKIE_60TH 
    bne _doKernelStuff

    rts


.endnamespace