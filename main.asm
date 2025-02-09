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
.include "memory.asm"

PROD = 1

WINDOW_MEM   = $8000
MAX_FILE_LENGTH = 100
FIRST_MEM_BLOCK = 8
MMU_REG_LOAD = 12

PROG_VERSION    .text "1.2.5"
TXT_FILE_ERROR  .text "Error reading file", $0d
TXT_BLOCK_ERROR .text $0d, "Data does not fit at given start position"
TXT_BYTES_READ  .text "Bytes read   : $"
TXT_BLOCKS_READ .text "Blocks read  : "
TXT_FILE_NAME   .text "Image to load: "
TXT_BLOCK_START .text "Start block  : "
TXT_CURRENT_BLK .text "Writing to   : "
TXT_ERASE       .text "Erasing block ... "
TXT_PROGRAM     .text "Programming block ... "
TXT_VERFIFY_OK  .text "Verification successfull"
TXT_VERFIFY_ERR .text "Verification FAILURE", $0d
TXT_ERROR_TOO_MANY_BLOCKS .text "Too many blocks", $0d
TXT_ERROR_PATH  .text "File name is illegal", $0d
TXT_DONE        .text "Done!"
TXT_STARS       .text "*********************"
TXT_PROG_NAME   .text "CartFlasher"
TXT_DIVIDER     .text "--------------------"
TXT_INFO1       .text "The flash cartridge has a size of 32 8K blocks. Therefore the start block", $0d
TXT_INFO2       .text "has to be in the range from 0 to 31 and the cartridge image file size can be", $0d
TXT_INFO3       .text "at most 256K. The image file data is written in consecutive flash blocks", $0d
TXT_INFO4       .text "beginning with the start block. You can prefix the image file name with a", $0d
TXT_INFO6       .text "drive number plus a colon.", $0d
TXT_INFO7       .text $0d, "Find the source code at https://github.com/rmsk2/cartflash. Published under"
TXT_INFO8       .text $0d, "MIT license.", $0d
TXT_INFO5       .text $0d, "Enter an empty string as a file name or start block to end program.", $0d
TXT_LOAD_FILE   .text $0d, "Loading image file ... "
TXT_ERASE_ALL   .text "Erasing all data on flash cartridge ... "

FILE_ALLOWED    .text "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789_-./:#+~()!&@[]*"
DIGIT_ALLOWED   .text "0123456789"
TXT_PARAM_ERASE .text "erasealldata", $00
TXT_PARAM_NHELP .text "silent", $00
TXT_10          .text "0         1         2         3 "
TXT_01          .text "01234567890123456789012345678901"
TXT_BLOCK_MAP   .text $0d,"Blocks already used", $0d, $0d
TXT_BLOCK_FREE  .text ". = Block free or not claimed by a KUP", $0d


DIGIT_BUFFER       .word 0
FIRST_BLOCK        .byte 0
VALS               .byte 0, 10, 20, 30, 40, 50, 60, 70, 80, 90
PROG_COUNT         .byte 0
PROG_BLOCK         .byte 0
ERASE_REQUESTED    .byte 0
LEN_PARMS_IN_BYTES .byte 0
HELP_SUPPRESS      .byte 0

COL = $12 
REV_COL = $21

toRev .macro
    pha
    lda #REV_COL
    sta CURSOR_STATE.col
    pla
.endmacro

noRev .macro
    pha
    lda #COL
    sta CURSOR_STATE.col
    pla
.endmacro

main
    jsr setup.mmu
    jsr clut.init
    stz ERASE_REQUESTED
    stz HELP_SUPPRESS
    jsr txtio.init80x60
    jsr txtio.cursorOn
    jsr initEvents

    lda kernel.args.extlen
    sta LEN_PARMS_IN_BYTES
    lsr
    cmp #2
    bcc _noErase
    jsr checkEraseParam
    jsr checkSilentParam

_noErase
    ; clear screen
    lda #$12
    sta CURSOR_STATE.col 
    jsr txtio.clear

    jsr printMsgHeader
    lda ERASE_REQUESTED
    beq _start

    ; user requested to erase all data from flash chip
    jsr txtio.newLine
    #printString TXT_ERASE_ALL, len(TXT_ERASE_ALL)
.if PROD == 1
    jsr flashcart.eraseChip
.endif
    #printString TXT_DONE, len(TXT_DONE)
    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_DIVIDER, len(TXT_DIVIDER)
    jsr txtio.newLine

_start
    #printString TXT_BLOCK_MAP, len(TXT_BLOCK_MAP)
    #printString TXT_BLOCK_FREE, len(TXT_BLOCK_FREE)
    jsr discoverContents
    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_10, len(TXT_10)
    jsr txtio.newLine
    #printString TXT_01, len(TXT_01)
    jsr txtio.newLine
    #printString BLOCK_MAP, 32
    jsr txtio.newLine
    jsr txtio.newLine
    jsr txtio.newLine
    ; enter file name
    #printString TXT_FILE_NAME, len(TXT_FILE_NAME)
    #toRev
    #inputString bload.FILE_NAME, 79 - len(TXT_FILE_NAME), FILE_ALLOWED, len(FILE_ALLOWED)
    #noRev
    cmp #0
    ; empty name entered => stop program
    bne _parsePath
    jmp returnToBasic
