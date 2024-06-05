;******************************************************************************
;   This file is a basic template for assembly code for a PIC18F4525. Copy    *
;   this file into your project directory and modify or add to it as needed.  *
;                                                                             *
;   Refer to the MPASM User's Guide for additional information on the         *
;   features of the assembler.                                                *
;                                                                             *
;   Refer to the PIC18FX525/X620 Data Sheet for additional                    *
;   information on the architecture and instruction set.                      *
;                                                                             *
;******************************************************************************
;                                                                             *
;    Filename:                                                                *
;    Date:                                                                    *
;    File Version:                                                            *
;                                                                             *
;    Author:                                                                  *
;    Company:                                                                 *
;                                                                             * 
;******************************************************************************
;                                                                             *
;    Files Required: P18F4525.INC                                             *
;                                                                             *
;******************************************************************************

	LIST P=18F4525	;directive to define processor
	#include "P18F4525.INC"	;processor specific variable definitions

;******************************************************************************
;Configuration bits
;Microchip has changed the format for defining the configuration bits, please 
;see the .inc file for futher details on notation.  Below are a few examples.



;   Oscillator Selection:
    CONFIG	OSC = XT             ;LP

;******************************************************************************
;Variable definitions
; These variables are only needed if low priority interrupts are used. 
; More variables may be needed to store other special function registers used
; in the interrupt routines.

		bit_buffer_h equ 0x00
		bit_buffer_l equ 0x01
		
		bit_ctr equ 0x02
		

;******************************************************************************
;EEPROM data
; Data to be programmed into the Data EEPROM is defined here

		ORG	0xf00000

		DE	"Test Data",0,1,2,3,4,5

;******************************************************************************
;Reset vector
; This code will start executing when a reset occurs.

		ORG	0x0000

		goto	Main		;go to start of main code

;******************************************************************************
;High priority interrupt vector
; This code will start executing when a high priority interrupt occurs or
; when any interrupt occurs if interrupt priorities are not enabled.

		ORG	0x0008

		bra	HighInt		;go to high priority interrupt routine

;******************************************************************************
;Low priority interrupt vector and routine
; This code will start executing when a low priority interrupt occurs.
; This code can be removed if low priority interrupts are not used.

		ORG 0x0018
		
		bra LowInt

;******************************************************************************
;High priority interrupt routine
; The high priority interrupt code is placed here to avoid conflicting with
; the low priority interrupt vector.

HighInt:

		; temporary
		movlw b'10110101' ;b'00110101'
		movwf bit_buffer_h
		movlw b'00110101'
		movwf bit_buffer_l

		
		call send_bits


		retfie	FAST

;******************************************************************************
;Low priority interrupt routine

LowInt:
		
		; stop timers
		bcf T0CON,TMR0ON
		bcf T2CON,TMR2ON
		
		bcf INTCON,TMR0IF

		retfie


;******************************************************************************
;Interrupt configuration routines
init_portb:
		; Routine f�r INT0- INT2 
		clrf	 PORTB      
     
		bcf    ADCON0,ADON ; AD Converter disabled 
      
		movlw	0xFF
		movwf	TRISB  

		movlw	 0xFF
		movwf	 ADCON1
; Clear Interrupt flags 

    	bcf 	INTCON,INT0IF
		bcf		INTCON3,INT1IF
		bcf		INTCON3,INT2IF
    	bcf		INTCON,RBIF
    
    	bcf 	INTCON2,RBPU

; Enable Interrupts       
    	bsf 	INTCON,INT0IE
		bsf		INTCON3,INT1IE
		bsf		INTCON3,INT2IE
    	bsf		INTCON,RBIE

; Set edges in this case on falling edge 
    	bcf 	INTCON2,INTEDG0
    	bcf		INTCON2,INTEDG1
		bcf		INTCON2,INTEDG2

; Interrupt priority of int1 / 2 needs to be configured 

    	bsf 	INTCON,GIEH  
		bsf 	INTCON,GIEL 
      
		bsf 	RCON,IPEN ; Enables Priorities 

; Setting Priority high for INT1, INT2 
		bsf		INTCON3,INT2IP
		bsf		INTCON3,INT1IP
    	bsf		INTCON2,RBIP ; Low Priority for interrupt on change

		return

;******************************************************************************
; Output configuration routines

init_portc:
		; configure port c
		clrf PORTC
		clrf LATC
		clrf TRISC
		return

init_tmr:
		; configure pwm module
		banksel PR2
		movlw 0x08 ;0x44			; configure period time with 0x44
		movwf PR2

		movlw b'00000011' ;b'00000100'	; configure duty cycle with 0x11
		movwf CCPR2L
		movlw b'00111100' ;b'00011100'	; configure pwm mode and 2 lsbs of duty cycle
		movwf CCP2CON

		movlw b'00000000'
		movwf T2CON

		; configure timer 0 for delay
		movlw b'00001000'
		movwf T0CON
	
		bcf INTCON,TMR0IF ;interrupt flag
		bsf INTCON,TMR0IE ;interrupt enable
		bcf INTCON2,TMR0IP ;low priority interrupt
		bsf INTCON,GIE ;general interrupt enable

		;movlw 0x00
		;movwf tmr_done		

		return


;******************************************************************************
; Helper sender routines
tmr_delay:
		;start timer 0 for pausing
		movlw 0xFF ;0xF0
		movwf TMR0H
		movlw 0xF0 ;0x52
		movwf TMR0L
		bsf T0CON,TMR0ON
		call delay_loop
		return

pwm_delay:
		;load timer 0 for half bit
		movlw 0xFF ;0xF7
		movwf TMR0H
		movlw 0xE0 ;0x52
		movwf TMR0L
		;load timer 2 for pwm
		movlw 0x00
		movwf TMR2
		bsf LATC,1 ;set first pulse manually

		bsf T0CON,TMR0ON
		bsf T2CON,TMR2ON

		call delay_loop

		return

;wait for interrupt to end half bit
delay_loop
		btfss tmr_done,0
		bra delay_loop
		bcf tmr_done,0
		return
		

send_0:
		call tmr_delay
		call pwm_delay
		return

send_1:
		call pwm_delay
		call tmr_delay
		return

;******************************************************************************
; Main sender routine

send_command:
		;skip first two bits
		rlcf bit_buffer_l
		rlcf bit_buffer_h
		rlcf bit_buffer_l
		rlcf bit_buffer_h

send_bit:
		rlcf bit_buffer_l
		rlcf bit_buffer_h
		btfss STATUS,C
		call send_0
		call send_1
		decfsz bit_ctr
		bra send_bit
		return


;******************************************************************************
;Start of main program
; The main program code is placed here.

Main:
		call init_portb
		call init_portc
		call init_tmr




;******************************************************************************
;End of program
	goto $
		END