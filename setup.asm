setup .namespace

mmu
    ; setup MMU, this seems to be neccessary when running as a PGZ
    lda #%10110011                         ; set active and edit LUT to three and allow editing
    sta 0
    lda #%00000000                         ; enable io pages and set active page to 0
    sta 1

    ; map BASIC ROM out and RAM in
    lda #4
    sta 8+4
    lda #5
    sta 8+5
    rts

; 8  0: 0000 - 1FFF
; 9  1: 2000 - 3FFF
; 10 2: 4000 - 5FFF
; 11 3: 6000 - 7FFF
; 12 4: 8000 - 9FFF
; 13 5: A000 - BFFF
; 14 6: C000 - DFFF
; 15 7: E000 - FFFF
;
; RAM expansion/Flash cartridge 
; 0x100000 - 0x13FFFF


.endnamespace