_parsePath
    pha
    #load16BitImmediate bload.FILE_NAME, PATH_PTR
    ldx #bload.DEVICE_NUM
    pla
    jsr bload.parseFileName
    bcc _loadFile
    jsr txtio.newLine
    #printString TXT_ERROR_PATH, len(TXT_ERROR_PATH)
    jsr txtio.newLine
    jmp _end
_loadFile
    ; store file name length and drive in file struct
    stx bload.TXT_FILE.drive
    sta bload.TXT_FILE.nameLen
    #printString TXT_LOAD_FILE, len(TXT_LOAD_FILE)
    ; load file with data to write
    jsr bload.to10000
    bcc _printFileInfo
    ; We were unable to load the file => print error message
    #printString TXT_FILE_ERROR, len(TXT_FILE_ERROR)
    jsr txtio.newLine
    jmp _end
_printFileInfo
    #printString TXT_DONE, len(TXT_DONE)
    jsr txtio.newLine
    jsr printFileInfo
    jsr txtio.newLine
    ; perform simple check whether the data fits into the flashcart
    lda bload.BYTE_COUNTER.numBlocks
    cmp #33
    bcc _enterFirstBlock
    #printString TXT_ERROR_TOO_MANY_BLOCKS, len(TXT_ERROR_TOO_MANY_BLOCKS)
    jsr txtio.newLine
    bra _end
_enterFirstBlock
    ; Let the user specify the start block
    #printString TXT_BLOCK_START, len(TXT_BLOCK_START)
    #toRev
    #inputString DIGIT_BUFFER, 2, DIGIT_ALLOWED, len(DIGIT_ALLOWED)
    #noRev
    cmp #0
    ; if nothing is entered stop the program
    bne _checkSize
    jmp returnToBasic
_checkSize
    jsr convDecimal
    jsr checkDataFit
    bcc _writeData
    jsr txtio.newLine
    bra _end
_writeData
    ; program cartridge
    jsr txtio.newLine
    jsr programBlocks
    bcc _done
    jsr txtio.newLine
    #printString TXT_VERFIFY_ERR, len(TXT_VERFIFY_ERR)
_done
    jsr txtio.newLine
    #printString TXT_DONE, len(TXT_DONE)
    jsr txtio.newLine
    jsr txtio.newLine
_end
    #printString TXT_DIVIDER, len(TXT_DIVIDER)
    jsr txtio.newLine
    jmp _start
    

printMsgHeader
    #printString TXT_STARS, len(TXT_STARS)
    lda #$20
    jsr txtio.charOut
    #printString TXT_PROG_NAME, len(TXT_PROG_NAME)
    lda #$20
    jsr txtio.charOut
    #printString PROG_VERSION, len(PROG_VERSION)
    lda #$20
    jsr txtio.charOut
    #printString TXT_STARS, len(TXT_STARS)
    jsr printHelpMsg
    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_DIVIDER, len(TXT_DIVIDER)
    jsr txtio.newLine
    rts


printHelpMsg
    lda HELP_SUPPRESS
    bne _end
    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_INFO1, len(TXT_INFO1)
    #printString TXT_INFO2, len(TXT_INFO2)
    #printString TXT_INFO3, len(TXT_INFO3)
    #printString TXT_INFO4, len(TXT_INFO4)
    #printString TXT_INFO6, len(TXT_INFO6)
    #printString TXT_INFO7, len(TXT_INFO7)
    #printString TXT_INFO8, len(TXT_INFO8)
    #printString TXT_INFO5, len(TXT_INFO5)
_end
    rts


printFileInfo
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
    sta txtio.WORD_TEMP
    stz txtio.WORD_TEMP + 1
    jsr txtio.printWordDecimal
    jsr txtio.newLine
    rts


returnToBasic
    ; restart xdev
    lda #<XDEV
    sta kernel.args.buf
    lda #>XDEV
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


TEMP_LO .byte 0
TEMP_HI .byte 0
getSecondParam
    #move16Bit kernel.args.ext, PARM_PTR
    ; determine address of second CLI parameter
    ldy #2
    lda (PARM_PTR), y
    sta TEMP_LO
    iny
    lda (PARM_PTR), y
    sta TEMP_HI
    #move16Bit TEMP_LO, PARM_PTR
    rts


checkEraseParam
    jsr getSecondParam
    #load16BitImmediate TXT_PARAM_ERASE, PARM_REF
    jsr strCmp
    bcc _doneUnequal
    lda #BOOL_TRUE
    sta ERASE_REQUESTED
