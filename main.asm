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
.include "bload.asm"
.include "flashcart.asm"

WINDOW_MEM   = $8000
MAX_FILE_LENGTH = 100
FIRST_MEM_BLOCK = 8
MMU_REG_LOAD = 12

TXT_FILE_ERROR  .text "Error reading file"
TXT_BLOCK_ERROR .text "Flashcart not big enough"
TXT_BYTES_READ  .text "Bytes read  : $"
TXT_BLOCKS_READ .text "Blocks read : $"
TXT_FILE_NAME   .text "File to load: "
TXT_BLOCK_START .text "Start block : "
TXT_ERASE       .text "Erasing block ... "
TXT_PROGRAM     .text "Programming block ... "
TXT_VERFIFY_OK  .text "Verification successfull"
TXT_VERFIFY_ERR .text "Verification FAILURE", $0d
TXT_ERROR_TOO_MANY_BLOCKS .text "Too many blocks", $0d
TXT_DONE        .text  "Done!"

FILE_ALLOWED .text "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789_-./:#+~()!&@[]*"
DIGIT_ALLOWED  .text "0123456789"
DIGIT_BUFFER   .word 0

FIRST_BLOCK .byte 0
VALS .byte 0, 10, 20, 30, 40, 50, 60, 70, 80, 90
PROG_COUNT .byte 0
PROG_BLOCK .byte 0

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
    ; enter file name
    #printString TXT_FILE_NAME, len(TXT_FILE_NAME)
    #inputString bload.FILE_NAME, 78, FILE_ALLOWED, len(FILE_ALLOWED)
    cmp #0
    ; empty name entered => stop program
    bne _goOn
    jmp _done
_goOn
    ; load file with data to write
    jsr bload.to10000
    bcc _readOK
    ; We were unable to load the file => print error message
    jsr txtio.newLine
    #printString TXT_FILE_ERROR, len(TXT_FILE_ERROR)
    jsr txtio.newLine
    jmp _end
_readOK
    ; print info about file contents
    jsr txtio.newLine
    ; print length in bytes in hex
    #printString TXT_BYTES_READ, len(TXT_BYTES_READ)
    lda bload.BYTE_COUNTER.hi
    jsr txtio.printByte
    lda bload.BYTE_COUNTER.mi
    jsr txtio.printByte
    lda bload.BYTE_COUNTER.lo
    jsr txtio.printByte
    jsr txtio.newLine
    ; print number of 8K blocks read
    #printString TXT_BLOCKS_READ, len(TXT_BLOCKS_READ)
    lda bload.BYTE_COUNTER.numBlocks
    jsr txtio.printByte
    jsr txtio.newLine

    ; perform simple check whether the data fits into the flashcart
    jsr txtio.newLine
    lda bload.BYTE_COUNTER.numBlocks
    cmp #33
    bcc _lenOK
    #printString TXT_ERROR_TOO_MANY_BLOCKS, len(TXT_ERROR_TOO_MANY_BLOCKS)
    jmp _end
_lenOK
    ; Let the user specify the start block
    #printString TXT_BLOCK_START, len(TXT_BLOCK_START)
    #inputString DIGIT_BUFFER, 2, DIGIT_ALLOWED, len(DIGIT_ALLOWED)
    cmp #0
    ; if nothing is entered stop the program
    bne _goOn2
    jmp _done
_goOn2
    ; convert string into number
    ; only one digit entered
    cmp #1
    bne _len2
    lda DIGIT_BUFFER
    sec
    sbc #$30
    sta FIRST_BLOCK
    bra _checkLen
_len2
    ; two digits entered
    lda DIGIT_BUFFER
    sec
    sbc #$30
    tax
    lda VALS, x
    sta FIRST_BLOCK
    lda DIGIT_BUFFER + 1
    sec
    sbc #$30
    clc
    adc FIRST_BLOCK
    sta FIRST_BLOCK    
_checkLen
    ; Here first block contains the value entered by the user
    ; perform check whether file data fits into cartridge relative 
    ; to the selected start block
    lda FIRST_BLOCK
    clc
    adc bload.BYTE_COUNTER.numBlocks
    cmp #33
    bcc _lenOK2
    jsr txtio.newLine
    #printString TXT_BLOCK_ERROR, len(TXT_BLOCK_ERROR)
    jsr txtio.newLine
    jmp _end
_lenOK2
    ; program carttridge
    jsr txtio.newLine
    jsr txtio.newLine

    jsr programBlocks
    bcc _done

_verifyError
    #printString TXT_VERFIFY_ERR, len(TXT_VERFIFY_ERR)
_done
    jsr txtio.newLine
    #printString TXT_DONE, len(TXT_DONE)
    jsr txtio.newLine
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
    

programBlocks
    ; make MMU show first block we have read
    lda #FIRST_MEM_BLOCK
    sta MMU_REG_LOAD
    ; reset block count
    stz PROG_COUNT

    ; calculate flash block number $80+FIRST_BLOCK and store it in
    ; PROG_BLOCK
    clc
    lda #$80
    adc FIRST_BLOCK
    sta PROG_BLOCK

    jsr txtio.newLine
_progLoop
    ; have we programmed all blocks?
    lda PROG_COUNT
    cmp bload.BYTE_COUNTER.numBlocks
    beq _done                                               ; yes we are done

    ; print block number of currently programmed block
    lda PROG_BLOCK
    jsr txtio.printByte
    jsr txtio.newLine
    ; program block
    lda PROG_BLOCK
    jsr flashcart.overwrite8KBlock
    bcs _verifyError

    inc PROG_COUNT                                          ; increment number of blocks programmed
    inc MMU_REG_LOAD                                        ; map in next page of input data
    inc PROG_BLOCK                                          ; increment block number used for programming
    bra _progLoop
_done
    clc
_verifyError
    rts


NAME .text "xdev"
.byte 0
