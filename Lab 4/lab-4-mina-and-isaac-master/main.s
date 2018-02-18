;****************** main.s ***************
; Program written by: Isaac Feldman and Mina Gawargious
; Date Created: 2/14/2017
; Last Modified: 2/15/2018
; Brief description of the program
;   The LED toggles at 8 Hz and a varying duty-cycle
;   Repeat the functionality from Lab3 but now we want you to 
;   insert debugging instruments which gather data (state and timing)
;   to verify that the system is functioning as expected.
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE0 is LED output (1 activates external LED on protoboard)
;  PF2 is Blue LED on Launchpad used as a heartbeat
; You will only verify the variable duty-cycle feature of Lab 3 and not the "breathing" feature. 
; Instrumentation data to be gathered is as follows:
; After Button(PE1) press collect one state and time entry. 
; After Buttin(PE1) release, collect 7 state and
; time entries on each change in state of the LED(PE0): 
; An entry is one 8-bit entry in the Data Buffer and one 
; 32-bit entry in the Time Buffer
;  The Data Buffer entry (byte) content has:
;    Lower nibble is state of LED (PE0)
;    Higher nibble is state of Button (PE1)
;  The Time Buffer entry (32-bit) has:
;    24-bit value of the SysTick's Current register (NVIC_ST_CURRENT_R)
; Note: The size of both buffers is 50 entries. Once you fill these
;       entries you should stop collecting data
; The heartbeat is an indicator of the running of the program. 
; On each iteration of the main loop of your program toggle the 
; LED to indicate that your code(system) is live (not stuck or dead).

GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C

GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B
SYSCTL_RCGCGPIO_R  EQU 0x400FE608


; RAM Area

           AREA    DATA, ALIGN=2
;-UUU-Declare  and allocate space for your Buffers 
;and any variables (like pointers and counters) here

; ROM Area
       IMPORT  TExaS_Init
;-UUU-Import routine(s) from other assembly files (like SysTick.s) here
       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB
       EXPORT  Start


Start
 ; TExaS_Init sets bus clock at 80 MHz
      BL  TExaS_Init ; voltmeter, scope on PD3
 ;place your initializations here
 
 ;PE1 is Button input, PE0 is LED output, PF2 is Blue LED on Launchpad used as a heartbeat
 
	LDR R0, =SYSCTL_RCGCGPIO_R
	LDRB R1, [R0]
	ORR R1, #0x30 ;Enable ports E and F.
	STRB R1, [R0]
	NOP
	NOP
	NOP
	NOP
	
	LDR R0, = GPIO_PORTF_LOCK_R
	LDR R1, = GPIO_LOCK_KEY
	STR R1, [R0]
	
	LDR R0, =GPIO_PORTF_CR_R
	LDRB R1, [R0]
	ORR R1, #0x1F
	STRB R1, [R0]
	
	LDR R0, =GPIO_PORTE_DIR_R
	LDRB R1, [R0]
	ORR R1, #0x01 ;PE0 is LED output, PE1 is button input.
	AND R1, #0xFD ;1111 1101. PE1 is input.
	STRB R1, [R0]
	
	LDR R0, =GPIO_PORTF_DIR_R
	LDRB R1, [R0]
	ORR R1, #0x04 ;PF2 is output.
	STRB R1, [R0]
	
	LDR R0, =GPIO_PORTE_DEN_R
	LDRB R1, [R0]
	ORR R1, #0x03 ;Digitally enable pins 0 and 1
	STRB R1, [R0]
	
	LDR R0, =GPIO_PORTF_DEN_R
	LDRB R1, [R0]
	ORR R1, #0x04 ;Digitally enable pin 2.
	STRB R1, [R0]
	
	;AFSEL and PUR unnecessary (we are not using any negative logic to justify using PUR).
	
Frequency RN 2
DutyCycle RN 3 ;From 0 to 100
PreviousButtonState RN 4
IncrementBy RN 5
OneHundred RN 6

	MOV Frequency, #8
	MOV DutyCycle, #20;%
	MOV PreviousButtonState, #0
	MOV IncrementBy, #20;%
	MOV OneHundred, #100
 
    CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
loop  

	BL toggleLED
	
	BL CheckButtonState

	B    loop

    ALIGN      ; make sure the end of this section is aligned
	
;_______________________________________________________________________________________________________________________________________________________________________________	
toggleLED 
	;Subroutine to turn the LED on and off based on the duty cycle.
	
	PUSH {R0, R1, R2, LR}
	
	LDR R1, =20000000
	UDIV R1, Frequency ;Now, we have the total number of cycles for 1 entire on-off loop.
	
	CMP DutyCycle, #0
	BEQ LEDOff ;If DutyCycle = 0, LED is never on.
	
	;Otherwise, we are here, and we turn the LED on.
	
