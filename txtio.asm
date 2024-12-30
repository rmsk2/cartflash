CURSOR_X = $D014
CURSOR_Y = $D016
CARRIAGE_RETURN = 13
BACK_SPACE = 8
; Change to $DE04 when building for a F256 Jr. Rev B using factory settings
MUL_RES_CO_PROC = $DE10

toTxtMatrix .macro
    lda #2
    sta $01
.endmacro

toColorMatrix .macro
    lda #3
    sta $01
.endmacro

toIoPage0 .macro
    stz $01
.endmacro

saveIoState .macro
    lda $01
    sta CURSOR_STATE.tempIo
.endmacro

restoreIoState .macro    
    lda CURSOR_STATE.tempIo
    sta $01
.endmacro

moveCursor .macro
    lda CURSOR_STATE.xPos
    sta CURSOR_X
    stz CURSOR_X+1
    clc
    lda CURSOR_STATE.yPos
    adc CURSOR_STATE.yOffset
    sta CURSOR_Y
    stz CURSOR_Y+1
.endmacro

printString .macro address, length
    #load16BitImmediate \address, TXT_PTR3
    lda #\length
    jsr txtio.printStr
.endmacro

printStringLenMem .macro address, length
    #load16BitImmediate \address, TXT_PTR3
    lda \length
    jsr txtio.printStr
.endmacro

locate .macro x_pos, y_pos
    lda #\x_pos
    sta CURSOR_STATE.xPos
    lda #\y_pos
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
.endmacro

inputString .macro addrRes, lenRes, addrAllowed, lenAllowed
    #load16BitImmediate \addrRes, TXT_PTR4
    ldx #\lenRes
    #load16BitImmediate \addrAllowed, TXT_PTR3
    ldy #\lenAllowed
    jsr txtio.getString    
.endmacro

inputStringNonBlocking .macro addrRes, lenRes, addrAllowed, lenAllowed
    #load16BitImmediate \addrRes, TXT_PTR4
    ldx #\lenRes
    #load16BitImmediate \addrAllowed, TXT_PTR3
    ldy #\lenAllowed
    jsr txtio.getStringNonBlocking    
.endmacro


setCol .macro col 
    lda #\col
    sta CURSOR_STATE.col
.endmacro

; Take a look at key_repeat_test.asm for an example on how to define a screen segment

BOOL_FALSE = 0
BOOL_TRUE = 1

cursorState_t .struct 
    xPos        .byte 0
    yPos        .byte 0
    videoRamPtr .word 0           ; location of VRAM which is represented by the current cursor position
    lastLinePtr .word 0           ; pointer to the last line of the segment. Is calculated in init routine.
    xMax        .byte 80
    yMax        .byte 60          ; Use a non default value to define a screen segment of corresponding size
    yMaxMinus1  .byte 59
    col         .byte $92
    tempIo      .byte 0
    nextChar    .byte 0
    maxVideoRam .word 0           ; is calculated in init routine
    scrollOn    .byte BOOL_TRUE   ; set to zero to prevent scrolling when lower right edge is reached
    cursorOn    .byte BOOL_FALSE
    vramOffset  .word $c000       ; set to address of the line that begins at yOffset, if yOffset is nonzero
    yOffset     .word 0           ; set to a nonzero value to define the row in which the screen segment begins
.endstruct


CURSOR_STATE  .dstruct cursorState_t

txtio .namespace

; --------------------------------------------------
; This routine saves the current values stored in the CURSOR_STATE
; struct to the memory location to which TXT_PTR2 points.
;
; This routine does not return a value.
; --------------------------------------------------
saveCursorState
    ldy #0
_loop
    lda CURSOR_STATE, y
    sta (TXT_PTR2), y
    iny
    cpy #size(cursorState_t)
    bne _loop
    rts


; --------------------------------------------------
; This routine switches between two CursorState_t structs. The one to
; which the current state should be saved has to be pointed to TXT_PTR2
; and the one which should be restored is referenced by TXT_PTR1.
; --------------------------------------------------
switch
    jsr cursorGet
    jsr saveCursorState
    jsr restoreCursorState
    jsr cursorSet
    lda CURSOR_STATE.cursorOn
    beq _off
    jsr cursorOn
    rts
