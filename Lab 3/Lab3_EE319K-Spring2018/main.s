;****************** main.s ***************
; Program written by: Isaac Feldman and Mina Gawargious
; Date Created: 2/4/2017
; Last Modified: 2/9/2018
; Brief description of the program
;   The LED toggles at 8 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE0 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
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
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

TotalDelay EQU 20000000
	
	;R2 = duty cycle in percentage from 0 to 100. R3 = frequency in Hertz.

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
 
 ;So, I will use Port E Pins 0 and 1, and Port F pin 4. Since I am not using Port F pin 0, I need not unlock anything.
 
	;Start clocks for ports E and F
	LDR R0, =SYSCTL_RCGCGPIO_R
	LDRB R1, [R0]
	ORR R1, R1, #0x30 ;SYSCTL_RCGCGPIO_R = xxFEDCBA, so to enable E and F, I need to ORR it with 0x30.
	STRB R1, [R0]
	NOP
	NOP
	NOP
	NOP
	
	;If I need to unlock port F, put it here, but since I am using switch 1 and not switch 2 (which is pin 0), I do not think an unlock is necessary.
	
	;Now, I need to digitally enable all the pins I am using.
	
	LDR R0, =GPIO_PORTE_DEN_R 
	LDRB R1, [R0]
	ORR R1, R1, #0x03 ;Digitally enable pins 0 and 1.
	STRB R1, [R0]
	
	LDR R0, =GPIO_PORTF_DEN_R
	LDRB R1, [R0]
	ORR R1, R1, #0x10 ;Digitally enable pin 4.
	STRB R1, [R0]
	
	;Now that the pins I am using are digitally enabled, I also need to set the directions of each of the pins as either input or output.
	
	;PE1 and PF4 are both inputs (0), and PE0 is an output (1). Remember that for some reason, 0 is input and 1 is output.
	
	LDR R0, =GPIO_PORTE_DIR_R
	LDRB R1, [R0]
	ORR R1, R1, #0x01 ;PE0 is an output (1).
	AND R1, R1, #0xFD ;PE1 is input (DIR = 76543210)
	STRB R1, [R0]
	
	;Now Port F
	
	LDR R0, =GPIO_PORTF_DIR_R
	LDRB R1, [R0]
	AND R1, R1, #0xEF ;Set pin 4 to input (0)
	STRB R1, [R0]
	
	;Now, I need to disable alternate funtions.
	
	LDR R0, =GPIO_PORTE_AFSEL_R ;R0 = address of Alternate Function SELect register.
	LDRB R1, [R0]
	AND R1, #0xFC ;Turn off alternate functions for pins 0 and 1 for portE.
	STRB R1, [R0]
	
	;Now to disable Port F's alternate functions.
	
	LDR R0, =GPIO_PORTF_AFSEL_R
	LDRB R1, [R0]
	AND R1, #0xEF ;I am only using pin 4, so I need to disable alternate functions just for pin 4.
	STRB R1, [R0]

	;Now, I need to enable the pull-up resistor for the negative-logic switch in Port F
	
	LDR R0, =GPIO_PORTF_PUR_R
	LDRB R1, [R0]
	ORR R1, #0x10 ;I am using switch 1 on pin 4, so I need to enable its pull-up resistor.
	STRB R1, [R0]
	
	MOV R2, #20 ;LED should start at 20% duty cycle.
	MOV R3, #8 ;Frequency is 8 at first Hz.
	MOV R4, #0 ;The button is not initially pressed.
 
DutyCycle RN 2
Frequency RN 3
 
     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
	 
	 ;What i want: R2 = duty cycle in percentage between 20 and 100. R3 = frequency in Hz. R4 = previous state of button (PE1).
	 
loop  
; main engine goes here

	;Initially turn the LED on.

	BL toggleLED
	
	BL checkSwitchState

	BL Breathe

    B    loop

    ALIGN      ; make sure the end of this section is aligned
	
;________________________________________________________________________________________________________________________________________________________________________

toggleLED ;Subroutine to toggle the LED on or off, according to the duty cycle.	Instead of putting this inside the loop, I put it as its own separate
;subroutine so I can call it for the breathing LED part.

	PUSH {R0, R1, R2, LR}
	
	CMP DutyCycle, #0
	BEQ turnLEDOff ;When R2 = 0, the LED should NEVER turn on.
	
turnLEDOn 

	LDR R0, =GPIO_PORTE_DATA_R
	LDRB R1, [R0]
	ORR R1, R1, #0x01 ;LED output on.
	STRB R1, [R0]
	
	;The number I should count down from is 20000000 (totalDelay) divided by the frequency for the total clock cycles between turning the LED on once and turning it
	;on another time. The tim it is on is then that value multiplied by R2 divided by 100.
	
	LDR R0, =TotalDelay
	UDIV R0, Frequency ;Divide the total delay by the frequency.
	MUL R0, R0, DutyCycle ;Time = (delay/frequency)(dutycycle/100) 
	MOV R1, #100
	UDIV R0, R1 ;The total ON delay is the number of clock cycles for that frequency multiplied by the duty cycle/100 (if R2 = 20, then it is 20/100 = 20% duty cycle).
	BL Delay
	
	;Otherwise, turn LED off.
	
	CMP DutyCycle, #100
	BEQ returnFromToggle ;When duty cycle is 100%, LED should NEVER turn off
	
