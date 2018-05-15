.equ    rand8reg, 45h

.org 000h
    ljmp start
    
.org 0bh
    lcall tick
	reti
    
.org 100h
start:
    mov P1, 0FFh
    mov P3, 0FFh
    mov rand8reg, #0AEh          ; Seed random
    lcall initser
    lcall setupboard
    loop:                       ; Main loop
        lcall wait
        lcall draw
        lcall update
        sjmp loop

tick:
    inc 43h
    mov th0, #0h
    mov tl0, #0h
    ret
        
wait:
    mov R4, #0FFh
    mov R5, #0FFh
    mov R6, #00Bh
    delay:
        djnz R4, delay
        mov R4, #0FFh
        lcall checkinp
        djnz R5, delay
        mov R4, #0FFh
        mov R5, #0FFh
        djnz R6, delay
    ret
    
checkinp:
    jnb P3.2, notpressed
    jb 40h, donecheck
    setb 40h
    
    jb P1.0, checkleft
    jb P1.1, checkright
    jb P1.2, checkrot
    sjmp donecheck
    
    checkleft:
        mov A, 41h
        cjne A, 65h, moveleft
        sjmp donecheck
        moveleft:
        inc 41h
        lcall draw
        sjmp donecheck
    
    checkright:
        mov A, 41h
        cjne A, #0h, moveright
        sjmp donecheck
        moveright:
        dec 41h
        lcall draw
        sjmp donecheck
    
    checkrot:
        mov R0, #40h
        mov @R0, 64h
        lcall getpart
        lcall draw
        sjmp donecheck
    
    notpressed:
        clr 40h
    donecheck:
        ret
    
getpart:
    mov R0, #0h
    mov R1, #60h
    mov DPTR, #800h
    loadpartbyte:
        mov A, 40h
        mov B, #7h
        mul AB
        add A, R0
        movc a, @a+dptr
        mov @R1, A
        inc R0
        inc R1
        cjne R0, #7h, loadpartbyte
    ret
    
addpart:
    lcall rand8
    mov B, #12h
    div AB
    mov 40h, B                ; Set part type to 0
    lcall getpart
    lcall rand8
    mov B, 65h
    div AB
    mov 41h, B                ; Set part x to 4
    mov 42h, #0h                ; Set part y to 0
    ret

update:
    inc 42h
    
    mov R0, 42h
    mov A, #30h
    add A, R0
    mov R0, A
    
    mov R2, #0h
    mov R1, #60h                ; Sample part start
    copypart3:
        mov A, @R1                  ; Read in current row of current part
        mov R3, 41h
        ls3:
            rl A
            djnz R3, ls3
        anl A, @R0                  ; OR the row of the part with the FB row
        cjne A, #0h, decfreeze
        inc R0
        inc R1
        inc R2
        cjne R2, #04h, copypart3
    
    mov R0, #42h
    cjne @R0, #00Ch, updateend     ; Check if we hit the bottom
    sjmp freeze
    
    decfreeze:
        dec 42h
    freeze:
        ; Grabs the relevant row from the game frame buffer
        mov R0, 42h
        mov A, #30h
        add A, R0
        mov R0, A
        
        mov R2, #0h
        mov R1, #60h                ; Sample part start
        copypart2:
            mov A, @R1                  ; Read in current row of current part
            mov R3, 41h
            ls2:
                rl A
                djnz R3, ls2
            orl A, @R0                  ; OR the row of the part with the FB row
            mov @R0, A
            inc R0
            inc R1
            inc R2
            cjne R2, #04h, copypart2
        lcall addpart
    
    updateend:
    
    mov R0, #30h
    mov R2, #10h
    checkrow:
        cjne @R0, #0FFh, notfull
        mov @R0, #0h
        mov 3, 0
        mov 1, 0
        dec R1
        
        moverow:
            mov A, @R1
            mov @R0, A
            dec R0
            dec R1
            cjne R1, #2Fh, moverow
        
        mov 0, 3    
        notfull:
            inc R0
            djnz R2, checkrow 
    ret

draw:
    ; Moves the contents of the game state buffer into the frame buffer
    mov R0, #30h
    mov R1, #50h
    mov R2, #10h
    copyrow:
        mov A, @R0
        mov @R1, A
        inc R0
        inc R1
        djnz R2, copyrow
    
    ; Grabs the relevant row from the game frame buffer
    mov R0, 42h
    mov A, #50h
    add A, R0
    mov R0, A
    
    mov R2, #0h
    mov R1, #60h                ; Sample part start
    copypart:
        mov A, @R1                  ; Read in current row of current part
        mov R3, 41h
        ls:
            rl A
            djnz R3, ls
        orl A, @R0                  ; OR the row of the part with the FB row
        mov @R0, A
        inc R0
        inc R1
        inc R2
        cjne R2, #04h, copypart
    

    mov R0, #50h
    mov R1, #10h
    row:
        mov A, @R0
        lcall sndchr
        inc R0
        djnz R1, row
    ;mov A, #0ah
    ;lcall sndchr
    ret
    