_off    
    jsr cursorOff
    rts


; --------------------------------------------------
; This routine restores the saved CURSOR_STATE struct from
; the memory location to which TXT_PTR1 points.
;
; This routine does not return a value.
; --------------------------------------------------
restoreCursorState
    ldy #0
_loop
    lda (TXT_PTR1), y
    sta CURSOR_STATE, y
    iny
    cpy #size(cursorState_t)
    bne _loop
    rts


; --------------------------------------------------
; This routine intializes the CURSOR_STATE struct.
;
; This routine does not return a value.
; --------------------------------------------------
init
    lda CURSOR_STATE.yMax
    dea
    sta CURSOR_STATE.yMaxMinus1

    ;calculate max address
    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMax
    sta CURSOR_STATE.yPos
    jsr calcCursorOffset
    #move16Bit CURSOR_STATE.videoRamPtr, CURSOR_STATE.maxVideoRam

    ; calc address of last line
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    stz CURSOR_STATE.xPos
    jsr calcCursorOffset
    #move16Bit CURSOR_STATE.videoRamPtr, CURSOR_STATE.lastLinePtr

    ; Make sure hardware cursor is in current screen segment
    jsr home
    jsr cursorOff
    rts


initSegmentDefaults
    stz CURSOR_STATE.yOffset
    #load16BitImmediate $c000, CURSOR_STATE.vramOffset
    rts


init80x60
    lda #80
    sta CURSOR_STATE.xMax
    lda #60
    sta CURSOR_STATE.yMax
    jsr initSegmentDefaults
setMode80x60
    #saveIoState
    #toIoPage0
    lda $D001
    and #%11111001
    sta $D001
    #restoreIoState
    jmp init


init40x60
    lda #40
    sta CURSOR_STATE.xMax
    lda #60
    sta CURSOR_STATE.yMax
    jsr initSegmentDefaults
setMode40x60    
    #saveIoState
    #toIoPage0
    lda $D001
    and #%11111001
    ora #%00000010
    sta $D001
    #restoreIoState
    jmp init


init80x30
    lda #80
    sta CURSOR_STATE.xMax
    lda #30
    sta CURSOR_STATE.yMax
    jsr initSegmentDefaults
setMode80x30    
    #saveIoState
    #toIoPage0
    lda $D001
    and #%11111001
    ora #%00000100
    sta $D001
    #restoreIoState
    jmp init


init40x30
    lda #40
    sta CURSOR_STATE.xMax
    lda #30
    sta CURSOR_STATE.yMax
    jsr initSegmentDefaults
setMode40x30    
    #saveIoState
    #toIoPage0
    lda $D001
    ora #%00000110
    sta $D001
    #restoreIoState
    jmp init


; --------------------------------------------------
; This routine calculates to what address in video RAM the cursor position
; CURSOR_STATE.xPos and CURSOR_STATE.yPos corresponds.
;
; This routine does not return a value. But as a side effect the calculated
; address is stored in CURSOR_STATE.videoRamPtr.
; --------------------------------------------------
calcCursorOffset
    ; calculate y * xMax    
    lda CURSOR_STATE.xMax
    sta $DE00
    stz $DE01
    lda CURSOR_STATE.yPos
    sta $DE02
    stz $DE03
    
    #move16Bit MUL_RES_CO_PROC, CURSOR_STATE.videoRamPtr

    ; calculate y * xMax + x + CURSOR_STATE.vramOffset
    clc
    lda CURSOR_STATE.videoRamPtr
    adc CURSOR_STATE.xPos
    sta CURSOR_STATE.videoRamPtr
    lda CURSOR_STATE.videoRamPtr+1
    adc #0
    sta CURSOR_STATE.videoRamPtr+1

    clc
    lda CURSOR_STATE.videoRamPtr
    adc CURSOR_STATE.vramOffset
    sta CURSOR_STATE.videoRamPtr

    lda CURSOR_STATE.videoRamPtr+1
    adc CURSOR_STATE.vramOffset+1
    sta CURSOR_STATE.videoRamPtr+1

    rts


; --------------------------------------------------
; This routine sets the hardware cursor to the values stored in CURSOR_STATE.xPos and
; CURSOR_STATE.yPos.
;
; This routine does not return a value.
; --------------------------------------------------
cursorSet 
    #moveCursor
    jsr calcCursorOffset
    rts    