_doneUnequal
    rts


checkSilentParam
    jsr getSecondParam
    #load16BitImmediate TXT_PARAM_NHELP, PARM_REF
    jsr strCmp
    bcc _doneUnequal
    lda #BOOL_TRUE
    sta HELP_SUPPRESS
_doneUnequal
    rts



; carry is set if strings are equal. String 1 in MEM_PTR1, the other has to
; be in MEM_PTR2.
strCmp
    ldy #0
_loop
    lda (PARM_PTR), y
    cmp (PARM_REF), y
    bne _notFound
    cmp #0
    beq _found
    iny
    beq _notFound
    bra _loop
_notFound
    clc
    rts
_found
    sec
    rts


; carry is set if data does not fit into cartridge
checkDataFit
    ; Here FIRST_BLOCK contains the value entered by the user
    ; perform check whether file data fits into cartridge relative 
    ; to the selected start block
    lda FIRST_BLOCK
    clc
    adc bload.BYTE_COUNTER.numBlocks
    cmp #33
    bcc _lenOK
    jsr txtio.newLine
    #printString TXT_BLOCK_ERROR, len(TXT_BLOCK_ERROR)
    jsr txtio.newLine
    sec
    rts
_lenOK
    clc
    rts


; Convert string into number
; raw data is in DIGIT_BUFFER. Length is in accu. Result is in FIRST_BLOCK
convDecimal
    ; only one digit entered
    cmp #1
    bne _len2
    lda DIGIT_BUFFER
    sec
    sbc #$30
    sta FIRST_BLOCK
    rts
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
    rts


; write bload.BYTE_COUNTER.numBlocks 8K blocks to flash cart. Source data
; is in RAM blocks 8, .... . The first flash block to be written is FIRST_BLOCK + $80
; When verification fails carry is set upon return.
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
    #printString TXT_CURRENT_BLK, len(TXT_CURRENT_BLK)
_progLoop
    ; have we programmed all blocks?
    lda PROG_COUNT
    cmp bload.BYTE_COUNTER.numBlocks
    beq _done                                               ; yes we are done

    ; print block number of currently programmed block
    lda #'$'
    jsr txtio.charOut
    lda PROG_BLOCK
    jsr txtio.printByte
    lda #$20
    jsr txtio.charOut

    ; program block
    lda PROG_BLOCK
.if PROD == 1
    jsr flashcart.overwrite8KBlock
.else
    clc
.endif
    bcs _verifyError

    inc PROG_COUNT                                          ; increment number of blocks programmed
    inc MMU_REG_LOAD                                        ; map in next page of input data
    inc PROG_BLOCK                                          ; increment block number used for programming
    bra _progLoop
_done
    jsr txtio.newLine
    clc
    rts
_verifyError
    jsr txtio.newLine
    sec
    rts


MMU_TEMP .byte 0
BLOCK_MAP .fill 32
CURRENT_BLOCK .byte 0
PROG_LEN .byte 0
;PROG_SYMBOL .text "ABCDEFGHIJKLMNOPQRSTUVWXYZ234568"
PROG_SYMBOL .byte 199, 7, 18, 21, 30, 23, 31, 180, 179, 253, 254, 255, 16
.text "#*ABCDEFGHIJKLMNOPQ"


discoverContents
    ldx #$FF
    ldy #0
    sty PROG_LEN
    lda #'.'
_clearLoop
    sta BLOCK_MAP, y
    iny
    cpy #32
    bne _clearLoop

    lda 13
    sta MMU_TEMP

    ldy #0
    lda #$80
    sta CURRENT_BLOCK
_blockLoop
    cpy #32
    beq _restoreMMU

    lda PROG_LEN
    beq _lookAtBlock
    dec PROG_LEN
    lda PROG_LEN
    beq _lookAtBlock
    bra _markAsUsed

_lookAtBlock
    lda CURRENT_BLOCK
    sta 13

    lda $A000
    cmp #$F2
    bne _nextBlock

    lda $A001
    cmp #$56
    bne _nextBlock

    inx
    jsr printProgName
    lda $A002
    sta PROG_LEN
_markAsUsed
    lda PROG_SYMBOL, x
    sta BLOCK_MAP, y

_nextBlock
    iny
    inc CURRENT_BLOCK
    bra _blockLoop

_restoreMMU
    lda MMU_TEMP
    sta 13
    rts


CURRENT_SYMBOL .byte ?
printProgName
    phx
    phy
    lda PROG_SYMBOL, x
    sta CURRENT_SYMBOL
    lda CURRENT_SYMBOL
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut
    lda #'='
    jsr txtio.charOut
    lda #' '
    jsr txtio.charOut
    ldy #0
_checkZero
    lda $A00A, y
    beq _done
    jsr txtio.charOut
    iny
    bra _checkZero
_done
    jsr txtio.newLine
    ply
    plx
    rts

XDEV .text "xdev"
.byte 0
