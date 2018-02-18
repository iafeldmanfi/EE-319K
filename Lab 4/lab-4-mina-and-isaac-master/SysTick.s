; SysTick.s
; Module written by: Isaac Feldman and Mina Gawargious
; Date Created: 2/14/2017
; Last Modified: 2/12/2018 
; Brief Description: Initializes SysTick

NVIC_ST_CTRL_R        EQU 0xE000E010
NVIC_ST_RELOAD_R      EQU 0xE000E014
NVIC_ST_CURRENT_R     EQU 0xE000E018

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
; -UUU- You add code here to export your routine(s) from SysTick.s to main.s
	EXPORT SysTick_Init

;------------SysTick_Init------------
; ;-UUU-Complete this subroutine
; Initialize SysTick running at bus clock.
	IMPORT  TExaS_Init
; Make it so NVIC_ST_CURRENT_R can be used as a 24-bit time
	LDR R0, =NVIC_ST_CURRENT_R
	LDR R1, [R0]
	AND R1, #0x00FFFFFF
	STR R1, [R0]
; Input: none
; Output: none
; Modifies: ??
SysTick_Init
 ; **-UUU-**Implement this function****
	PUSH {R0, R1, R2, LR}
 
	BL TExaS_Init
	
	LDR R0, =NVIC_ST_CTRL_R
	LDRB R1, [R0]
	AND R1, #0xFE ;Disable clock for SysTick (bit 0).
	STRB R1, [R0]
	
	LDR R0, =NVIC_ST_RELOAD_R
	LDR R1, =0x00FFFFFF
	STR R1, [R0]
	
	LDR R0, =NVIC_ST_CURRENT_R
	MOV R1, #0
	STRH R1, [R0]
	
	LDR R0, =NVIC_ST_CTRL_R
	LDRB R1, [R0]
	ORR R1, #0x05 ;Toggle enable and clock source bits (xxxxx101)
	STRB R1, [R0]
 
	
	POP {R0, R1, R2, LR}
	
    BX  LR                          ; return

    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file