; --------------------------------------------------
; This routine prints the character stored in the accu to the screen at the current
; position of the cursor. If it is called while the cursor is in the bottom right corner
; the whole screen is scrolled one line up.
;
; This routine does not return a value.
; --------------------------------------------------
charOut
    pha
    sta CURSOR_STATE.nextChar

    #saveIoState    
    #move16Bit CURSOR_STATE.videoRamPtr, TXT_PTR1    
    #toTxtMatrix
    ; store character to print in video RAM
    lda CURSOR_STATE.nextChar
    sta (TXT_PTR1)
    #toColorMatrix
    ; set color of printed character in video RAM
    lda CURSOR_STATE.col
    sta (TXT_PTR1)    
    #restoreIoState

    #inc16Bit CURSOR_STATE.videoRamPtr
    #cmp16Bit CURSOR_STATE.videoRamPtr, CURSOR_STATE.maxVideoRam
    bcc _moveRight
    ; We have reached the lower right corner.
    #move16Bit CURSOR_STATE.lastLinePtr, CURSOR_STATE.videoRamPtr
    stz CURSOR_STATE.xPos
    phy
    jsr scrollUp
    ply
    bra _done
_moveRight  
    ; move cursor one character to the right
    inc CURSOR_STATE.xPos
    lda CURSOR_STATE.xPos
    cmp CURSOR_STATE.xMax
    bcc _done
    stz CURSOR_STATE.xPos
    ; We do not have to worry about an overflow in y position. When we arrive
    ; here there was at least one character position left on the screen
    inc CURSOR_STATE.yPos
_done
    #moveCursor
    pla
    rts


TEMP_CURSOR_POS .byte 0
; --------------------------------------------------
; This routine stores the current position of the hardware cursor in
; the CURSOR_STATE struct and updates CURSOR_STATE.videoRamPtr. A precondition
; for this routine is that the hardware cursor is currently in the defined
; screen segment.
;
; This routine does not return a value.
; --------------------------------------------------
cursorGet
    lda CURSOR_X
    sta CURSOR_STATE.xPos
    
    lda CURSOR_Y
    sec
    sbc CURSOR_STATE.yOffset
    sta CURSOR_STATE.yPos

    jsr calcCursorOffset

    rts


; --------------------------------------------------
; This routine makes the cursor visible.
;
; This routine does not return a value.
; --------------------------------------------------
cursorOn
    lda #5
    sta $D010
    lda #214
    sta $D012
    lda #BOOL_TRUE
    sta CURSOR_STATE.cursorOn
    rts

; --------------------------------------------------
; This routine makes the cursor invisible.
;
; This routine does not return a value.
; --------------------------------------------------
cursorOff
    lda #%11111110
    and $D010
    sta $D010
    stz CURSOR_STATE.cursorOn
    rts


; --------------------------------------------------
; This routine moves the cursor one position to the left. If it
; is called while the cursor is at position 0,0, i.e. in the top left
; corner, nothing happens.
;
; This routine does not return a value.
; --------------------------------------------------
left
    lda CURSOR_STATE.xPos
    beq _leftEdge                                        ; was xPos zero?
    dec a
    sta CURSOR_STATE.xPos
    bra _done
_leftEdge
    lda CURSOR_STATE.yPos
    beq _done                                            ; was yPos zero?
    inc HAS_LINE_CHANGED
    lda CURSOR_STATE.xMax
    dec a
    sta CURSOR_STATE.xPos
    dec CURSOR_STATE.yPos
_done
    jsr cursorSet
    rts


; --------------------------------------------------
; This routine moves the cursor one position to the right. If it
; is called in the bottom right corner of the screen the whole screen
; is scrolled up and the cursor is placed in the leftmost position
; of the bottom most line.
;
; This routine does not return a value.
; --------------------------------------------------
right
    inc CURSOR_STATE.xPos
    lda CURSOR_STATE.xPos
    cmp CURSOR_STATE.xMax
    bcc _done
    inc HAS_LINE_CHANGED
    stz CURSOR_STATE.xPos
    inc CURSOR_STATE.yPos
    lda CURSOR_STATE.yPos
    cmp CURSOR_STATE.yMax
    bcc _done
    phy
    inc HAS_SCROLLED
    jsr scrollUp
    ply
    dec CURSOR_STATE.yPos
