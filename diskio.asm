DEVICE_NUM = 0

MODE_READ = 0
MODE_WRITE = 1

EOF_REACHED = 1
EOF_NOT_REACHED = 0

FileState_t .struct cookie, nameAddr, nameLen, dataAddr, dataLen, mode, drive    
    cookie .byte \cookie
    streamId .byte ?
    namePtr .word \nameAddr
    nameLen .byte \nameLen
    dataPtr .word \dataAddr
    dataLen .byte \dataLen
    mode .byte \mode
    drive .byte \drive
    eofReached .byte 0
.endstruct

disk .namespace

eventStub .macro
_retry 
    ; Peek at the queue to see if anything is pending
    lda kernel.args.events.pending ; Negated count
    bpl _retry
    ; Get the next event.
    jsr kernel.NextEvent
    bcs _retry
.endmacro

init
    rts


; FILEIO_PTR1 => FileState_t
; on error carry is set
waitOpen
    ldy #FileState_t.drive
    lda (FILEIO_PTR1), y
    sta kernel.args.file.open.drive

    ldy #FileState_t.namePtr
    lda (FILEIO_PTR1), y
    sta kernel.args.file.open.fname
    iny
    lda (FILEIO_PTR1), y
    sta kernel.args.file.open.fname+1

    ldy #FileState_t.nameLen
    lda (FILEIO_PTR1), y
    sta kernel.args.file.open.fname_len

    ldy #FileState_t.mode
    lda (FILEIO_PTR1), y
    sta kernel.args.file.open.mode

    ldy #FileState_t.cookie
    lda (FILEIO_PTR1), y
    sta kernel.args.file.open.cookie

    jsr kernel.File.Open
    bcs _done

    ldy #FileState_t.streamId
    sta (FILEIO_PTR1), y

    ldy #FileState_t.mode
    lda (FILEIO_PTR1), y
    beq _openForRead
    jmp finishOpenWrite
_openForRead    
    jmp finishOpenRead
_done
    rts


finishOpenWrite
_eventLoop    
    #eventStub
    lda myEvent.type
    cmp #kernel.event.file.OPENED
    bne _checkError
    jsr testCookie                           ; does cookie match?
    bcs _eventLoop                           ; event was for another file
    rts                                      ; we got an OPENED event for our file and carry is clear => done
_checkError
    cmp #kernel.event.file.ERROR
    bne _eventLoop                           ; some other event in which we are not interested at the moment                   
    jsr testCookie                           ; does cookie match?
    bcs _eventLoop                           ; event was for another file
    sec                                      ; we got an ERROR event for our file. Set carry and return
    rts


finishOpenRead
_eventLoop    
    #eventStub
    lda myEvent.type
    cmp #kernel.event.file.OPENED
    bne _checkError
    jsr testCookie                           ; does cookie match?
    bcs _eventLoop                           ; event was for another file
    rts                                      ; we got an OPENED event for our file and carry is clear => done
_checkError
    cmp #kernel.event.file.ERROR
    bne _checkFileNotFound                   
    jsr testCookie                           ; does cookie match?
    bcs _eventLoop                           ; event was for another file
    sec                                      ; we got an ERROR event for our file. Set carry and return
    rts
_checkFileNotFound
    cmp #kernel.event.file.NOT_FOUND
    bne _eventLoop                           ; some other event in which we are not interested at the moment
    jsr testCookie
    bcs _eventLoop
    sec                                      ; we got an ERROR event for our file. Set carry and return
    rts


; carry is set upon error
waitClose
    ldy #FileState_t.streamId
    lda (FILEIO_PTR1), y
    sta kernel.args.file.close.stream
    jsr kernel.File.Close
    bcc _waitForClose
    rts
_waitForClose
    #eventStub
    lda myEvent.type
    cmp #kernel.event.file.CLOSED
    bne _waitForClose
    jsr testCookie
    bcs _waitForClose
    clc
    rts


; carry set on error
waitWriteBlock
    ldy #FileState_t.streamId
    lda (FILEIO_PTR1), y
    sta kernel.args.file.write.stream

    ldy #FileState_t.dataPtr
    lda (FILEIO_PTR1), Y
    sta kernel.args.file.write.buf
    iny 
    lda (FILEIO_PTR1), Y
    sta kernel.args.file.write.buf+1

    ldy #FileState_t.dataLen
    lda (FILEIO_PTR1), y
    sta kernel.args.file.write.buflen
    jsr kernel.File.Write
    bcs _done
_waitForResult
    #eventStub
    lda myEvent.type
    cmp #kernel.event.file.WROTE
    bne _checkError
    jsr testCookie
    bcs _waitForResult
    ldy #FileState_t.dataLen
    lda (FILEIO_PTR1), y
    sec
    sbc myEvent.file.wrote.wrote
    sta (FILEIO_PTR1), y                      ; save number of bytes which remain to be written 
    beq _allWritten                           ; zero flag is set when all bytes are written
    ; not all bytes are written
    ; change base address of data to reflect bytes already written
    ldy #FileState_t.dataPtr
    lda (FILEIO_PTR1), Y
    clc
    adc myEvent.file.wrote.wrote
    sta (FILEIO_PTR1), Y
    iny
    lda (FILEIO_PTR1), Y
    adc #0
    sta (FILEIO_PTR1), Y
    bra waitWriteBlock
_allWritten
    clc
    rts
_checkError
    cmp #kernel.event.file.ERROR
    bne _waitForResult
    jsr testCookie
    bcs _waitForResult
    sec
_done
    rts


; carry set on error
waitReadBlock
    ldy #FileState_t.streamId
    lda (FILEIO_PTR1), y
    sta kernel.args.file.read.stream

    ldy #FileState_t.dataLen
    lda (FILEIO_PTR1), y
    sta kernel.args.file.read.buflen 

    jsr kernel.File.Read
    bcs _done
_waitForResult
    #eventStub
    lda myEvent.type
    cmp #kernel.event.file.DATA
    bne _checkEof
    jsr testCookie
    bcs _waitForResult

    ldy #FileState_t.dataPtr
    lda (FILEIO_PTR1),y 
    sta kernel.args.buf 
    iny
    lda (FILEIO_PTR1),y 
    sta kernel.args.buf+1
    
    lda myEvent.file.data.read
    sta kernel.args.buflen 
    jsr kernel.ReadData

    ldy #FileState_t.dataLen
    lda (FILEIO_PTR1), y
    sec
    sbc myEvent.file.data.read
    sta (FILEIO_PTR1), y
    beq _allRead

    ldy #FileState_t.dataPtr
    lda (FILEIO_PTR1), Y
    clc
    adc myEvent.file.data.read
    sta (FILEIO_PTR1), Y
    iny
    lda (FILEIO_PTR1), Y
    adc #0
    sta (FILEIO_PTR1), Y
    bra waitReadBlock
_allRead
    clc
    rts
_checkEof
    cmp #kernel.event.file.EOF
    bne _checkError
    jsr testCookie
    bcs _waitForResult
    lda #EOF_REACHED
    ldy #FileState_t.eofReached
    sta (FILEIO_PTR1), y
    bra _doneError
_checkError
    cmp #kernel.event.file.ERROR
    bne _waitForResult
    jsr testCookie
    bcs _waitForResult
_doneError
    sec
_done
    rts


testCookie
    pha
    phy
    lda myEvent.file.cookie
    ldy #FileState_t.cookie
    cmp (FILEIO_PTR1), y
    beq _ok
    ply
    pla
    sec
    rts
_ok
    ply
    pla
    clc
    rts

.endnamespace