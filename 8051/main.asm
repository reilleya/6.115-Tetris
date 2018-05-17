.equ    rand8reg, 45h

.org 000h
    ljmp start
    
.org 100h
start:
    mov P1, 0FFh
    mov P3, 0FFh
    mov rand8reg, #06Eh          ; Seed random
    mov 46h, #008h
    lcall initser
    lcall setupboard
    loop:                       ; Main loop
        lcall wait
        lcall draw
        lcall update
        sjmp loop
    gameover:
        mov 46h, #008h
        mov A, #0h
        lcall drawimage
        lcall wait
        
        mov 46h, #008h
        mov A, #1h
        lcall drawimage
        lcall wait
        
        mov 46h, #003h
        mov A, #2h
        lcall drawimage
        lcall wait
        
        mov 46h, #003h
        mov A, #3h
        lcall drawimage
        lcall wait
        
        mov 46h, #003h
        mov A, #4h
        lcall drawimage
        lcall wait
        
        sjmp gameover

wait:
    mov R4, #0FFh
    mov R5, #0FFh
    mov R6, 46h
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
    
    jb P3.4, checkdouble
    jb P3.3, checkleft
    sjmp donecheck
    
    checkdouble:
        jb P3.3, checkright
        sjmp checkrot

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
    
drawimage:
    mov R0, #0h
    mov DPTR, #700h
    mov B, #010h
    mul AB
    mov DPL, A
    loadimagebyte:
        mov A, #0h
        movc a, @a+dptr
        lcall sndchr
        inc DPL
        inc R0
        cjne R0, #010h, loadimagebyte
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
    mov 42h, #0h              ; Set part y to 0
    lcall checkcollision                ; Check if the newly added part collides
    jb 41h, gotogameover                ; If it does, the game is over
    ret
    gotogameover:
        ljmp gameover
        

checkcollision:                         ; Checks for collisions of the current part. Sets bit 41h if there is a collision, clears it if not.
    clr 41h
    mov R0, 42h                         ; Gets Y position of part
    mov A, #30h                         ; Start of game state array
    add A, R0                           ; Generates a pointer to the row in the game state where the current part is
    mov R0, A                           ; R0 stores the pointer to that row

                                        ; Detect collisions with frozen-in parts
    mov R2, #0h                         ; Counter for the rows copied
    mov R1, #60h                        ; Current part start
    copypart4:
        mov A, @R1                      ; Read in current row of current part
        mov R3, 41h                     ; Gets the X position of the current part
        ls4:                            ; Loop to left shift the part to its X position
            rl A
            djnz R3, ls4
        anl A, @R0                      ; AND the row of the part with the FB row
        cjne A, #0h, hitdet          ; If the result isn't 0, a collision has occurred!
        inc R0                          ; Otherwise, increment the pointer to the current row of the game state buffer
        inc R1                          ; Also increment the pointer to the current row of the part
        inc R2                          ; Finally, increment the row counter
        cjne R2, #04h, copypart4        ; After 4 rows, the loop is done
    ret
    hitdet:
        setb 41h
    ret
    
update:                                 ; Called every loop to update the game state
    inc 42h                             ; Move the piece down a row

    lcall checkcollision                ; Check if a collision occurred
    jb 41h, decfreeze                   ; Move the part back up if one did
    
                                        ; Next, check if the piece is at the bottom of the field
    mov R0, #42h                        ; Get the current Y position of the part
    cjne @R0, #00Ch, updateend          ; Check if we hit the bottom. If not, the update is done
    sjmp freeze                         ; Stop the part
    
    decfreeze:                          ; Jumped to in the case of a collision, when we need to move the part back up
        dec 42h                         ; Move the part back up
    freeze:                             ; Bakes a part into the game state array
        mov R0, 42h
        mov A, #30h
        add A, R0
        mov R0, A
        
        mov R2, #0h
        mov R1, #60h                    ; Current part start
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