_done
    jsr cursorSet
    rts

HAS_SCROLLED     .byte 0
HAS_LINE_CHANGED .byte 0

; --------------------------------------------------
; This routine moves the cursor up one line. If it is called
; while the cursor is in the top line then the screen is scrolled 
; one line upwards.
;
; This routine does not return a value.
; --------------------------------------------------
up
    lda CURSOR_STATE.yPos
    bne _noScroll
    phy
    inc HAS_SCROLLED
    jsr scrollDown
    ply
    bra _done
_noScroll
    dec CURSOR_STATE.yPos
_done
    jsr cursorSet
    rts


; --------------------------------------------------
; This routine moves the cursor down one line. If it is called
; while the cursor is in the bottom line then the screen is scrolled
; one line upwards.
;
; This routine does not return a value.
; --------------------------------------------------
down
    inc CURSOR_STATE.yPos
    lda CURSOR_STATE.yPos
    cmp CURSOR_STATE.yMax
    bcc _done
    dec CURSOR_STATE.yPos
    phy
    inc HAS_SCROLLED
    jsr scrollUp
    ply
_done
    jsr cursorSet
    rts


; --------------------------------------------------
; This routine deletes the character left of the cursor and then
; moves the cursor one position to the left.
;
; This routine does not return a value.
; --------------------------------------------------
backSpace
    jsr left
    lda #32
    jsr charOut
    jsr left
    rts


; --------------------------------------------------
; This routine moves the cursor down one line and then places
; it on the leftmost position. If it is called in the last line
; the screen is scrolled on line upwards.
;
; This routine does not return a value.
; --------------------------------------------------
newLine
    stz CURSOR_STATE.xPos
    jsr down
    rts


; --------------------------------------------------
; This routine sets the cursor to the leftmost position in the current 
; line
;
; This routine does not return a value.
; --------------------------------------------------
leftMost
    stz CURSOR_STATE.xPos
    jsr cursorSet
    rts


; --------------------------------------------------
; This routine sets the cursor to the left upper corner at
; the screen coordinate 0,0.
;
; This routine does not return a value.
; --------------------------------------------------
home
    stz CURSOR_STATE.xPos
    stz CURSOR_STATE.yPos
    jsr cursorSet
    rts

clear_t .struct
    mem_size .word 0
.endstruct

CLEAR_STATE .dstruct clear_t


; --------------------------------------------------
; clear fills the screen segment with blank characters and the
; color matrix with the value given in CURSOR_STATE.col. It makes
; use of TXT_PTR2.
;
; This routine does not return a value.
; --------------------------------------------------
clear
    #saveIoState
    #move16Bit CURSOR_STATE.maxVideoRam, CLEAR_STATE.mem_size
    #sub16Bit CURSOR_STATE.vramOffset, CLEAR_STATE.mem_size
    #move16Bit CURSOR_STATE.vramOffset, TXT_PTR2
    ldy #0
_nextBlock
    lda CLEAR_STATE.mem_size + 1
    beq _lastBlockOnly
_clearBlock    
    #toTxtMatrix
    lda #32
    sta (TXT_PTR2), y
    #toColorMatrix
    lda CURSOR_STATE.col
    sta (TXT_PTR2), y
    iny
    bne _clearBlock
    inc TXT_PTR2+1
    dec CLEAR_STATE.mem_size+1
    bra _nextBlock

_lastBlockOnly
    lda CLEAR_STATE.mem_size
    beq _done
    ldy #0
_loop
    #toTxtMatrix
    lda #32
    sta (TXT_PTR2), y
    #toColorMatrix
    lda CURSOR_STATE.col
    sta (TXT_PTR2), y
    iny
    cpy CLEAR_STATE.mem_size
    bne _loop
_done
    #restoreIoState
    rts


scrollUp_t .struct
    line_count .byte 0
.endstruct

SCROLL_UP .dstruct scrollUp_t
SCROLL_DOWN .dstruct scrollUp_t

