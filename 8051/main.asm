.org 000h
	ljmp start
	
.org 100h
start:
	loop:                       ; Main loop
        lcall wait
		sjmp loop
	
wait:
	mov R0, #0FFh
	delay:
		djnz R0, delay
	ret
	