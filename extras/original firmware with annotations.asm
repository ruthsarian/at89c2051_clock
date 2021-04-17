; AS31 Conversion Notes
;	- EQU, DB, ORG need periods infront of them
;	- EQU order is different than original source
;	- CALL needs to be changed to ACALL
;	- references to individual bits based on byte position need parentheses removed (20H).1 becomes 20H.1
;
;	Fails to compile. 
;	Missing symbols: 
;		- CLOCK			: A routine that keeps time, updating HOUR (22H), MINUTE (23H), and SECOND (24H) values
;						  This is the Timer0 ISR
;						  Is executed once every 50ms
;						  Every 20 executions of CLOCK = 1 second
;		- BCDCH			: A routine that converts the current HOUR, MINUTE, and SECOND values into BCD values
;						  TWO bytes per time element -- One byte for TENS position, second byte for ONES position
;						  HOUR stored in 30H (TENS) and 31H (ONES)
;						  MINUTE stored in 32H (TENS) and 33H (ONES)
;						  SECOND stored in 34H (TENS) and 35H (MINUTES)
;		- DELAY			: A delay routine to hold a single digit active during the multiplexed rendering of the display
;		- DELAY1		: ?? (another delay routine?)
;		- DEL			: ?? (another delay routine?)
;
;
;	LATCHES
;	To read input on a pin, set the latch to 1 
;		MOV P1.1,#01H
;	Now read from the pin
;		MOV A, P1
;
;	ORL will use the latch, not read the pin. So if you want to ORL input
;	you need to first copy (via MOV instructino) the pin to a register
;
;
;	The code below
;	Input: 3 bytes stored at 22H, 21H and 20H
;	Output: 6 bytes stored at 23H, 24H, 25H, 26H, 27H
;
;	Process 3 numbers stored at 22H, 21H, and 20H (in that order, via the DEC R0)
;	Each number is divied by 10
;   Quotient and Remainder stored in separate BYTE values
;
;	This code takes the hours, minutes, and seconds and separates them into tens and ones place
;	so they can then be used to display each digit.
;
;	BCDCH:
;		MOV R0,#22H			; load memory address 22H into R0 (INPUT)
;		MOV R1,#23H			; load memory address 23H into R1 (OUTPUT)
;		MOV R3,#3			; counter
;	BCDCH1:
;		MOV A,@R0			; move value stored at memory address pointed to R0 into reigster A
;		MOV B,#10			; move literal "10" into register B
;		DIV AB				; divide value of A by 10 (separating 10s and 1s???)
							; quotient placed in A, remainder placed in B