LINE_TEMP .byte 0
; accu has to contain the line to clear in the context of the
; screen segment.
clearLine
    sta LINE_TEMP
    #saveIoState
    jsr clearLineWithOffset
    #restoreIoState
    rts


; LINE_TEMP has to contain the line to clear in the context of the
; screen segment.
clearLineWithOffset
    #mul8x8BitCoproc LINE_TEMP, CURSOR_STATE.xMax, TXT_PTR1
    #add16Bit CURSOR_STATE.vramOffset, TXT_PTR1 
; TXT_PTR1 has to be set to line start
clearLineInternal
    ldy #0
_lastLineLoop
    #toTxtMatrix
    lda #32
    sta (TXT_PTR1), y
    #toColorMatrix
    lda CURSOR_STATE.col
    sta (TXT_PTR1), y
    iny
    cpy CURSOR_STATE.xMax
    bne _lastLineLoop

    rts


scrollDown
    lda CURSOR_STATE.scrollOn
    bne scrollDownInternal
    rts


; --------------------------------------------------
; scrollDownInternal scrolls the text screen one line down. It makes use
; of TXT_PTR1 and TXT_PTR2 in order to implement this functionality.
;
; This routine does not return a value.
; --------------------------------------------------
scrollDownInternal
    #saveIoState

    #move16Bit CURSOR_STATE.lastLinePtr, TXT_PTR1
    #move16Bit CURSOR_STATE.lastLinePtr, TXT_PTR2

    sec
    lda TXT_PTR2
    sbc CURSOR_STATE.xMax
    sta TXT_PTR2
    lda TXT_PTR2 + 1
    sbc #0    
    sta TXT_PTR2 + 1

    lda CURSOR_STATE.yMaxMinus1
    sta SCROLL_DOWN.line_count

    ; move all lines one step down
_nextLine
    ldy #0
_lineLoop
    #toTxtMatrix
    lda (TXT_PTR2), y
    sta (TXT_PTR1), y
    #toColorMatrix
    lda (TXT_PTR2), y
    sta (TXT_PTR1), y
    iny
    cpy CURSOR_STATE.xMax
    bne _lineLoop
    
    #move16Bit TXT_PTR2, TXT_PTR1
    dec SCROLL_DOWN.line_count
    beq _clearFirstLine

    sec
    lda TXT_PTR2
    sbc CURSOR_STATE.xMax
    sta TXT_PTR2
    lda TXT_PTR2+1
    sbc #0
    sta TXT_PTR2+1
    bra _nextLine

_clearFirstLine
    jsr clearLineInternal

    #restoreIoState
    rts


scrollUp
    lda CURSOR_STATE.scrollOn
    bne scrollUpInternal
    rts


; --------------------------------------------------
; scrollUpInternal scrolls the text screen one line up. It makes use
; of TXT_PTR1 and TXT_PTR2 in order to implement this functionality.
;
; This routine does not return a value.
; --------------------------------------------------
scrollUpInternal
    #saveIoState

    #move16Bit CURSOR_STATE.vramOffset, TXT_PTR1
    #move16Bit CURSOR_STATE.vramOffset, TXT_PTR2
    clc
    lda TXT_PTR2
    adc CURSOR_STATE.xMax
    sta TXT_PTR2
    lda #0
    adc TXT_PTR2+1
    sta TXT_PTR2+1

    stz SCROLL_UP.line_count

    ; move all lines on step up
_nextLine
    ldy #0
_lineLoop
    #toTxtMatrix
    lda (TXT_PTR2), y
    sta (TXT_PTR1), y
    #toColorMatrix
    lda (TXT_PTR2), y
    sta (TXT_PTR1), y
    iny
    cpy CURSOR_STATE.xMax
    bne _lineLoop
    
    #move16Bit TXT_PTR2, TXT_PTR1
    clc
    lda CURSOR_STATE.xMax
    adc TXT_PTR2
    sta TXT_PTR2
    lda #0
    adc TXT_PTR2+1
    sta TXT_PTR2+1

    inc SCROLL_UP.line_count
    lda SCROLL_UP.line_count
    cmp CURSOR_STATE.yMaxMinus1
    bne _nextLine

    #move16Bit CURSOR_STATE.lastLinePtr, TXT_PTR1

    ; clear last line
    jsr clearLineInternal

    #restoreIoState
    rts


