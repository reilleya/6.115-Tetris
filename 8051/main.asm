.org 000h
    ljmp start
    
.org 0bh
    lcall tick
	reti
    
.org 100h
start:
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
    mov R0, #0FFh
    mov R1, #0FFh
    mov R2, #00Bh
    delay:
        djnz R0, delay
        mov R0, #0FFh
        djnz R1, delay
        mov R0, #0FFh
        mov R1, #0FFh
        mov P1, R2
        djnz R2, delay
    ret
    
addpart:
    mov 40h, #0h                ; Set part type to 0
    mov 41h, #4h                ; Set part x to 4
    mov 42h, #0h                ; Set part y to 0
    ret

update:
    inc 42h
    mov R0, #42h
    cjne @R0, #00Ch, checkcol     ; Check if we hit the bottom
    sjmp freeze
    
    checkcol:
        mov R0, 42h
        mov A, #30h
        add A, R0
        mov R0, A
        
        mov R2, #0h
        mov R1, #60h                ; Sample part start
        copypart3:
            mov A, @R1                  ; Read in current row of current part
            anl A, @R0                  ; OR the row of the part with the FB row
            cjne A, #0h, decfreeze
            mov @R0, A
            inc R0
            inc R1
            inc R2
            cjne R2, #04h, copypart3
        sjmp updateend
    
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
            orl A, @R0                  ; OR the row of the part with the FB row
            mov @R0, A
            inc R0
            inc R1
            inc R2
            cjne R2, #04h, copypart2
        lcall addpart
    
    updateend:
    
    ret

draw:
    ; Moves the contents of the game state buffer into the frame buffer
    mov R0, #30h
    mov R1, #20h
    mov R2, #10h
    copyrow:
        mov A, @R0
        mov @R1, A
        inc R0
        inc R1
        djnz R2, copyrow
    
    ; Grabs the relevant row from the game frame buffer
    mov R0, 42h
    mov A, #20h
    add A, R0
    mov R0, A
    
    mov R2, #0h
    mov R1, #60h                ; Sample part start
    copypart:
        mov A, @R1                  ; Read in current row of current part
        orl A, @R0                  ; OR the row of the part with the FB row
        mov @R0, A
        inc R0
        inc R1
        inc R2
        cjne R2, #04h, copypart
    

    mov R0, #20h
    mov R1, #10h
    row:
        mov A, @R0
        lcall sndchr
        inc R0
        djnz R1, row
    mov A, #0ah
    lcall sndchr
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
    mov R0, #20h
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
    
    mov 40h, #0h                ; Set part type to 0
    mov 41h, #4h                ; Set part x to 4
    mov 42h, #0h                ; Set part y to 0
    
    mov 43h, #0h                ; Set tick to 0
    
    mov 60h, #0b00000000        ; Sample part
    mov 61h, #0b00010000
    mov 62h, #0b00010000
    mov 63h, #0b00011000
    
    ret
    