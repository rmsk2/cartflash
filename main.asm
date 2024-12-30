* = $0300
.cpu "w65c02"

jmp main

.include "api.asm"
.include "zeropage.asm"
.include "macros.asm"
.include "setup.asm"
.include "clut.asm"
.include "khelp.asm"
.include "txtio.asm"
.include "diskio.asm"
.include "flashcart.asm"

WINDOW_MEM   = $8000

main
    jsr setup.mmu
    jsr clut.init
    jsr txtio.init80x60
    jsr txtio.cursorOn
    lda #$12
    sta CURSOR_STATE.col 
    jsr txtio.clear

    jsr initEvents

    jsr txtio.newLine
    
    ; jsr flashcart.getProductId
    ; lda FLASH_CHIP.vendorID
    ; jsr txtio.printByte
    ; jsr txtio.newLine

    ; lda FLASH_CHIP.chipID
    ; jsr txtio.printByte    
    ; jsr txtio.newLine

    ;jsr flashcart.eraseChip
    jsr setSrcBlock

    ; #printString TXT_ERASE, len(TXT_ERASE)
    ; lda #$84
    ; jsr flashcart.erase8KBlock
    ; #printString TXT_DONE, len(TXT_DONE)
    
    ; #printString TXT_PROGRAM, len(TXT_PROGRAM)
    ; lda #$84
    ; jsr flashcart.program8KBlock
    ; #printString TXT_DONE, len(TXT_DONE)

    lda #$84
    jsr flashcart.verify8KBlock
    ;jsr flashcart.overwrite8KBlock
    bcs _verifyError
    #printString TXT_VERFIFY_OK, len(TXT_VERFIFY_OK)
    bra _end
_verifyError
    #printString TXT_VERFIFY_ERR, len(TXT_VERFIFY_ERR)

_end
    jsr waitForKey

    lda #<NAME
    sta kernel.args.buf
    lda #>NAME
    sta kernel.args.buf+1
    jsr kernel.RunNamed

    ; if we do end up here => perform a reset
    lda #$DE
    sta $D6A2
    lda #$AD
    sta $D6A3
    lda #$80
    sta $D6A0
    lda #00
    sta $D6A0
    rts
    

NAME .text "xdev"
.byte 0

TXT_ERASE      .text "Erasing block ... "
TXT_PROGRAM    .text "Programming block ... "
TXT_DONE       .text "Done", $0d
TXT_VERFIFY_OK .text "Verification successfull"
TXT_VERFIFY_ERR .text "Verification FAILURE"

COUNT_PAGE .byte 0
setSrcBlock
    #load16BitImmediate WINDOW_MEM, PTR_SOURCE
    stz COUNT_PAGE
_copyNextPage
    ldy #0
    ; copy 8K block
_copyPage
    ; copy single page
    ; lda #31
    ; sec
    ; sbc COUNT_PAGE
    lda COUNT_PAGE
    ; lda #0
    sta (PTR_SOURCE), y
    iny
    bne _copyPage
    ; update source addresses
    inc PTR_SOURCE + 1
    ; increment page counter
    inc COUNT_PAGE
    lda COUNT_PAGE
    cmp #32
    bne _copyNextPage
    rts


bload
    rts