prByteState_t .struct
    hex_chars .text "0123456789ABCDEF"
    temp_char .byte 0
.endstruct

PRBYTE .dstruct prByteState_t
; --------------------------------------------------
; printByte outputs the hex value of the byte stored in the accu.
;
; This routine does not return a value.
; --------------------------------------------------
printByte
    sta PRBYTE.temp_char
    and #$F0
    lsr
    lsr
    lsr
    lsr
    tay
    lda PRBYTE.hex_chars, y
    jsr charOut
    lda PRBYTE.temp_char
    and #$0F
    tay
    lda PRBYTE.hex_chars, y
    jsr charOut
    rts


WORD_TEMP .word 0
COUNT_DIGITS .byte 0
printWordDecimal
    stz COUNT_DIGITS
    #load16BitImmediate 10, $DE04
    lda WORD_TEMP 
    sta $DE06
    lda WORD_TEMP + 1
    sta $DE07
_loop
    ldx $DE16
    lda PRBYTE.hex_chars, x
    pha
    inc COUNT_DIGITS
    #cmp16BitImmediate 0, $DE14
    beq _done
    #move16Bit $DE14, $DE06
    bra _loop
_done
    ldy #0
_loop2
    pla
    jsr charOut
    iny
    cpy COUNT_DIGITS
    bne _loop2 
    rts

; --------------------------------------------------
; This routine reverses the colour that is currently defined in CURSOR_STATE.col
;
; This routine does not return a value.
; --------------------------------------------------
reverseColor
    lda CURSOR_STATE.col
    and #$F0
    lsr
    lsr
    lsr
    lsr
    sta PRBYTE.temp_char
    lda CURSOR_STATE.col
    and #$0F
    asl
    asl
    asl
    asl
    ora PRBYTE.temp_char
    sta CURSOR_STATE.col
    rts


prString_t .struct
    out_len .byte 0
.endstruct

PRINT_STR .dstruct prString_t
; --------------------------------------------------
; printStr prints the string to which TXT_PTR3 points assuming a
; that the number of characters to print is contained in the accu
;
; This routine does not return a value.
; --------------------------------------------------
printStr
    sta PRINT_STR.out_len
    ldy #0
_printLoop
    cpy PRINT_STR.out_len
    beq _done
    lda (TXT_PTR3), y
    cmp #CARRIAGE_RETURN
    bne _realChar
    jsr newLine
    bra _nextChar
_realChar
    jsr charOut
_nextChar
    iny
    bra _printLoop 
_done
    rts


printSpace_t .struct
    temp_x    .byte 0
    temp_y    .byte 0
    temp_size .byte 0
.endstruct

PRINT_SPACES .dstruct printSpace_t
; --------------------------------------------------
; printSpaces prints as many spaces as the value of the accu indicates.
;
; This routine does not return a value
; --------------------------------------------------
printSpaces
    sta PRINT_SPACES.temp_size

    ; save cursor position
    lda CURSOR_STATE.xPos
    sta PRINT_SPACES.temp_x
    lda CURSOR_STATE.yPos
    sta PRINT_SPACES.temp_y

    ; clear the selected characters
    ldy #0
    lda #32                               ; load code for space
_loopClear                                ; print desired number of blanks
    cpy PRINT_SPACES.temp_size            ; check first, this handles the case with length 0 correctly
    beq _doneClear     
    jsr charOut                           ; print blank
    iny
    bra _loopClear

_doneClear
    ; restore cursor position
    lda PRINT_SPACES.temp_x
    sta CURSOR_STATE.xPos
    lda PRINT_SPACES.temp_y
    sta CURSOR_STATE.yPos
    jsr cursorSet
    rts    


inputState_t .struct
    len_output   .byte 0
    len_allowed  .byte 0
    index_output .byte 0
    input_char   .byte 0
.endstruct