LEDOn MOV R0, #0x11
	BL changeLEDState ;Turn LED off since R0 = 0x00.
	
;Count down for how long the LED should be on for.

	CMP DutyCycle, #100
	BEQ DutyCycleIs100 ;If not 100, LED and heartbeat follow each other.
	
	;Otherwise, duty cycle is not 100.

	MUL R0, R1, DutyCycle ;Multiply the number of cycles (R1) by the duty cycle.
	UDIV R0, OneHundred ;Divide by 100 to get the percentage of the total clock cycles for 1 second that the LED should be on for. Now, R0 = clock cycles to count down from for LED to
	;be on.
	B ContinueOn
	
	;If the duty cycle is 100%, I want to subtract the IncrementBy value from 100 to get the previous state. I count down (delay) from that percentage 
	;with 0x11 for changeLEDState, then set it to 0x01 and call changeLEDState again and continue the rest of the delay.
	
	;Otherwise, the DutyCycle is 100. So, do 100-IncrementBy. Multiply that by R0 and divide by 100
	
DutyCycleIs100	SUBS R0, OneHundred, IncrementBy ;R0 = 100 - IncrementBy. If the duty cycle was 100% and we increment by 20% every time, I want to keep it at 80%.
	MUL R0, R1, R0 
	UDIV R0, OneHundred ;Multiply R1 (20 million delay for 1 second (100% duty cycle)) by the previous duty cycle then divide by 100.
	
	BL Delay ;The delay is (100-IncrementBy)/100. So, if we increment the duty cycle by 30%, we delay for 70% for the blue LED.
	
	MOV R0, #0x01
	BL changeLEDState ;Now, turn the blue LED off but keep the breadboard LED on.
	
	;Now, delay by (100-(100-IncrementBy))/100 = IncrementBy/100.
	
	MUL R0, R1, IncrementBy
	UDIV R0, OneHundred
	
ContinueOn	BL Delay ;Delay for numberOfCycles * DutyCyclePercentage/100.
	
	CMP DutyCycle, #100
	BEQ Done ;If the duty cycle is 100, never turn the LED off.
	
LEDOff CMP DutyCycle, #0
	BEQ DutyCycleIs0
	
	;Otherwise, the duty cycle is not 0, and the breadboard LED and heartbeat should follow each other.

	MOV R0, #0x00
	BL changeLEDState ;Turn LED off since R0 = 0x00.
	SUB R0, OneHundred, DutyCycle ;The off time is 100% - DutyCycle (percentage on). R0 = percent of cycles that the LED is off. If Duty Cycle = 40% (on), 100-DutyCycle - 60% (off).
	MUL R0, R0, R1 ;Multiply the percentage off by the total number needed to count down from to have 1 second delay. So, if off = 60%, it should be off for 60% of 1 second.
	UDIV R0, OneHundred ;Now, R0 holds the numberofCycles for 1 entire-on-off loop * percetage of that cycle the LED is off. Divide by 100 to get the actual PERCENTAGE between 0 and 1.
	B ContinueOff
	
DutyCycleIs0 MOV R0, #0x10 ;Turn blue on-board LED on.
	BL changeLEDState ;Unlike when the duty cycle is 100, I need to actual change 0x00 to 0x10 before calling changeLEDState.
	SUBS R0, OneHundred, IncrementBy ;R0 = 100-IncrementBy = Previous Duty Cycle before 100%.
	MUL R0, R1, R0 ;Multiply the total countdown for a 100% duty cycle (20 million) by the duty cycle before 100%.
	UDIV R0, OneHundred ;Get the percentage between 0 and 1 (value/100).
	
	BL Delay
	
	MOV R0, #0x00
	BL changeLEDState
	
	MUL R0, R1, IncrementBy
	UDIV R0, OneHundred
	
ContinueOff	BL Delay
	
Done	
	POP {R0, R1, R2, LR}
	BX LR
	
;_______________________________________________________________________________________________________________________________________________________________________________		  
Delay
	;Takes the number in R0 for the delay.
	PUSH {R0, R1, R2, LR}
	
subtractAgain	SUBS R0, #1
	BGT subtractAgain
	
	POP {R0, R1, R2, LR}
	BX LR
	
