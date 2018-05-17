.equ    rand8reg, 45h

.org 000h
    ljmp start
    
.org 100h
start:
    mov P1, 0h                          ; Zero the score counter
    mov P3, 0FFh                        ; Protect the P3 inputs
    mov rand8reg, #06Eh                 ; Seed random
    mov 46h, #008h                      ; Initial timer value
    lcall initser                       ; Setup the serial port
    lcall setupboard                    ; Setup the game board
    loop:                               ; Main loop
        lcall wait                      ; Wait for a variable amount of time
        lcall draw                      ; Draw the previous state
        lcall update                    ; Update the game state
        sjmp loop                       ; Loop endlessly
        
    gameover:                           ; Endless loop when the user loses
        mov 46h, #008h                  ; Long delay
        mov A, #0h                      ; Show the "You" image
        lcall drawimage
        lcall wait
        
        mov 46h, #008h                  ; Long delay
        mov A, #1h                      ; Show the los image
        lcall drawimage
        lcall wait
        
        mov 46h, #003h                  ; Short delay
        mov A, #2h                      ; Show the los(t) image
        lcall drawimage
        lcall wait
        
        mov 46h, #003h                  ; Short delay
        mov A, #3h                      ; Show the (l)ost image
        lcall drawimage
        lcall wait
        
        mov 46h, #008h                  ; Long delay
        mov A, #4h                      ; Show the ost image
        lcall drawimage
        lcall wait
        
        sjmp gameover

wait:                                   ; Waits for an amount of time dependent on the value in 46h, and polls inputs
    mov R4, #0FFh                       ; Reload counter
    mov R5, #0FFh                       ; Reload counter
    mov R6, 46h                         ; Reload outer counter to variable
    delay:                              ; Counts down from 255*255*(value in 46h)
        djnz R4, delay
        mov R4, #0FFh
        lcall checkinp                  ; Poll the buttons regularly during the loop
        djnz R5, delay
        mov R4, #0FFh
        mov R5, #0FFh
        djnz R6, delay
    ret
    
checkinp:                               ; Polls key pad and moves parts
    jnb P3.2, notpressed                ; 3.2 is the "data available" pin on the 922
    jb 40h, donecheck                   ; Bit 40h gets set if a button press has already been serviced
    setb 40h
    
    jb P3.4, checkdouble                ; If 3.4 is high, either right or rotate is pressed
    jb P3.3, checkleft                  ; If only 3.3 is high, it must be left
    sjmp donecheck                      ; Nothing pressed
    
    checkdouble:                        ; Determine if right or rotate was pressed, based on 3.3
        jb P3.3, checkright
        sjmp checkrot

    checkleft:                          ; Handles left movement
        mov A, 41h                      ; Get the X position
        cjne A, 65h, moveleft           ; Compare it to the part's max X to determine if the part can move
        sjmp donecheck                  ; If not, nothing to do
        moveleft:
        inc 41h                         ; Move the part to the left
        lcall checkcollision            ; Check for a collision in the new position
        jb 41h, undoleft                ; Undo the movement if it has collided
        lcall draw                      ; If not, draw the new state
        sjmp donecheck
        undoleft:                       ; Undo the move to the left
            dec 41h
            sjmp donecheck
    
    checkright:                         ; Handles right movement
        mov A, 41h                      ; Get the X value of the part
        cjne A, #0h, moveright          ; If it is 0, we can't move any further to the right
        sjmp donecheck                  ; Nothing to do if we can't move
        moveright:
        dec 41h                         ; Move the part to the right
        lcall checkcollision            ; Check for a collision in the new position
        jb 41h, undoright               ; If a collision occurred, undo the move
        lcall draw                      ; Otherwise, draw the new state
        sjmp donecheck
        undoright:
            inc 41h                     ; Undo the move to the right
            sjmp donecheck
    
    checkrot:                           ; Handles rotation
        mov R2, 40h                     ; Store the current part type in case we need to rotate back
        mov R0, #40h                    ; Pointer to the current part type
        mov @R0, 64h                    ; Set the current part type to the "next part" from our part data
        lcall getpart                   ; Grab the new part data
        lcall checkcollision            ; Check if the new part is in a valid position
        jb 41h, undorot                 ; If there is a collision, undo the rotation
        lcall draw                      ; Otherwise, draw the new state
        sjmp donecheck                  ; Rotation complete
        undorot:                        ; Undo the rotation if it is invalid
            mov 40h, R2                 ; Reset the part type to the previous value
            lcall getpart               ; Restore the part data
            sjmp donecheck
    
    notpressed:                         ; Reset the pressed bit
        clr 40h
    donecheck:
        ret
    
getpart:                                ; Pulls the data for a part out of prog memory and stores it at 60h
    mov R0, #0h                         ; Counter
    mov R1, #60h                        ; Destination, where data about the current part is stored
    mov DPTR, #800h                     ; Origin, where all the part data is stored
    loadpartbyte:                       ; Loop that extracts each byte
        mov A, 40h                      ; Put the current part type into A
        mov B, #7h                      ; Multiply by the size of a part to get the offset
        mul AB
        add A, R0                       ; Add the offset to counter to get the index we are copying
        movc a, @a+dptr                 ; Get the byte from prog mem
        mov @R1, A                      ; Save the byte into the current part data location, starting at 60h
        inc R0                          ; Count up
        inc R1                          ; Increment pointer to next byte
        cjne R0, #7h, loadpartbyte      ; Loop until we hit the part size
    ret
    