INPUT_STATE .dstruct inputState_t
; --------------------------------------------------
; This routine implements a robust string input allowing only characters
; from a given set. The address of the target buffer has to be specified in
; TXT_PTR4. TXT_PTR3 has to point to the set of allowed characters.
; The x register has to contain the length of the target buffer and the y
; register the length of the set of allowed characters.
;
; This routine returns the length of the string entered in the accu
; --------------------------------------------------
getString
    stx INPUT_STATE.len_output
    sty INPUT_STATE.len_allowed
    txa
    jsr printSpaces                            ; clear input text
    lda #0
    sta INPUT_STATE.index_output               ; set index in output to 0 
    jsr cursorOn

_inputLoop
    jsr waitForKey

    cmp #CARRIAGE_RETURN                       ; CR 
    beq _inputDone                             ; => We are done
    cmp #BACK_SPACE                            ; DELETE
    beq _delete                                ; delete one character from result string
    sta INPUT_STATE.input_char
    jsr checkIfInSet                           ; check if typed character is allowed
    bne _inputLoop                             ; Not allowed => try again

    lda INPUT_STATE.input_char
    ldy INPUT_STATE.index_output
    cpy INPUT_STATE.len_output                 ; have we reached the maximum length?
    beq _inputLoop                             ; yes => don't store
    sta (TXT_PTR4), y                          ; store typed character
    inc INPUT_STATE.index_output               ; move to next position in target buffer
    jsr charOut                                ; print typed character
    bra  _inputLoop                            ; let user type next character

_delete
    lda INPUT_STATE.index_output
    beq _inputLoop                             ; Output index is 0 => do nothing
    dec INPUT_STATE.index_output               ; decrement the output position
    jsr backSpace
    bra _inputLoop                             ; let user enter next character
_inputDone
    jsr cursorOff                            
    lda INPUT_STATE.index_output               ; load length of target buffer in accu    
    rts


checkIfInSet
    ldy #0
_checkLoop
    cmp (TXT_PTR3),Y               ; is typed character in allowed set
    beq _found                     ; yes => zero flag is set when routine returns
    iny 
    cpy INPUT_STATE.len_allowed               
    bne _checkLoop                 ; try next character
    ldy #1                         ; typed character is not allowed => zero flag is clear when routine returns
_found
    rts


; --------------------------------------------------
; This routine implements a robust string input allowing only characters
; from a given set. The address of the target buffer has to be specified in
; TXT_PTR4. TXT_PTR3 has to point to the set of allowed characters.
; The x register has to contain the length of the target buffer and the y
; register the length of the set of allowed characters.
;
; This routine only sets up only the necessary data structure. The key presses
; then must be processed one by one through calls to getStringFocusFunc as
; soon as a new character becomes available.
;
; This routine does not return a value.
; --------------------------------------------------
getStringNonBlocking
    stx INPUT_STATE.len_output
    sty INPUT_STATE.len_allowed
    txa
    jsr printSpaces                            ; clear input text
    lda #0
    sta INPUT_STATE.index_output               ; set index in output to 0 
    jsr cursorOn
    rts


; --------------------------------------------------
; This routine processes single characters as provided by external means. If the
; carry is clear upon return then the accu contains the length of the entered string.
; If the carry is set upon return then the text entry is not yet finished and the
; routine should be called again until the carry is clear.
; --------------------------------------------------
getStringFocusFunc
    cmp #CARRIAGE_RETURN                       ; CR 
    beq _inputDone                             ; => We are done
    cmp #BACK_SPACE                            ; DELETE
    beq _delete                                ; delete one character from result string
    sta INPUT_STATE.input_char
    jsr checkIfInSet                           ; check if typed character is allowed
    beq _procThisChar
    sec
    rts
_procThisChar
    lda INPUT_STATE.input_char
    ldy INPUT_STATE.index_output
    cpy INPUT_STATE.len_output                 ; have we reached the maximum length?
    bne _notEnd   
    sec
    rts
_notEnd
    sta (TXT_PTR4), y                          ; store typed character
    inc INPUT_STATE.index_output               ; move to next position in target buffer
    jsr charOut                                ; print typed character
    sec
    rts
_delete
    lda INPUT_STATE.index_output
    bne _doBackSpace
    sec
    rts
_doBackSpace
    dec INPUT_STATE.index_output               ; decrement the output position
    jsr backSpace
    sec
    rts
_inputDone
    jsr cursorOff                            
    lda INPUT_STATE.index_output               ; load length of target buffer in accu
    clc
    rts


.endnamespace