;_______________________________________________________________________________________________________________________________________________________________________________	
changeLEDState ;Turns breadboard LED on or off depending on value of R0's least significant bit. R0 bit 0 = 0 = LED off. R0 bit 0 = 1 = LED on. Turns blue LED on
;microcontroller on depending on R0 bit 4. R0 bit 4 = 0 = LED off. R0 bit 4 = 1 = LED on.
	PUSH {R0, R1, R2, R3, R4, LR}
	LDR R1, =GPIO_PORTE_DATA_R
	LDRB R2, [R1]
	
	ORR R3, R0, #0xFE ;Change all other bits in R0 to a 1. R3 = R0 ORR 0xFE.
	AND R2, R3 ;AND the data with R3. If R3 = 0xFE, the led is off. If R3 = 0xFF, nothing changes.
	AND R3, #0x01 ;Preserve the least significant bit of R0.
	ORR R2, R3 ;ORR the data with R0. If R0 = 0x01, ORR turns bit 0 of the data to a 1 (LED on). If R0 = 0x00, nothing changes.
	STRB R2, [R1]
	
	LDR R1, =GPIO_PORTF_DATA_R
	LDRB R2, [R1]
	
	LSR R3, R0, #2 ;Shift value over 2 bits to correspond to PF2. R3 = R0 >> 2.
	ORR R3, #0xFB ;Change all other bits in R0 to a 1. FB = 1111 1011
	AND R2, R3 ;AND the data with R3. If R0 = 0xFE, the led is off. If R0 = 0xFF, nothing changes.
	AND R3, #0x04 ;Preserve the least significant bit of R0.
	ORR R2, R3 ;ORR the data with R0. If R0 = 0x01, ORR turns bit 0 of the data to a 1 (LED on). If R0 = 0x00, nothing changes.
	STRB R2, [R1]
	
	;LSL R0, #2
	;ORR R2, R0
	;ORR R0, #0xFB
	;AND R2, R0 ;Set PF4 LED
	;STRB R2, [R1]
	
LEDStateChanged	POP {R0, R1, R2, R3, R4, LR}
	BX LR

;(0 AND 0) ORR 0 = 0 ORR 0 = 0. (0 AND 1) ORR 1  = 0 ORR 1 = 1. (1 AND 0) ORR 0 = 0 ORR 0 = 0. (1 AND 1) ORR 1 = 1 ORR 0 = 1. 
;(0 ORR 0) AND 0 = 0 AND 0 = 0. (0 ORR 1) AND 1  = 1 AND 1 = 1. (1 ORR 0) AND 0 = 1 AND 0 = 0. (1 ORR 1) AND 1 = 1 AND 1 = 1.
;ORRing then ANDing or ANDing or ORRing a bit with another bit either changes the bit to a 0 with the AND and does not change it with the ORR, 
;or changes the bit to a 1 with the ORR and does not change it with the AND.
;THAT is why I can ORR then AND a bit or ORR it then AND it to set it equal to another bit.

;_______________________________________________________________________________________________________________________________________________________________________________
CheckButtonState 
	;Subroutine that checks the state of the button input (PE1) to determine if it has been released or not. If it has, it goes to the next duty cycle (20-40-60-80-100-0-20...)
	
	PUSH {R0, R1, R2, LR}
	
	LDR R0, =GPIO_PORTE_DATA_R
	LDRB R0,[R0]
	AND R0, #0x02 ;Preserve only bit 1 (the button status bit).
	LSR R0, #1 ;Logically shift it right 1 bit so it is easier to compare with PreviousButtonState
	
	CMP R0, PreviousButtonState
	BEQ StateChecked ;If the current button state is the same as the previous button state, nothing changed, so we are done here.
	
	;Otherwise, the state has changed.
	
	CMP PreviousButtonState, #0
	BEQ ChangeStateToCurrentState ;If the previous button state is 0, and the previous button state is not the same as the current state, the button was just pressed,
	;not released. So, just update the value for PreviousButtonState. The duty cycle only changes when the button is RELEASED.
	
	;Otherwise, if we are here and previous branches failed, the previous button state and the current button state are not the same, and the previous button state is not 0.
	;So, the previous button state is 1, and the current button state is a 0. Update the duty cycle.
	
	ADD DutyCycle, IncrementBy
	
	CMP DutyCycle, #100
	BGT ChangeDutyCycleTo0
	B ChangeStateToCurrentState
	
ChangeDutyCycleTo0 MOV DutyCycle, #0
	
ChangeStateToCurrentState MOV PreviousButtonState, R0
StateChecked	POP {R0, R1, R2, LR}
	BX LR
	
	ALIGN
	
    END        ; end of file