;		MOV @R1,A			; copy quotient to location in memory pointed to by R1 (23H)
;		INC R1
;		MOV @R1,B			; copy remainder to location in memory pointed to by R1 (24H)
;		INC R1
;		DEC R0
;		DJNZ R3,BCDCH1
;		RET
;
;
; Looks like registers R0 - R3 are open/free to use for stuff
;
; RAM MEMORY ALLOCATION
; -----------------------------
; 0x00 - 0x07 = Register Bank 0
; 0x08 - 0x0F = Register Bank 1
; 0x10 - 0x17 = Register Bank 2
; 0x18 - 0x1F = Register Bank 3
; 0x20 - 0x2F = Bit-Addressable RAM (meaning operations that work on BITs and not BYTEs can refer to individual bits in this area with the values 0x00 - 0x7f)
; 0x30 - 0x7F = Scratch Pad RAM
;
; 0x20 - 0x2F = 16 bytes of bit-addressable RAM
; This area is also addressible as the BIT position values of 0x00 - 0x7f (
;
; SETB (20H).0 
;	is the same as
; SETB 00H
;
; In this code, the first 10 bits are of bit-addressable space is being used for flags
;
; I don't see ANYWHERE in this code where these defines are being reference
.EQU HOUR,22H	;时 Bit addressible byte 0x22 will store value for HOURS
.EQU  MIN,23H	;分 Bit addressible byte 0x23 will store value for MINUTES
.EQU  SEC,24H	;秒 Bit addressible byte 0x22 will store value for SECONDS
;
;20H:标志位									; "flag positions"
;	(20H).0:半秒到标志						; "half second to sign"				-- ?? a flag that does not appear to be set anywhere in the code
;																				-- may be a means to blank the entire display
;	(20H).1:当前第一位闪						; "the current first flash"			-- currently modifying digit 1
;	(20H).2:当前第二位闪						; "the current second flash"		-- currently modifying digit 2
;	(20H).3:当前第三位闪						; "the current third flash"			-- currently modifying digit 3
;	(20H).4:当前第四位闪						; "the current fourth flash"		-- currently modifying digit 4
;	(20H).5:校时标志							; "school hour marker"				-- clock is in set time mode
;	(20H).6:校闹时标志						; "flag at school"					-- clock is in set alarm mode
;	(20H).7:打闹标志							; "slapstick sign"					-- appears to be the alarm flag; when set the alarm is sounding
;
;21H:标志位									; "flag positions"
;	(21H).0:修改校时或闹时参数				; "Modify the time or alarm parameters"
;																				-- currently modifying either the time or the alarm
;	(21H).1:闹时结束							; "End of trouble"					-- end of alarm flag, set when the alarm has been active for 1 minute
;   (21H).2									;									-- a flag set when the user ends the alarm early by pressing a button
;
;2AH:时 暂存单元								; "temporary storage"				-- temporary storage for the HOUR; used ONLY in BKEY routine
;2BH:分 暂存单元								; "separation"						-- temporary storage for the MINUTE; used ONLY in BKEY routine
;3AH:闹时时存贮单元							; "memory unit at time of trouble"	-- this is the HOUR of the alarm
;3BH:闹时分存贮单元							; "alarm memory unit"				-- this is the MINUTE of the alarm
;30H--35H:时,分,秒单个BCD码存贮单元			; "hour, minute, second single BCD code storage unit"
;																				-- one byte per digit for the tens and ones position for HOUR, MINUTE, and SECOND (6 bytes total); used when rendering the display
;***********************************
;主程序										; "Main program"
;************************************
;显示时间,有键按下则处理按键,如果需要闹时闹时时间至则闹时一分钟
											; "Display time, press the key to deal with the button, if you need to make trouble when the time is up to the time of a minute"

.ORG 0000H
AJMP LOOP0				; This is setting the address location for the start of the program
						; LOOP0 label marks the start
.ORG 000BH
AJMP CLOCK				;走时定时
						; This is setting the ISR for Timer0
						; Timer0 ISR starts at the CLOCK label
						;
						; -- MISSING! -- This routine is missing from this code.
						; Looks like this routine does the actual timekeeping. Values for the current HOUR, MINUTE, and SECOND
						; stored at 22H, 23H, and 24H respectively, as denoted by the EQU statements at the start of the code
						;
						; This routine must update these values
.ORG 001BH
AJMP CLOCK1M			;打闹一分钟定时
						; This is setting the ISR for Timer0
						; Timer1 ISR starts at the CLOCK1M label
LOOP0: 
	ACALL ORG1			;初始化
						; calling the initialization routine which begins at label ORG1
LOOP1:					; main() {
	ACALL DISPLAY1		;调显示程序
						; Call the routine to draw the display
	JB P3.4,LOP1		;A键按了吗?
						; test if button 1 is pressed
						; a press would indicate a LOW value on P3.4
						; if value is HIGH then no button press, skip to LOP1
	ACALL AKEY			; if pressed, go to the AKEY routine
LOP1: 
	JB P3.5,LOP2		;B键按了吗?
						; test if button 2 is pressed
	ACALL BKEY			; if pressed go to the BKEY routine
LOP2:
;	JB 21H.0,LOOP1		;正在修改参数,不闹时
	JNB 20H.7,LOP3		;有打闹标志吗?没转
						; Jump to LOP3 if flag at 20H.7 is not set
						; this is the 'slapstick' flag, aka the alarm is active flag
	JNB 21H.1,LOOP1		;停闹时吗？
						; If the flag at 21H.1 ('end of trouble') is NOT set, go back to start of main loop (LOOP1)
	CLR TR1				; disable Timer1
						; if we get here then the alarm should be stopped
	SETB P3.7			; 
	CLR 20H.7			; disable the active alarm flag
	CLR 21H.1			; clear the deactivate alarm flag
	CLR 21H.2			; 
	SETB P3.7			; disable buzzer (buzzer is on PNP; is active when pin goes low)
	SJMP LOOP1			; go back to start of main()
LOP3: 					; Test whether or not it's time to sound the alarm
	MOV A,22H			;闹时时间到吗?
						; load contents at 22H (HOUR) into A
	XRL A,3AH			;3AH,3BH比22H,23H
						; XOR the HOUR with the value at 3AH
	JNZ LOOP1			; if value at 3AH and HOUR are not equal, go back to start of main()
						; this looks like it's testing for the alarm
	MOV A,23H
	XRL A,3BH			; test value of MINUTE against value at 3BH
	JNZ LOOP1
	SETB 20H.7			;到了,置闹时标志
						; If we get here then the ALARM has triggered, set flag at 20H.7
;	CLR P3.7			;闹时输出
						; This would have enabled the buzzer
						; this is now handled elsewhere based on the flag at 20H.7 ?
						; possibly the CLOCK1M routine
	CLR 21H.2			; clear the bit at 21H.2
	SETB TR1			; Enable Timer1
	SJMP LOOP1			; } // main()

;************************************
;显示程序									; "show program"
;**********************************
;(20H).0:半秒到标志							; "half second to sign"
;当参数修改时,显示须产生位闪,闪动与秒闪同步,非参数修改时,位不闪,直接显示
											; "When the parameter is modified, the display must generate a bit flash, 
											; flashing and second flash synchronization, non-parameter modification, the bit does not flash, direct display"
;P3.0-P3.3:时分位控,0位显示,1位不显示			; "Time-division position control, 0-bit display, 1 bit is not displayed"
DISPLAY1:
	ACALL BCDCH				; This routine is missing
							;
							; Probably a routine to read the current time and convert them to 
							; individual bytes used to set LED segments
							;
							; These individual bytes setting LED segments for each digit are stored
							; at 0x30 - 0x33
							;
							; Memory space that's been 'reserved' for 
							;
							; Possibly a routine to prepare whatever content is to be displayed
							; such as time (HH:MM), date, seconds, etc.
	JNB 20H.1,BIT1			;jump BIT1
	JNB 20H.0,BIT1			;jump BIT1
							; the above jumps happen unless 20H.0 or 20H.1 are set
							; nothing in the code sets 20H.0, but 20H.1 is set when modifying the date/time
	SETB P3.3				; turn off digit 4 (was it left on?)
	SJMP BIT2				; jump to BIT2 (digit 2)
							; this only happens when 20H.1 or 20H.0 are NOT set
BIT1: 
	MOV A,30H				; memory address where either the 10s hour or 1s second position is located
;	SWAP A
;	ANL P1,#01H
	MOV DPTR,#TAB_LED		; move address of TAB_LED into (16-bit) data pointer register
	MOVC A,@A+DPTR			; copy the byte value to enable the correct LED segments from the TAB_LED; e.g. A = TAB_LED[A]
	MOV P1,A				; move the value in A to Port1 register
	ORL P1,A				; P1 is LOGICAL OR'd against A and result stored in P1
							;   ... why? a delay of some sort?
							; 
	SETB P3.3				; P3.3 = 1; doesn't this DISABLE the digit thought????
							; This instruction probably belongs before setting the P1

	CLR P3.0				; Turn on digit 1 (TENS-HOURS position)
	ACALL DELAY				; call some delay function
							; doesn't look like any delay value is being passed
	JNB 20H.2,BIT2
	JNB 20H.0,BIT2
	SETB P3.0				; turn off digit 1
	SJMP BIT3				; Jump to 'BIT3'
							; why do we need to skip bit2? 
							; only happens when 20H.2 or 20H.0 are NOT set
							;
							; looks like the 20H.1 - 20H.4 bits are there to control flashing individual digits
							;
							; 20H.0 seems to be disabling the entire display
							;       is this to blink the entire display instead of an individual digit???
BIT2: 
	MOV A,31H
;	SWAP A
;	ANL P1,#01H
	MOV DPTR,#TAB_LED
	MOVC A,@A+DPTR
	MOV P1,A
	ORL P1,A
	SETB P3.0

	CLR P3.1
	ACALL DELAY
	JNB 20H.3,BIT3
	JNB 20H.0,BIT3
	SETB P3.1
	SJMP BIT4
BIT3: 
	MOV A,32H
;	SWAP A
;	ANL P1,#01H
	MOV DPTR,#TAB_LED
	MOVC A,@A+DPTR
	MOV P1,A
	ORL P1,A
	SETB P3.1

	CLR P3.2
	ACALL DELAY
	JNB 20H.4,BIT4
	JNB 20H.0,BIT4
	SETB P3.2
	SJMP SEC1
BIT4: 
	MOV A,33H
;	SWAP A
;	ANL P1,#01H
	MOV DPTR,#TAB_LED
	MOVC A,@A+DPTR
	MOV P1,A
	ORL P1,A
	SETB P3.2

	CLR P3.3
	ACALL DELAY
	SETB P3.3
;	SJMP BIT2

SEC1: 
	JB 20H.5,DD0		;校时修改秒显常亮
						; what is the purpose of this jump? 
						; 20H.5 and 20H.6 should never be set at the same time
						; perhaps to jump over moment when 20H.0 is enabled?
	JB 20H.6,DD1		;闹时修改秒显不亮
	JB 20H.0,DD1		;走时闪
DD0: 
	MOV A,#0AH			; load literal 10 into A
;	ANL P1,#01H
	MOV DPTR,#TAB_LED	
	MOVC A,@A+DPTR		; load byte at LED_TAB[10] into A
	MOV P1,A			; copy A to P1
	ORL P1,A
;	ACALL DELAY1
;	ACALL DELAY
	RET					; RET without enabling any digit pins?
						; perhaps DELAY1 should be doing something with digits ??
						; but, essentially, 
DD1: 
	SETB P1.0			; This is just enabling the DP pin
						; whereas DD0 is setting the ENTIRE digit
						; but no digit is being enabled and the next time a pin is enabled
						; P1 will be overwritten
						;
						; This will happen when 20H.6 or 20H.0 are set
	RET

;********************************
;初始化程序 ("Initialization procedure")
;******************************

ORG1: 
	MOV 20H,#00H												; Initializing the byte at 20H (being used as 8 1-bit flags) to all 0s
	MOV 21H,#00H												; Initializing the byte at 21H (the first two bits of which are being used as 1-bit flags) to all 0s
	MOV 22H,#12H		;置走时初值	("Set the initial value")	; Sets the HOUR to 0x12 (6pm??)
	MOV 23H,#00H												; Sets the MINUTE value to 0x00
	MOV 24H,#00H												; Sets the SECOND value to 0x00, Why is the DEFINE not being used here? Hmmm
	MOV 25H,#03H												; Initializing a byte value being used by the Timer1 ISR
	MOV 3AH,#06H		;置闹时初值
	MOV 3BH,#01H
	MOV TMOD,#11H		; set both Timer0 and Timer1 to mode 1 (16-bit, no prescaler)
	MOV TH0,#3CH		
	MOV TL0,#0B5H		;加了5uS
						; counter for Timer0 is starting at 15541 and overflows/triggers at 65536, a difference of 49995
						; ~50 milliseconds per trigger
						; Why not 0x3CAF which would be a perfect 50ms? 
						; The comment says "added 5 micro seconds" which is what's happening here.
						; TL0 probably was AF at one point, but for some reason they found the need for an additional 5 microseconds 
						; The "addition" is actually a SUBTRACTION, so this routine executes every 49.995ms instead of every 50ms. 
						; Those 5 extra machine cycles are probably to make up for losses calling the ISR, perhaps because the ISR has a LOW priority
	MOV TL1,#0CAH
	MOV TH1,#0FEH		; 65226 loaded into Timer1
						; 310 machine cycles per execution of Timer1
	MOV R4,#255			; initialize R4 to a value of 255
						; this is used in the CLOCK1M/Timer1 ISR routine
	MOV R5,#255			; initialize R5 to a value of 255
						; this is used in the CLOCK1M/Timer1 ISR routine
	MOV R6,#20			;一秒当量	("One second equivalent")
						; initialize R6 to a value of 20
						; Must be used in one of the missing routines; possibly a delay routine???
						; Of course it is. Timer 0 execute every 50ms.
						; 50ms * 20 = 1000ms or 1 second. So the CLOCK routine must
						; decrement R6 and when it reaches zero, increment the seconds (and minute, and hours as needed) values
	SETB EA				; enable global interrupts
	SETB ET0			; enable Timer0 interrupt
	SETB TR0			; enable Timer0
	SETB ET1			; enable Timer1 interrupt
						; Timer1 is not being enabled here
						; Looks like Timer1 is for running the buzzer for 60 seconds
	SETB PT0			; set Timer0 priority bit to HIGH priority
	RET
						; ISR for Timer0 vector address is 0x000B
						; ISR for Timer1 vector address is 0x001B

;***************************
; Timer0 ISR -- Time Keeping
;***************************
CLOCK:
	MOV TH0,#3CH		
	MOV TL0,#0B5H			; reset Timer0 counter
	DJNZ R6,CLOCKEND		; if a second has not yet passed, exit ISR

	MOV R6,#20				; reset counter to next second
	INC 24H					; increment SECONDS by 1
	MOV A,#60				; 
	CJNE A,24H,CLOCKEND		; compare SECONDS to number 60 and if not equal exit ISR

	MOV 24H,#0				; reset SECONDS to zero
	INC 23H					; increment MINUTES by 1
	MOV A,#60				; (is this necessary? i think A still has 60 from the SECONDS operation)
	CJNE A,23H,CLOCKEND		; compare MINUTES to number 60 and if not equal exit ISR
	
	MOV 23H,#0				; reset MINUTES to zero
	INC 22H					; increment HOURS by 1
	MOV A,#24				;
	CJNE A,22H,CLOCKEND		; compare HOURS to number 24 and if not equal exit ISR
	
	MOV 22H,#0				; set HOURS to zero

CLOCKEND:
	RETI					; exit ISR

;***************************
; Separate time values to separate TENS and ONES values
;***************************
;      TEN ONE
; HOUR 30H 31H     HOUR stored at 22H
;  MIN 32H 33H      MIN stored at 23H
;  SEC 34H 35H      SEC stored at 24H
BCDCH:
	MOV R0,#22H			; pointer to HOUR in memory (INPUT)
	MOV R1,#30H			; pointer to TENS HOUR in memory (OUTPUT)
	MOV R3,#3			; counter -- do this loop 3 times
BCDCH1:
	MOV A,@R0			; move value at address pointed to by R0 into A
	MOV B,#10			; move literal 10 into B
	DIV AB				; divide
	MOV @R1,A			; move TENS value to @R1
	INC R1				; increment R1 so it points to the next address
	MOV @R1,B			; move the ONES value to @R1
	INC R1
	INC R0				; move to next time element value
	DJNZ R3, BCDCH1		; step to next loop
	RET

;***************************
; Delay Routines
; see: http://www.circuitstoday.com/software-delay-routine-in-8051
;***************************
; DJNZ routine = 2 machine cycles; 1 machine cycle = 1microsecond
; DELAY = 500 calls to DJNZ = 1ms
; DELAY1 = 4 * 250 calls to DELAY producting a 1 second delay
DELAY1:
	MOV R2,#250D
DELAY1L:
	ACALL DELAY 
	ACALL DELAY
	ACALL DELAY
	ACALL DELAY
	DJNZ R2, DELAY1L
	RET
DELAY:
	MOV R0,#250D
	MOV R1,#250D
DELAYL1:
	DJNZ R0, DELAYL1
DELAYL2:
	DJNZ R1, DELAYL2
	RET

DEL:					; this routine is only called after a button has been pressed. i think it's a short pause to help with debounce
	MOV R0,#50D
DELL1:
	DJNZ R0,DELL1
	RET

;***************************
;中断程序1				;("Interrupt program 1")	This is Timer1 ISR
;***************************
;打闹一分钟定时			; "Rush for a minute"
;(21H).1:一分时间到标志	; "One minute to sign"

CLOCK1M:
	MOV TL1,#0CAH
	MOV TH1,#0FEH		; (Re)Set T1 counter to 65226; 310 from overflow
						; this timer is executing every 310 machine cycles (~310 microseconds)
	JB 21H.2,CK2M		;停闹时吗？
						; jump if bit 21H.2 is set
	CPL P3.7			; invert bit P3.7, the buzzer pin

CK2M:
	DJNZ R5,CK1M		; Decrement R5 by 1
						; If not 0, go to CK1M (exit routine)
	MOV R5,#255			;一分钟常量
						; Reset R5 to 255 (0xFF)
	DJNZ R4,CK1M		; Decrement R4
						; If not zero, go to CK1M (exit routine)
	DJNZ 25H,CK1M		; Decrement value at 25H
						; If not zero, exit routine
	MOV 25H,#03H		;一分钟常量
						; reset value at 25H to 3
	SETB 21H.1			; enable bit 21H.1
						; this bit signifies "end of trouble" ???
						; "trouble" = alarm
						;
						; 255 * 255 * 3 = 195,075 loops
						; but this loop only runs once every 310 machine cycles so ... 
						; 60473250 machine cycles per SETB call
						; OR ... 60 (ish) seconds!				
						; 1 machine cycle = 12 clock cycles. clock is 12,000,000 cycles per second					
						; 1,000,000 machine cycles per second
						; 60,473,250 / 1,000,000 = 60(.47325) seconds!
						;
						; what clears flag 21H.1 ??
						; a KEY press
						; This feels like a possible alarm that buzzes for 1 minute before .. turning off???
						; but if the button is pressed (setting bit 21H.1) then the alarm turns off early???
CK1M: 
	RETI				; exit ISR

;*******************************
;A键处理程序			; AKEY is S1 (P3.4), the LEFT switch
;					; S1 press will turn off the alarm if it is active
;					; S1 press will navigate through the digits to modify them
;****************************
;作用:修改参数时移位
AKEY: 
	JNB P3.4,AKEY	;去抖	"debounce"
					; this creates a loop until the button is released
	ACALL DEL		; call some delay routine (i assume)
					; not sure of its purpose, maybe to help with debouncing on the button release?
	JB 20H.5,BB1	;修改校时转	"modify the school hours"	; probably the set time flag
	JB 20H.6,BB1	;修改闹时转	"change the time"			; probably the set alarm flag
					; if either of these flags are set (appear to be related to setting the alarm or time)
					; then jump to BB1
					;
					; next set of instructions stop the alarm
					; would be executed even if the alarm is not sounding, but would also
					; have no impact (I think)
;	CLR TR1			; would have stopped ISR1, but commented out
	SETB P3.7		; stop the buzzer (i don't think this is necessary as the later SETB P3.7 instruction does the same thing)
	CLR 21H.1		; reset the "end of alarm" flag
	SETB 21H.2		; essentially disabling the buzzer
	SETB P3.7		;止闹
					; stop the buzzer
	RET
BB1: 				; state machine keeping track of which of the 4 digits is currently in a state to be modified
	SETB 21H.0		;置校闹时修改标志
					; flag that the clock is currently in modify mode
	JB 20H.1,BB2	;第一位闪转
					; with each button press advance to the next digit
	JB 20H.2,BB3	;第二位闪转
	JB 20H.3,BB4	;第三位闪转
	JB 20H.4,BC1	;第四位闪转
	SETB 20H.1		;置第一位闪
	RET
BC1: 				; after all 4 digits are touched, clear all the flags and return to normal state
	CLR 20H.4		;清第四位修改标志
	CLR 21H.0
	CLR 20H.5
	CLR 20H.6
	RET
BB2: 				; modify digit 2
	CLR 20H.1		;置第二位闪标志
	SETB 20H.2
	RET
BB3: 				; modifity digit 3
	CLR 20H.2		;置第三位闪标志
	SETB 20H.3
	RET
BB4: 				; modify digit 4
	CLR 20H.3		; 置第四位闪标志
	SETB 20H.4
	RET

;************************************
;B键处理程序			; BKEY is S2 (P3.5), the RIGHT buttom
;					; S2 press puts clock into change time mode
;					;
;***********************************
;作用:校时闹时走时转换,参数修改
;作参数修改时,必须先按A键,出现位闪动
BKEY: 
	JNB P3.5,BKEY	; 去抖	"debounce"
	ACALL DEL

	JNB 21H.0,BKEY1	; 无修改标志转
	ACALL MODY
	RET
BKEY1: 
	JB 20H.5,BKEY2	; 是校时参数修改转
	JB 20H.6,BKEY3

	; 是闹时参数修改转
	SETB 20H.5
	RET
BKEY2: 
	SETB 20H.6
	CLR 20H.5
	RET
BKEY3: 
	CLR 20H.6
	RET

MODY: 
	JB 20H.1,BK1	;第一位修改转
	JB 20H.2,BK2	;第二位修改转
	JB 20H.3,BK3	;第三位修改转
	MOV A,33H		; 第四位修改
	MOV R7,A
	ACALL MOD09
	MOV 33H,R7
BK0:
	NOP				; NOP? why? perhaps waiting for some value to make it into a register?
	MOV A, 30H		; 修改值置缓冲区
					; move the TENS hour value into A
	SWAP A			; swap nibbles (0x01 becomes 0x10)
	ORL A,31H		; OR value of A with ONES hour value, result is stored in A (tens and ones places of HOUR are merged into a single value)
	MOV 2AH,A		; HOURS value in A stored at 2AH in memory (a temporary memory location?)
	MOV A,32H		; do same as above for MINUTES
	SWAP A
	ORL A,33H
	MOV 2BH,A		; store MINUTES value at 2BH
	JB 20H.5,BK
	JB 20H.6,BK4
	RET
BK: 
	MOV HOUR,2AH
	MOV MIN, 2BH
	RET
BK4:
	MOV 3AH,2AH
	MOV 3BH,2BH
	RET
BK1:
	MOV A, 30H 		; 第一位修改
	MOV R7,A		; looks like MOD09/NN1 could be used instead here
	XRL A,#09H		; like other BKn routines
	JNZ KK1
	MOV 30H,#00H
	SJMP BK0
KK1: 
	INC R7
	MOV 30H,R7
	SJMP BK0
BK2: 
	MOV A,31H		; 第二位修改
	MOV R7,A
	ACALL MOD09
	MOV 31H,R7
	SJMP BK0
BK3: 
	MOV A,32H		; 第三位修改
	MOV R7,A
	XRL A,#06H
	JNZ MM1
	MOV 32H,#00H
	SJMP BK0
MM1: 
	INC R7
	MOV 32H,R7
	SJMP BK0

MOD09:
	XRL A,#09H		;数字0-9变化
	JNZ NN1
	MOV R7,#00H
	RET
NN1:
	INC R7
	RET
TAB_LED: 
	.DB 0FDH,25H,0BBH,0AFH,67H,0CFH,0DFH	;共阴字码表
	.DB 0A5H,0FFH,0EFH,0FEH

	; TAB_LED contains the pin configurations needed to genera
	; characters on the 7-segment LED displays
	;
	; SEGMENT DIAGRAM
	;
	;  -a-
	; |f  |b
	;  -g- 
	; |e  |c
	;  -d-   -dp
	;
	; 1 = on, 0 = off (except, perhaps, for dp???)
	;
	; a, f, b, e, d, c, g, dp
	;
	; TAB_LED contents
	; ----------------
	; 0xFD = 11111101 = 0
	; 0x25 = 00100101 = 1
	; 0xBB = 10111011 = 2
	; 0xAF = 10101111 = 3
	; 0x67 = 01100111 = 4
	; 0xCF = 11001111 = 5
	; 0xDF = 11011111 = 6
	; 0xA5 = 10100101 = 7
	; 0xFF = 11111111 = 8
	; 0xEF = 11101111 = 9
	; 0xFE = 11111110 = <disable/enable dp???>

.END
