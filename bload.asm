bload .namespace

FILE_NAME .fill MAX_FILE_LENGTH

IO_BLOCK_LEN = 128
DATA_BUFFER .fill IO_BLOCK_LEN + 1
DEVICE_NUM = 0

ByteCounter_t .struct
    lo           .byte 0
    mi           .byte 0
    hi           .byte 0
    offset       .word 0
    numBlocks    .byte 0
    currentBlock .byte 0
.endstruct

BYTE_COUNTER .dstruct ByteCounter_t

TXT_FILE .dstruct FileState_t, 76, FILE_NAME, len(FILE_NAME), DATA_BUFFER, IO_BLOCK_LEN, MODE_READ, DEVICE_NUM


BUFFER_PTR   .word 0
BUFFER_COUNT .byte 0
DATA_READ    .byte 0
; carry set upon error
read8KBlock
    #load16BitImmediate $8000, BUFFER_PTR
    #load16BitImmediate 0, BYTE_COUNTER.offset
    stz BUFFER_COUNT
_readLoop
    lda BUFFER_COUNT
    cmp #64
    beq _doneOK
    #move16Bit BUFFER_PTR, TXT_FILE.dataPtr
    lda #IO_BLOCK_LEN
    sta TXT_FILE.dataLen
    jsr disk.waitReadBlock
    php
    sec
    lda #IO_BLOCK_LEN
    sbc TXT_FILE.dataLen
    sta DATA_READ

    clc
    lda DATA_READ
    adc BYTE_COUNTER.offset
    sta BYTE_COUNTER.offset
    lda BYTE_COUNTER.offset + 1
    adc #0
    sta BYTE_COUNTER.offset + 1

    clc
    lda DATA_READ
    adc BUFFER_PTR
    sta BUFFER_PTR
    lda BUFFER_PTR + 1
    adc #0
    sta BUFFER_PTR + 1
    plp
    bcs _doneError
    inc BUFFER_COUNT
    bra _readLoop
_doneOK
    clc
    rts
_doneError
    sec
    rts


; carry set upon error
to10000
    ; reset counters
    stz BYTE_COUNTER.lo
    stz BYTE_COUNTER.mi
    stz BYTE_COUNTER.hi
    stz BYTE_COUNTER.numBlocks
    lda #FIRST_MEM_BLOCK
    sta BYTE_COUNTER.currentBlock

    ; reset file state
    lda #MODE_READ
    sta TXT_FILE.mode
    stz TXT_FILE.eofReached
    load16BitImmediate TXT_FILE, FILEIO_PTR1
    
    ; open file
    jsr disk.waitOpen
    bcc _fileOpened
    rts
_fileOpened
    ; map new block into slot at $8000
    lda BYTE_COUNTER.currentBlock
    sta MMU_REG_LOAD
    jsr setSrcBlock
    ; read data    
    jsr read8KBlock
    bcs _checkEnd                                                       ; carry is set. Either read error or EOF
    bra _procData
_checkEnd
    ; check if EOF is reached?
    lda TXT_FILE.eofReached
    ; Error but no EOF => we stop
    beq _closeError
_procData
    ; we get here after each 8K block has been read. It could be a full
    ; block, a partial block (This was the last block)
    ; or an empty block which was the last block and it does not count.
    #cmp16BitImmediate 0, BYTE_COUNTER.offset
    beq _closeOK                                                        ; we have read zero bytes in last call => last block, we do not count the empty block
    ; the last block contained at least one byte
    ; we count the block and update the byte counter
    inc BYTE_COUNTER.numBlocks

    ; check whether we have reached the end of the main memory
    lda BYTE_COUNTER.numBlocks
    cmp #64 - 8 + 1
    bcs _closeError
    
    ; add bytes read to overall length
    clc
    lda BYTE_COUNTER.lo
    adc BYTE_COUNTER.offset
    sta BYTE_COUNTER.lo
    lda BYTE_COUNTER.mi
    adc BYTE_COUNTER.offset + 1
    sta BYTE_COUNTER.mi
    lda BYTE_COUNTER.hi
    adc #0
    sta BYTE_COUNTER.hi
    ; have we read a full block?
    #cmp16BitImmediate $2000, BYTE_COUNTER.offset
    bne _closeOK                                                        ; no full block, we are done
    ; we have read a full block
    lda TXT_FILE.eofReached
    bne _closeOK                                                        ; It was a full block but it was also the last one
    ; read next block
    inc BYTE_COUNTER.currentBlock
    bra _fileOpened
_closeOK
    jsr disk.waitClose
    clc
    rts
_closeError
    jsr disk.waitClose
    sec
    rts


COUNT_PAGE .byte 0
setSrcBlock
    #load16BitImmediate WINDOW_MEM, CLEAN_PTR
    stz COUNT_PAGE
_copyNextPage
    ldy #0
    ; copy 8K block
_copyPage
    ; copy single page
    lda COUNT_PAGE
    sta (CLEAN_PTR), y
    iny
    bne _copyPage
    ; update source addresses
    inc CLEAN_PTR + 1
    ; increment page counter
    inc COUNT_PAGE
    lda COUNT_PAGE
    cmp #32
    bne _copyNextPage
    rts


Path_t .struct 
    drive    .byte 0
    len      .byte 0
.endstruct

PATH_HELP .dstruct Path_t
; In: Pointer to raw file name in PATH_PTR
; In: Length of raw file name in accu
; In: Default drive number in X-reg
; Out: Modified path pointer without drive specification
; Out: Length of potentially modified file name in accu
; Out: Drive number in x-reg
; carry is set if file name is invalid, i.e. only contains a drive specification
parseFileName
    sta PATH_HELP.len
    stx PATH_HELP.drive

    lda PATH_HELP.len
    beq _doneErr                                     ; a zero length name is not OK
    cmp #2
    bcs _atLeastTwo
    bra _success                                     ; file name has length one => This is OK
_atLeastTwo
    ldy #1
    lda (PATH_PTR), y
    cmp #58
    bne _success                                    ; byte at index 1 is not a colon
    lda (PATH_PTR)
    cmp #$30
    bcc _success                                    ; byte at index 0 is < '0'
    cmp #$33
    bcs _success                                    ; byte at index 0 is >= '3'
    ; we have a valid drive number and a colon
    lda PATH_HELP.len
    cmp #2
    beq _doneErr                                    ; we only have a drive designation => this is not OK
    ; convert drive number
    lda (PATH_PTR)
    sec
    sbc #$30
    sta PATH_HELP.drive
    ; remove drive designation from file name
    #move16Bit PATH_PTR, MEM_PTR1
    ldy PATH_HELP.len
    lda #0
    jsr memory.vecShiftleft
    dec PATH_HELP.len
    ldy PATH_HELP.len
    lda #0
    jsr memory.vecShiftleft
    dec PATH_HELP.len
_success
    lda PATH_HELP.len
    ldx PATH_HELP.drive
    clc
    rts
_doneErr
    sec
    rts


.endnamespace