drawimage:                              ; Send an image at position A from the program memory over serial
    mov R0, #0h                         ; Index into the image, starts at 0
    mov DPTR, #700h                     ; Point to the beginning of the image array
    mov B, #010h                        ; The size of each image
    mul AB                              ; A holds the image that we want to send, so this calculates the offset to the image
    mov DPL, A                          ; Point DPTR to the image
    loadimagebyte:                      ; Loop that sends each byte over serial
        mov A, #0h                      ; A+DPTR=DPTR
        movc a, @a+dptr                 ; Grab the byte from memory
        lcall sndchr                    ; Send the byte
        inc DPL                         ; Point to the next byte
        inc R0                          ; Increment the counter
        cjne R0, #010h, loadimagebyte
    ret
    
addpart:
    lcall rand8                         ; Get a random number for the part type
    mov B, #12h                         ; There are 18 different parts
    div AB
    mov 40h, B                          ; Set the random part type
    lcall getpart
    lcall rand8                         ; Calculate a random valid X position
    mov B, 65h
    div AB
    mov 41h, B                          ; Set the part's X to a random valid position
    mov 42h, #0h                        ; Set part y to 0
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
        cjne A, #0h, hitdet             ; If the result isn't 0, a collision has occurred!
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
        mov R0, 42h                     ; Get the Y value of the current part
        mov A, #30h                     ; Offset that points to the start of the game state array
        add A, R0                       ; Combine them to get a pointer to the row the part is at in the game state array
        mov R0, A
        
        mov R2, #0h                     ; Counter
        mov R1, #60h                    ; Current part start
        copypart2:
            mov A, @R1                  ; Read in current row of current part
            mov R3, 41h                 ; Get the X position of the part for left shifting
            ls2:                        ; Left shift the part into position
                rl A
                djnz R3, ls2
            orl A, @R0                  ; OR the row of the part with the FB row
            mov @R0, A                  ; Copy the row into the game state array
            inc R0                      ; Move onto the next row by increasing all pointers and counters
            inc R1
            inc R2
            cjne R2, #04h, copypart2    ; Loop over all 4 rows of the part
        lcall addpart                   ; Since we baked in a part, we need a new one
    
    updateend:                          ; At the end of each update, check for full rows to eliminate
    
    mov R0, #30h                        ; Pointer to game state array
    mov R2, #10h                        ; Counter set to size of game state array
    clr 42h                             ; No full rows yet
    checkrow:                           ; Loop to check each row
        cjne @R0, #0FFh, notfull        ; Check if the current row is full (every bit set)
        inc P1                          ; If it is, increase the score
        
        mov @R0, #0h                    ; Clear out the row
        mov 3, 0                        ; Stash the current place in the search
        mov 1, 0                        ; Create a pointer to the previous (above) row
        dec R1
        
        moverow:                        ; Loop the brings down each row to fill in the empty row
            mov A, @R1                  ; Pull out the row above
            mov @R0, A                  ; Copy it into the row below
            dec R0                      ; Move up both pointers
            dec R1
            cjne R1, #2Fh, moverow      ; Loop until we have copied the top row into the second from the top
        
        mov 0, 3    
        notfull:                        ; If the row isn't full, continue the search
            inc R0                      ; Check the next row
            djnz R2, checkrow           ; Continue the loop until all rows have been checked
    jb 42h, speedup
    ret
    speedup:                            ; Speeds up the game if any rows have been cleared
        dec 46h                         ; Decreases delay between updates
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

.org 700h                               ; Image data. 16 bytes per image.
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
    .db 0b00110000
    .db 0b00110000
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100100
    .db 0b00100100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100000
    .db 0b00111100
    .db 0b00000100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    
    .db 0b00110000
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100100
    .db 0b00100100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100000
    .db 0b00111100
    .db 0b00000100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00011000
    
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100100
    .db 0b00100100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100000
    .db 0b00111100
    .db 0b00000100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00011000
    .db 0b00011000

    .db 0b00000000
    .db 0b00111100
    .db 0b00100100
    .db 0b00100100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00100000
    .db 0b00111100
    .db 0b00000100
    .db 0b00111100
    .db 0b00000000
    .db 0b00111100
    .db 0b00011000
    .db 0b00011000
    .db 0b00011000


.org 800h                               ; Part data. 7 bytes per part.
parts:
    ; Part 0, L
    .db 0b00000000                      ; Row 0 of image
    .db 0b00000010                      ; Row 1 of image
    .db 0b00000010                      ; Row 2 of image
    .db 0b00000011                      ; Row 3 of image
    .db 0x1                             ; Index of part that results from a clockwise rotation
    .db 0x6                             ; Maximum distance to the left the part can move (number of 0's on the left in the image)
    .db 0x1                             ; Empty space above the part (number of 0's above it in the image)
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
    
