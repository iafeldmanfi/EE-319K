;****************** main.s ***************
; Program written by: Mina Gawargious and Isaac Feldman
; TA: Austin Harris
; Date Created: 2/4/2017
; Last Modified: 2/12/2018
; Brief description of the program
;   The LED toggles at 8 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  	PE1 is Button input  (1 means pressed, 0 means not pressed)
;   PE0 is LED output (1 activates external LED on protoboard)
;   PF4 is builtin button SW1 on Launchpad (Internal) 
;   	Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE0 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 8Hz,
;      which is 8 times per second with a duty-cycle of 20%.
;      Therefore, the LED is ON for (0.2*1/8)th of a second
;      and OFF for (0.8*1/8)th of a second.
;   3) When the button on (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 20% to 40% to 60%
;      to 80% to 100%(ON) to 0%(Off) to 20% to 40% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 8Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 20%.
;      TIP: debugging the breathing LED algorithm and feel on the simulator is impossible.

; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B ; unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

TotalDelay EQU 20000000 ; the number of delay loops per second in simulation
breatheFrequency EQU 80 ; the frequency at which to breathe
breatheIncrement EQU 5 ; the duty cycle percentage change
Direction RN 0
DutyCycle RN 2
Frequency RN 3

     IMPORT  TExaS_Init
     THUMB
     AREA    DATA, ALIGN=2
;global variables go here

     AREA    |.text|, CODE, READONLY, ALIGN=2
     THUMB
     EXPORT  Start
Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init ; voltmeter, scope on PD3
 ; Initialization goes here
	LDR R0, =SYSCTL_RCGCGPIO_R ; start the clock for PE, PF
	LDR R1, [R0]
	ORR R1, R1, #0x30
	STR R1, [R0]
	NOP
	NOP
	LDR R0, =GPIO_PORTE_DEN_R ; digital enable for PE0, PE1
	LDR R1, [R0]
	ORR R1, R1, #0x3
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_DEN_R ; digital enable for PF4
	LDR R1, [R0]
	ORR R1, R1, #0x10
	STR R1, [R0]
	LDR R0, =GPIO_PORTE_DIR_R ; PE0 is output, PE1 is input
	LDR R1, [R0]
	ORR R1, R1, #0x3
	EOR R1, R1, #0x2
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_DIR_R ; PF4 is input
	LDR R1, [R0]
	AND R1, R1, #0xEF
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_PUR_R ; enable the pull-up resistor for PF4
	LDR R1, [R0]
	ORR R1, R1, #0x10
	STR R1, [R0]
	MOV DutyCycle, #20 ; the duty cycle starts at 20 percent
	MOV Frequency, #8 ; frequency starts at 8 Hz
    CPSIE I ; TExaS voltmeter, scope runs on interrupts	 

loop  
; main engine goes here
	BL toggleLED ; turn the LED ON
	BL checkSwitchState
	BL Breathe
    B loop

toggleLED ; toggles the LED
	PUSH {R0, R1, R2, LR}
	CMP DutyCycle, #0
	BEQ turnLEDOff

turnLEDOn ; turns the LED ON
	LDR R0, =GPIO_PORTE_DATA_R ; set the LED high
	LDR R1, [R0]
	ORR R1, R1, #0x1
	STR R1, [R0]
	LDR R0, =TotalDelay ; find the appropriate count for the ON delay
	UDIV R0, Frequency
	MUL R0, R0, DutyCycle
	MOV R1, #100
	UDIV R0, R1
	BL delay
	CMP DutyCycle, #100 ; when the duty cycle is at 100 percent, do not turn the LED OFF
	BEQ returnFromToggle
	
turnLEDOff LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0] ; set the LED low
	AND R1, R1, #0xFE
	STR R1, [R0]
	LDR R0, =TotalDelay ; find the appropriate count for the OFF delay
	UDIV R0, Frequency
	MOV R1, #100
	SUB R1, R1, DutyCycle
	MUL R0, R0, R1
	MOV R1, #100
	UDIV R0, R1
	BL delay
	
returnFromToggle
	POP {R0, R1, R2, LR}
	BX LR

delay ; delay loop. Keeps the LED high or low for a prescribed period
	PUSH {R0, LR}
subtract	
	SUBS R0, R0, #1
	BGT subtract
	POP {R0, LR}
	BX LR

checkSwitchState ; checks if PE1 has been pressed and released. If R4 = 0x0 and PE1 = 0x1, PE1 has been pressed. If R4 = 0x1 and PE1 = 0x0, PE1 has been released.
	PUSH {R0, LR}
	LDR R0, =GPIO_PORTE_DATA_R ; get PE1 and put it in the least significant bit
	LDR R0, [R0]
	AND R0, R0, #0x2
	LSR R0, #1
	CMP R4, #0x0 ; if R4 = 0x0, move R0 to R4
	BEQ ChangeState
	CMP R0, #0 ; R4 must be a 1. If R0 = 0x0, PE1 has been released
	BEQ buttonReleased
	B ChangeState
	
buttonReleased	
	ADD DutyCycle, DutyCycle, #20
	CMP DutyCycle, #101 ; if DutyCycle is greater than 100, set it to 0
	BHS SetDutyCycleTo0 
	BL toggleLED ; when PE0 is released, toggle the LED
	B ChangeState
	
SetDutyCycleTo0 ; sets the duty cycle to 0 percent
	MOV DutyCycle, #0

ChangeState ; changes the previous state of the switch
	MOV R4, R0
	POP {R0, LR}
	BX LR

Breathe
	PUSH {R1, R2, R3, LR}
	MOV DutyCycle, #0 ; start breathing with a duty cycle of 0 percent
	LDR Frequency, =breatheFrequency ; change the frequency to 80 Hz
	MOV Direction, #0x0

ButtonCheck	
	LDR R1, =GPIO_PORTF_DATA_R ; get PF4 and put it into R1
	LDR R1, [R1]
	AND R1, R1, #0x10
	CMP R1, #0x0 ; if PF4 = 0x1, it is no longer depressed
	BNE doneBreathing
	CMP Direction, #0x0 ; PF4 is still depressed, vary the duty cycle
	BEQ ForwardDirection
	
ReverseDirection ; decrement the duty cycle by 5 percent
	SUB DutyCycle, #breatheIncrement
	CMP DutyCycle, #0 ; if the duty cycle is at 0 percent, set the direction to forwards
	BEQ SetDirectionToForwards
	B BreatheAtNewDutyCycle
	
ForwardDirection ; increment the duty cycle by 5 percent
	ADD DutyCycle, #breatheIncrement
	CMP DutyCycle, #100 ; if the duty cycle is at 100 percent, set the direction to backwards
	BEQ SetDirectionToBackwards
	B BreatheAtNewDutyCycle
	
SetDirectionToForwards ; changes Direction to forwards 
	LDR R0, =5000000
	BL DELAY
	MOV Direction, #0x0
	B BreatheAtNewDutyCycle
	
SetDirectionToBackwards ; changes Direction to backwards
	MOV Direction, #0x1
	
BreatheAtNewDutyCycle ; operate at a new duty cycle
	BL toggleLED
	B ButtonCheck
	
doneBreathing ; stops the breathing subroutines
	POP {R1, R2, R3, LR}
	BX LR
	
    ALIGN      ; make sure the end of this section is aligned
    END        ; end of file