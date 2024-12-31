memory .namespace

SHIFT_HELP .byte 0
DELETE_POS_HELP .byte 0
; This routine shifts the memory area to which MEM_PTR1 points and which has the length given in y
; one position to the left beginning with the position specified in the accu. The "hole" that
; is created at the end is filled with a space character. Upon return y is set to the
; position of the "hole" that was created.
;
; ***** Beware **** This routine uses self modifying code. I know this is ugly but doing it
; in the "proper" way would not be nice either.
vecShiftleft
    ; save length
    sty SHIFT_HELP
    ; if length is zero do nothing
    cpy #0
    beq doneL
    ; from here on length is at least one
    ; save delete position
    sta DELETE_POS_HELP
    ina
    ; compare with length
    cmp SHIFT_HELP
    ; do we want to delete the last character?
    ; if yes we simply overwrite the last character. This also handles the special case where
    ; the data has length one
    beq shftDoneL
    lda DELETE_POS_HELP
    tay
    ina
    tax
    ; modify the base addresses of the lda, x and the sta, y
    #move16Bit MEM_PTR1, shftSrcAddrL
    #move16Bit MEM_PTR1, shftTargetAddrL
shftLoopL
    cpx SHIFT_HELP
    beq shftDoneL
    ; After modification: lda srcAddr, x
    .byte $BD
shftSrcAddrL
    .word 0
    ; After modification sta srcAddr, y
    .byte $99
shftTargetAddrL
    .word 0
    inx
    iny
    bra shftLoopL
shftDoneL
    lda #$20
    ldy SHIFT_HELP
    dey
    ; we won't overdo it with the self modifiying code
    sta (MEM_PTR1), y
doneL
    rts

.endnamespace