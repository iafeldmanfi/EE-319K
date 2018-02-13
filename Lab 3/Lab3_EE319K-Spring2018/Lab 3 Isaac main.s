;****************** main.s ***************
; Program written by: ***Your Names**update this***
; Date Created: 2/4/2017
; Last Modified: 1/15/2018
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

fullCount EQU 20000000 ; the number of delay loops for 1 second

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
	 LDR R0, =GPIO_PORTE_DATA_R ; the LED (PE0) starts off
	 LDR R1, [R0]
	 AND R1, R1, #0x7
	 MOV R12, #100 ; R12 should be considered a constant
	 BL reset
     CPSIE  I    				; TExaS voltmeter, scope runs on interrupts
loop ; main engine goes here
	 BL checkButtonPressed
     B loop
reset ; resets the frequency, duty cycle percentage, and counts
	 PUSH {R0, LR}
	 MOV R11, #8 ; R11 is the frequency register, initialized to 8 Hz
	 MOV R10, #20 ; R10 is duty cycle percentage
	 BL getCount ; get the initial delay counts
	 POP {R0, LR}
	 BX LR
toggleLED ; toggles the LED ON/OFF
	 PUSH {R0, LR}
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R1, [R0]
	 EOR R1, R1, #0x1
	 STR R1, [R0]
	 POP {R0, LR}
	 BX LR
checkButtonPressed ; checks if PE1 has been pressed
	 PUSH {R0, LR}
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R0, [R0]
	 AND R0, R0, #0x2
	 CMP R0, #0x2
	 BEQ checkButtonReleased
pressedCycle ; checks the status of the duty cycle and runs one cycle
	 ;CMP R10, #0 ; if the duty cycle is at 0 percent
	 ;BEQ ifDuty0
	 CMP R10, #100
	 BEQ ifDuty100 ; if the duty cycle is at 100 percent
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R0, [R0]
	 AND R0, R0, #0x1
	 BL delayController
	 BL toggleLED
	 POP {R0, LR}
	 BX LR
checkButtonReleased
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R0, [R0]
	 AND R0, R0, #0x2
	 CMP R0, #0x2
	 BNE changeDuty
releasedCycle ; runs the duty cycle for PE1 high
	 ;CMP R10, #0 ; if the duty cycle is at 0 percent
	 ;BEQ ifDuty0
	 CMP R10, #100
	 BEQ ifDuty100 ; if the duty cycle is at 100 percent
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R0, [R0]
	 AND R0, R0, #0x1
	 BL delayController
	 BL toggleLED
	 B checkButtonReleased
changeDuty ; increases the duty cycle by 20 percent. Loops back to 0 percent after 100 percent
	 ADD R10, R10, #20
	 BL getCount
	 CMP R10, #120
	 BEQ flipDuty
	 POP {R0, LR}
	 BX LR
flipDuty
	 MOV R10, #0
	 BL getCount
	 POP {R0, LR}
	 BX LR
;ifDuty0 ; if the duty cycle is 0, make the LED continually OFF
	 ;LDR R0, =GPIO_PORTE_DATA_R
	 ;LDR R1, [R0]
	 ;AND R1, R1, #0x7
	 ;STR R1, [R0]
	 ;B loop
ifDuty100 ; if the duty cycle is 100; make the LED continually ON
	 LDR R0, =GPIO_PORTE_DATA_R
	 LDR R1, [R0]
	 ORR R1, R1, #0x1
	 STR R1, [R0]
	 BL delayON
getCount ; calculates the current counts and puts them into the appropriate registers
	 PUSH {R0, LR}
	 LDR R8, =fullCount ; R8 is the count for when the LED is currently ON
	 UDIV R8, R8, R11
	 MUL R8, R8, R10
	 UDIV R8, R8, R12
	 LDR R7, =fullCount ; R7 is the count for when the LED is currently OFF
	 UDIV R7, R7, R11
	 SUB R7, R7, R8
	 POP {R0, LR}
	 BX LR
delayController ; determines the type of delay depending on the LED's status
	 PUSH {R0, LR}
	 CMP R0, #0x1
	 BEQ delayON
	 BNE delayOFF
delayON ; if the LED is currently ON
	 MOV R0, R8
	 B dloop
delayOFF ; if the LED is currently OFF
	 MOV R0, R7
	 B dloop
dloop
	 SUBS R0, #1
	 BNE dloop
	 POP {R0, LR}
	 BX LR
	 
     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