initser:                        ; Sets up serial port timer for 9600 baud
    mov th0, #0h
    mov tl0, #0h

    mov tmod, #021h             ; Set timer 1 for auto reload, mode 2
    mov tcon, #050h             ; Run timer 1
    mov th1, #0fdh              ; Set 9600 baud with xtal=11.059 mhz
    mov scon, #050h             ; Set serial control reg for 8 bit data, and mode 1
    
    ;setb IE.1                   ; Enable timer 0 interrupts
    ;setb EA                     ; Enable interrupts
    
    ret

getchr:                         ; Waits until a char appears in the serial port and puts it in A
    jnb ri, getchr              ; Loop until a character is received
    mov a, sbuf                 ; Move the character from the buffer into A
    anl a, #7Fh                 ; The 8th bit doesn't matter, so remove it
    clr ri                      ; Mark that the byte was received
    ret

sndchr:                         ; Prints the char in A out on the serial port
    clr scon.1                  ; Mark the send as not complete
    mov sbuf, a                 ; Move the character from A to the serial buffer
    txloop:                     ; Loop that runs until the character has been sent
        jnb scon.1, txloop
    ret

setupboard:
    mov R0, #50h
    mov R1, #10h
    setrowfb:
        mov @R0, #0b00000000
        inc R0
        djnz R1, setrowfb
    mov R0, #30h
    mov R1, #10h
    setrowbs:
        mov @R0, #0b00000000
        inc R0
        djnz R1, setrowbs
    
    lcall addpart
    
    ret
    
rand8:	mov	a, rand8reg
	jnz	rand8b
	cpl	a
	mov	rand8reg, a
rand8b:	anl	a, #10111000b
	mov	c, p
	mov	a, rand8reg
	rlc	a
	mov	rand8reg, a
	ret

.org 800h    
parts:
    ; Part 0, L
    .db 0b00000000
    .db 0b00000010
    .db 0b00000010
    .db 0b00000011
    .db 0x1
    .db 0x6
    .db 0x1
    ; Part 1, L
    .db 0b00000000
    .db 0b00000000
    .db 0b00000111
    .db 0b00000100
    .db 0x2
    .db 0x5
    .db 0x2
    ; Part 2, L
    .db 0b00000000
    .db 0b00000011
    .db 0b00000001
    .db 0b00000001
    .db 0x3
    .db 0x6
    .db 0x1
    ; Part 3, L
    .db 0b00000000
    .db 0b00000000
    .db 0b00000001
    .db 0b00000111
    .db 0x0
    .db 0x5
    .db 0x2
    
    
    ; Part 4, fL
    .db 0b00000000
    .db 0b00000001
    .db 0b00000001
    .db 0b00000011
    .db 0x5
    .db 0x6
    .db 0x1
    ; Part 5, fL
    .db 0b00000000
    .db 0b00000000
    .db 0b00000100
    .db 0b00000111
    .db 0x6
    .db 0x5
    .db 0x2
    ; Part 6, fL
    .db 0b00000000
    .db 0b00000011
    .db 0b00000010
    .db 0b00000010
    .db 0x7
    .db 0x6
    .db 0x1
    ; Part 7, fL
    .db 0b00000000
    .db 0b00000000
    .db 0b00000111
    .db 0b00000001
    .db 0x4
    .db 0x5
    .db 0x2
    
    
    ; Part 8, I
    .db 0b00000001
    .db 0b00000001
    .db 0b00000001
    .db 0b00000001
    .db 0x9
    .db 0x7
    .db 0x0
    ; Part 9, I
    .db 0b00000000
    .db 0b00000000
    .db 0b00000000
    .db 0b00001111
    .db 0x8
    .db 0x4
    .db 0x3
    
    
    ; Part 10, B
    .db 0b00000000
    .db 0b00000000
    .db 0b00000011
    .db 0b00000011
    .db 0xA
    .db 0x6
    .db 0x2
    
    
    ; Part 11, S
    .db 0b00000000
    .db 0b00000000
    .db 0b00000011
    .db 0b00000110
    .db 0xC
    .db 0x5
    .db 0x2
    ; Part 12, S
    .db 0b00000000
    .db 0b00000010
    .db 0b00000011
    .db 0b00000001
    .db 0xB
    .db 0x6
    .db 0x1
    
    
    ; Part 13, T
    .db 0b00000000
    .db 0b00000000
    .db 0b00000010
    .db 0b00000111
    .db 0xE
    .db 0x5
    .db 0x2
    ; Part 14, T
    .db 0b00000000
    .db 0b00000010
    .db 0b00000011
    .db 0b00000010
    .db 0xF
    .db 0x6
    .db 0x1
    ; Part 15, T
    .db 0b00000000
    .db 0b00000000
    .db 0b00000111
    .db 0b00000010
    .db 0x10
    .db 0x5
    .db 0x2
    ; Part 16, T
    .db 0b00000000
    .db 0b00000001
    .db 0b00000011
    .db 0b00000001
    .db 0xD
    .db 0x6
    .db 0x1
    
    ; Part 17, Z
    .db 0b00000000
    .db 0b00000000
    .db 0b00000110
    .db 0b00000011
    .db 0x12
    .db 0x5
    .db 0x2
    ; Part 18, Z
    .db 0b00000000
    .db 0b00000001
    .db 0b00000011
    .db 0b00000010
    .db 0x11
    .db 0x6
    .db 0x1
    