draw:                                   ; Outputs the game state over serial
                                        ; Moves the contents of the game state buffer into the frame buffer
    mov R0, #30h                        ; Start of the game state array
    mov R1, #50h                        ; Start of the frame buffer
    mov R2, #10h                        ; Length of both
    copyrow:                            ; Loop that copies each row of the game state into the frame buffer
        mov A, @R0
        mov @R1, A
        inc R0
        inc R1
        djnz R2, copyrow
                                        ; Copy the current part onto the frame buffer
    mov R0, 42h                         ; Gets the position of the current part
    mov A, #50h                         ; The position in memory of the frame buffer
    add A, R0                           ; Add them to get the position in memory of the row that the first row of the part occupies
    mov R0, A
    mov R2, #0h                         ; Start a counter to loop over the 4 rows of the part
    mov R1, #60h                        ; Current part start
    copypart:                           ; Loop that copies the current part into the frame buffer
        mov A, @R1                      ; Read in current row of current part
        mov R3, 41h                     ; Read in the X position of the part
        ls:                             ; Loop that left shifts the part by its X position
            rl A
            djnz R3, ls
        orl A, @R0                      ; OR the row of the part with the FB row
        mov @R0, A                      ; Store the row back into the frame buffer
        inc R0                          ; Increments the pointer to the row in the frame buffer
        inc R1                          ; Increment the pointer to the next row of the part
        inc R2                          ; Count up current row counter
        cjne R2, #04h, copypart         ; Count up to 4 rows, because all parts have 4 rows of data
        
                                        ; Send the completed frame buffer over serial
    mov R0, #50h                        ; Pointer to the beginning of the frame buffer
    mov R1, #10h                        ; Length of the frame buffer
    row:                                ; Loop to send each row of the FB
        mov A, @R0
        lcall sndchr
        inc R0
        djnz R1, row
    ret
    
initser:                                ; Sets up serial port timer for 9600 baud
    mov th0, #0h
    mov tl0, #0h

    mov tmod, #021h                     ; Set timer 1 for auto reload, mode 2
    mov tcon, #050h                     ; Run timer 1
    mov th1, #0fdh                      ; Set 9600 baud with xtal=11.059 mhz
    mov scon, #050h                     ; Set serial control reg for 8 bit data, and mode 1
    
    ;setb IE.1                          ; Enable timer 0 interrupts
    ;setb EA                            ; Enable interrupts
    
    ret

getchr:                                 ; Waits until a char appears in the serial port and puts it in A
    jnb ri, getchr                      ; Loop until a character is received
    mov a, sbuf                         ; Move the character from the buffer into A
    anl a, #7Fh                         ; The 8th bit doesn't matter, so remove it
    clr ri                              ; Mark that the byte was received
    ret

sndchr:                                 ; Prints the char in A out on the serial port
    clr scon.1                          ; Mark the send as not complete
    mov sbuf, a                         ; Move the character from A to the serial buffer
    txloop:                             ; Loop that runs until the character has been sent
        jnb scon.1, txloop
    ret

setupboard:                             ; Initializes the game
    mov R0, #50h                        ; Start of the frame buffer
    mov R1, #10h                        ; Length of frame buffer
    setrowfb:                           ; Loop to 0 all of the rows of the FB
        mov @R0, #0b00000000
        inc R0
        djnz R1, setrowfb
    mov R0, #30h                        ; Start of the game state buffer
    mov R1, #10h                        ; Length of the game state buffer
    setrowbs:                           ; Loop that 0's the game state buffer
        mov @R0, #0b00000000
        inc R0
        djnz R1, setrowbs
    
    lcall addpart                       ; Add a new random part
    
    ret
    
rand8:	mov	a, rand8reg                 ; Random procedure from PJRC
	jnz	rand8b                          ; Stores a random value in A
	cpl	a                               ; Requires a dedicated memory address
	mov	rand8reg, a                     ; I picked 45h
rand8b:	anl	a, #10111000b
	mov	c, p
	mov	a, rand8reg
	rlc	a
	mov	rand8reg, a
	ret

.org 700h
    ; You
    .db 0b01100110
    .db 0b01100110
    .db 0b01111110
    .db 0b00011000
    .db 0b00011000
    .db 0b00000000
    .db 0b01111110
    .db 0b01000010
    .db 0b01000010
    .db 0b01000010
    .db 0b01111110
    .db 0b00000000
    .db 0b01000010
    .db 0b01000010
    .db 0b01100110
    .db 0b01111110
    
    ;Los(t)
    .db 0b01100000
    .db 0b01100000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01001000
    .db 0b01001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01000000
    .db 0b01111000
    .db 0b00001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    
    .db 0b01100000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01001000
    .db 0b01001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01000000
    .db 0b01111000
    .db 0b00001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b00110000
    
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01001000
    .db 0b01001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01000000
    .db 0b01111000
    .db 0b00001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b00110000
    .db 0b00110000

    .db 0b00000000
    .db 0b01111000
    .db 0b01001000
    .db 0b01001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b01000000
    .db 0b01111000
    .db 0b00001000
    .db 0b01111000
    .db 0b00000000
    .db 0b01111000
    .db 0b00110000
    .db 0b00110000
    .db 0b00110000


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
    