turnLEDOff LDR R0, =GPIO_PORTE_DATA_R
	LDRB R1, [R0]
	AND R1, R1, #0xFE ;Turn LED Off.
	STRB R1, [R0]
	
	LDR R0, =TotalDelay	
	UDIV R0, Frequency ;Divide total delay by the frequency.
	;The time the LED is on is (100-R2)% of the time.
	MOV R1, #100
	SUB R1, R1, DutyCycle ;Off = 100 - on. R1 = 100 - on = off
	MUL R0, R0, R1
	MOV R1, #100
	UDIV R0, R1 ;Once I get the value off, it's percentage is what I need for the LED to be off. So, 80 corresponds to 0.8, or 80%.
	BL Delay
	
returnFromToggle	POP {R0, R1, R2, LR}
	BX LR

;________________________________________________________________________________________________________________________________________________________________________

Delay ;Subroutine to take what is in R0 as the value I want to count down from.
	PUSH {R0, LR}
subtract	SUBS R0, R0, #1
	BGT subtract ;R0 is a signed number. If it is 0 and I subtract 1 to get 0xFFFFFFFF, I want it to be -1 and break out of the loop.
	POP {R0, LR}
		BX LR

;________________________________________________________________________________________________________________________________________________________________________

checkSwitchState ;Subroutine to check if the switch has been pressed and released. If R4= 0, check switch state to see if it is 1. If it is, the switch has been
;pressed, so change R4 to a 1. If R3 is a 1, check switch state to see if it is a 0. If it is, the switch has been released, so R2 = (R2 + 1)%6, and R4 = 0.

	PUSH {R0, LR}
	LDR R0, =GPIO_PORTE_DATA_R
	LDRB R0, [R0] ;Now, R0 has the data of port E. I am not storing back to the data register here, so I can override R0.
	AND R0, R0, #0x02 ;Preserve only the switch's bit. If this is 0, the switch is not pressed. If it is 1, it is pressed.
	LSR R0, #1

	CMP R4, #0
	BEQ ChangeState ;If R4 = 0, I am not changing the LED's duty cycle since the button has not yet been pushed for it to be released.
	
	;Otherwise, R4 is a 1. If R0 = 0, that means the switch has changes states from 1 (pressed) to 0 (released). Go to the next duty cycle.
	
	CMP R0, #0 ;If R0 = 0 (and here, the previous branch failed, so R3 = 1), the button has been released.
	BEQ buttonReleased
	B ChangeState
	
buttonReleased	ADD DutyCycle, DutyCycle, #20
	CMP DutyCycle, #101 ;R2 is an unsigned value (percentage can't be negative)
	BHS SetDutyCycleTo0 ;There is no modulos operator in ARM, so instead, if R2 + 1 > 100, set it back to 0 since there is no duty cycle greater than 100%.
	BL toggleLED ;Once the button was releassed, toggle the LED on. The toggleLED subroutine saves R0 onto the stack, so when I do MOV R3, R0 later on, it is okay.
	B ChangeState ;So, if R2 = 120, it was previously 100%, so go to 0% (off). Otherwise, toggle the LED and then set R4 back to 0.
	
SetDutyCycleTo0 MOV DutyCycle, #0

;If R3 is 0, the button has not yet been pressed, so all I am doing is checking to see if it has been pressed, then putting 1 into R3 if it has. That is why I did an 
;LSR R0, #1. Since the button is bit 1 in Port E's Data Register, shifting it over 1 to the right means R0 is either 1 or 0. So, all I do is R3 = R0 in this case.

ChangeState MOV R4, R0 ;Now, R4 = R0.
	POP {R0, LR}
	BX LR
	
	;    R4   R0    (change made? 0 = no changes, 1 = duty cycle changed).
	;	 0	   0		0
	;	 0	   1		0  Button was pressed, so change R4 = 1
	;	 1	   0		1  (if the button gets released, change duty cycle, then R4 = 0)
	;	 1	   1		0
	
	;In any case, R4 = R0 at the end. If the button was just pressed (R0 = 1), I want R4 = 1 so I can tell if the button was released. If the button was released (R0 = 0),
	;I want R3 = 0 so I don't change the duty cycle again from just 1 button press. In any case, I will do R3 = R0, but it just so happens that if R4 = R0, this does
	;not change the value of R4. So, ChangeR3 will be executed every time.
	
	ALIGN
				
;________________________________________________________________________________________________________________________________________________________________________

;For the breathing LED, I need to set the frequency to a higher value, such as 80 Hz, and dynamically change the duty cycle.


Breathe
	
	PUSH {R1, R2, R3, LR}
	
	MOV DutyCycle, #0
	MOV Frequency, #80 ;Change frequency to 80 Hz.
	
	MOV R0, #0
	
Direction RN 0

ButtonCheck	LDR R1, =GPIO_PORTF_DATA_R
	LDRB R1, [R1]
	AND R1, R1, #0x10 ;Preserve bit 4. This is a negative logic switch. 0 = closed, 1 = open
	CMP R1, #0	
	BNE doneBreathing ;Value is a 1, meaning the button is not being pressed.
	
	;Otherwise, the button is still being pressed, so change the duty cycle.
	
	CMP Direction, #0
	BEQ ForwardDirection
	
ReverseDirection SUB DutyCycle, #5
	CMP DutyCycle, #0
	BEQ SetDirectionToForwards ;Set the direction for the NEXT time the LED takes a breath.
	B BreatheAtNewDutyCycle
	
ForwardDirection ADD DutyCycle, #5
	CMP DutyCycle, #100
	BEQ SetDirectionToBackwards
	B BreatheAtNewDutyCycle
	
SetDirectionToForwards MOV Direction, #0
	B BreatheAtNewDutyCycle
	
SetDirectionToBackwards MOV Direction, #1
	
BreatheAtNewDutyCycle BL toggleLED

	B ButtonCheck
	
doneBreathing	POP {R1, R2, R3, LR}
	BX LR
	
	ALIGN
	
    END        ; end of file