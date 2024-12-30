; --------------------------------------------------
; This macro prints moves the contents of the two bytes stored
; at source and source + 1 to the memory location beginning at
; target.
;--------------------------------------------------
move16Bit .macro src, target
    lda \src
    sta \target
    lda \src+1
    sta \target+1
    .endmacro

; --------------------------------------------------
; load16BitImmediate loads the 16 bit value given in the first argument 
; into the memory location given the second argument.
; --------------------------------------------------
load16BitImmediate .macro addr, target
    lda #<\addr
    sta \target
    lda #>\addr
    sta \target+1
    .endmacro


; --------------------------------------------------
; inc16Bit implements a 16 bit increment of the 16 bit value stored at .memAddr 
; --------------------------------------------------
inc16Bit .macro memAddr
    clc
    lda #1
    adc \memAddr
    sta \memAddr
    bcc _noCarryInc
    inc \memAddr+1
_noCarryInc
    .endmacro


; --------------------------------------------------
; cmp16Bit compares the 16 bit values stored at memAddr1 and memAddr2 
; Z  flag is set in case these values are equal
; --------------------------------------------------
cmp16Bit .macro  memAddr1, memAddr2 
    lda \memAddr1+1
    cmp \memAddr2+1
    bne _unequal
    lda \memAddr1
    cmp \memAddr2
_unequal
.endmacro


; --------------------------------------------------
; cmp16BitImmediate compares the 16 bit value stored at memAddr with
; the immediate value given in .value.
; 
; Z  flag is set in case these values are equal. Carry is set
; if .value is greater or equal than the value store at .memAddr
; --------------------------------------------------
cmp16BitImmediate .macro  value, memAddr 
    lda #>\value
    cmp \memAddr+1
    bne _unequal2
    lda #<\value
    cmp \memAddr
_unequal2
.endmacro


; --------------------------------------------------
; add16BitImmediate implements a 16 bit add of an immediate value to value stored at memAddr2 
; The result is stored in .memAddr2
; --------------------------------------------------
add16BitImmediate .macro  value, memAddr2 
    clc
    ; add lo bytes
    lda #<\value
    adc \memAddr2
    sta \memAddr2
    ; add hi bytes
    lda #>\value
    adc \memAddr2+1
    sta \memAddr2+1
.endmacro


; --------------------------------------------------
; add16Bit implements a 16 bit add of the values stored at memAddr1 and memAddr2 
; The result is stored in .memAddr2
; --------------------------------------------------
add16Bit .macro  memAddr1, memAddr2 
    clc
    ; add lo bytes
    lda \memAddr1
    adc \memAddr2
    sta \memAddr2
    ; add hi bytes
    lda \memAddr1+1
    adc \memAddr2+1
    sta \memAddr2+1
.endmacro


; --------------------------------------------------
; sub16Bit subtracts the value stored at .memAddr1 from the value stored at the
; address .memAddr2. The result is stored in .memAddr2
; --------------------------------------------------
sub16Bit .macro  memAddr1, memAddr2 
    sec
    lda \memAddr2
    sbc \memAddr1
    sta \memAddr2
    lda \memAddr2+1
    sbc \memAddr1+1
    sta \memAddr2+1
.endmacro


mul8x8BitCoproc .macro oper1, oper2, oper3
    lda \oper1
    sta $DE00
    stz $DE01
    lda \oper2
    sta $DE02
    stz $DE03
    #move16Bit $DE10, \oper3
.endmacro


; --------------------------------------------------
; double16Bit multiplies the 16 bit value stored at .memAddr by 2
; --------------------------------------------------
double16Bit .macro  memAddr     
    asl \memAddr                     
    rol \memAddr+1
.endmacro

; --------------------------------------------------
; This macro prints a string to the screen at a given x and y coordinate. The 
; macro has the following parameters
;
; 1. x coordinate
; 2. y coordinate
; 3. address of text to print
; 4. length of text to print
; 5. address of color information
;--------------------------------------------------
kprint .macro x, y, txtPtr, len, colPtr
     lda #\x                                     ; set x coordinate
     sta kernel.args.display.x
     lda #\y                                     ; set y coordinate
     sta kernel.args.display.y
     #load16BitImmediate \txtPtr, kernel.args.display.text
     lda #\len                                   ; set text length
     sta kernel.args.display.buflen
     #load16BitImmediate \colPtr, kernel.args.display.color
     jsr kernel.Display.DrawRow                  ; print to the screen
     .endmacro

kprintAddr .macro x, y, txtPtr, len, colPtr
     lda #\x                                     ; set x coordinate
     sta kernel.args.display.x
     lda #\y                                     ; set y coordinate
     sta kernel.args.display.y
     #move16Bit \txtPtr, kernel.args.display.text
     lda \len                                   ; set text length
     sta kernel.args.display.buflen
     #load16BitImmediate \colPtr, kernel.args.display.color
     jsr kernel.Display.DrawRow                  ; print to the screen
     .endmacro