.org 000h
    ljmp start
    
.org 100h
start:
    lcall initser
    lcall setupboard
    loop:                       ; Main loop
        lcall wait
        lcall draw
        
        ;inc 42h
        sjmp loop
    
wait:
    mov R0, #0FFh
    mov R1, #0FFh
    delay:
        djnz R0, delay
        mov R0, #0FFh
        djnz R1, delay
    ret
    
addpart:
    mov 40h, #0h                ; Set part type to 0
    mov 41h, #4h                ; Set part x to 4
    mov 42h, #0h                ; Set part y to 0
    
draw:
    ; Moves the contents of the game state buffer into the frame buffer
    mov R0, #20h
    mov R1, #30h
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
    mov tmod, #020h             ; Set timer 1 for auto reload, mode 2
    mov tcon, #040h             ; Run timer 1
    mov th1, #0fdh              ; Set 9600 baud with xtal=11.059 mhz
    mov scon, #050h             ; Set serial control reg for 8 bit data, and mode 1
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
    
    mov 60h, #0b00000000
    mov 61h, #0b00010000
    mov 62h, #0b00010000
    mov 63h, #0b00011000
    
    ret
    