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

.endnamespace