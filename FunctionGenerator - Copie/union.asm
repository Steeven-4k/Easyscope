#include <p18F4550.inc>

; config lines for interrupts        
CONFIG WDT = OFF			; disable watchdog timer 
CONFIG MCLRE = ON			; MCLEAR Pin On
CONFIG DEBUG = OFF			; Disable Debug Mode
CONFIG FOSC = HS			; Oscillator Mode 
CONFIG CPUDIV = OSC1_PLL2
CONFIG PBADEN = OFF
    
; Declaration of constants 
FREQ_MIN equ 10
FREQ_MAX equ 1000
; declaration of global variables 
FREQUENCY_POTENTIOMETER equ 0x20
; raw digits to be displayed
FREQUENCY_POTENTIOMETER_0 equ 0x20
FREQUENCY_POTENTIOMETER_1 equ 0x21
FREQUENCY_POTENTIOMETER_2 equ 0x22
FREQUENCY_POTENTIOMETER_3 equ 0x23
; temporary used by the decode routine
FREQUENCY_TEMPORARY equ 0x24
; final digits ready to be displayed
FREQUENCY_DISPLAY_0 equ 0x25
FREQUENCY_DISPLAY_1 equ 0x26 
FREQUENCY_DISPLAY_2 equ 0x27 
FREQUENCY_DISPLAY_3 equ 0x28  
 
count1 equ H'FF'			; Counter for DisplayDelay    
 
org 0x0000				; Reset vector
    GOTO INIT
org 0x0008				; ADC interrupt vector 
    GOTO ADCInterrupt
    
INIT
    CALL PortsInit
    CALL ADInit
    CALL InterruptsInit
    GOTO MAIN_LOOP
    
    
    
; Main function    
MAIN_LOOP
    CALL ReadPotentiometer
    CALL ExtractDigits
    ;CALL AssociateExtractDigits
    CALL ConvertToBCD
    CALL DisplayFrequency
    
    GOTO MAIN_LOOP
    
    
    
PortsInit
    ; initialization of PORTA (for the 7SEG)
    movlw B'11110000'          ; Configurer les bits RA0, RA1, RA2, RA3 comme des sorties numériques
    movwf TRISA
    ; initialization of PORTD (for the 7SEG)
    clrf TRISD				; PORTD is an OUTPUT 
    clrf PORTD				; Clear PORTD
    ; initialization of RA5 bit of PORTA (for the frequency_potentiometer)
    ;bsf TRISA, RA5 ; Set bit 5 (RA5) as INPUT
RETURN
    
ADInit 
    ; Change the ADCON1 register in digital I/O because it is analog input by default (for 7SEG)
    movlw B'00001010'			; Set RA5 as Analog I/O
    movwf ADCON1
    ; initialization of the A/D module
    movlw B'00010000'			; Set Channel 5 -> AN4
    movwf ADCON0 
    ; power up the A/D module 
    bsf ADCON0, ADON
RETURN
    
InterruptsInit
    ; configure interrupts 
    bsf INTCON, GIE			; interrupts
    bsf INTCON, PEIE			; Periph. Int.
    bsf PIE1, ADIE			; active l'interruption ADC
RETURN    
    
ADCInterrupt
    bcf PIR1, ADIF			; clear the ADC interrupt flag
    ; A/D result goes into FREQUENCY_POTENTIOMETER
    movf ADRESH, W			; load the high part of the result into WREG
    movwf FREQUENCY_POTENTIOMETER	; stock the value in FREQUENCY_POTENTIOMETER
    CALL LimitFrequency
RETFIE
    
ReadPotentiometer
    ; start the A/D conversion
    bsf ADCON0, GO_DONE
    ; Wait for the A/D to complete...
    WaitLoop
	btfsc ADCON0, GO_DONE		; Check if the conversion is occuring
    GOTO WaitLoop			; If the conversion is not complete, back to the loop
RETURN
    
LimitFrequency
    ; Chech if FREQUENCY_POTENTIOMETER is below FREQ_MIN    
    movlw FREQ_MIN			; load the min value in WREG
    subwf FREQUENCY_POTENTIOMETER, W	; Substract FREQUENCY_POTENTIOMETER to FREQ_MIN and stock the result in WREG
    btfsc STATUS, Z			; check if result is 0
    GOTO FrequencyInRange		; if the result is positive, FREQUENCY_POTENTIOMETER is in the range
    
    ; If below FREQ_MIN, set FREQUENCY_POTENTIOMETER to FREQ_MIN
    movlw FREQ_MIN	    
    movwf FREQUENCY_POTENTIOMETER	   
    ;GOTO FrequencyInRange		; ------------Peut être un CALL ?
RETURN  
    
FrequencyInRange
    ; Check if FREQUENCY_POTENTIOMETER is above FREQ_MAX
    movlw FREQ_MAX			; load the max value in WREG
    subwf FREQUENCY_POTENTIOMETER, W	; Substract FREQUENCY_POTENTIOMETER to FREQ_MAX and stock the result in WREG
    btfsc STATUS, Z			; check the carry flag
    GOTO Done
    
    ; If above FREQ_MAX, set FREQUENCY_POTENTIOMETER to FREQ_MAX
    movlw FREQ_MAX			
    movwf FREQUENCY_POTENTIOMETER
    GOTO Done
 
Done 
    RETURN        
   
ExtractDigits
    ; Division par 10 pour extraire les chiffres
    movlw 10
    movwf FREQUENCY_POTENTIOMETER_3	; Initialisation du quotient
    movlw 0    
    movwf FREQUENCY_POTENTIOMETER_2	; Initialisation du reste
    movwf FREQUENCY_POTENTIOMETER_1
    movwf FREQUENCY_POTENTIOMETER_0
    GOTO dig_loop
RETURN    

; Division répétée
; Explication : FREQUENCY_POTENTIOMETER est divisé par 10, et le reste est stocké dans FREQUENCY_POTENTIOMETER_0. FREQUENCY_POTENTIOMETER est mis à jour avec le quotient.
; on recommence l'itération : FREQUENCY_POTENTIOMETER (nouvelle valeur après la première itération) est divisé par 10, et le reste est stocké dans FREQUENCY_POTENTIOMETER_1. FREQUENCY_POTENTIOMETER est mis à jour avec le quotient.
; on continue ainsi de suite jusqu'à ce que la division ne soit plus possible et donc que tous les chiffres qui composent la fréquence du potentiomètre soient placés dans des variables
dig_loop
    movf FREQUENCY_POTENTIOMETER_3, W
    subwf FREQUENCY_POTENTIOMETER, W
    btfss STATUS, C          ; Si C=0, FREQUENCY_POTENTIOMETER < FREQUENCY_POTENTIOMETER_3
    GOTO dig_end
    incf FREQUENCY_POTENTIOMETER_0, F
    movf FREQUENCY_POTENTIOMETER_2, W
    subwf FREQUENCY_POTENTIOMETER_3, F
    movlw 10
    movwf FREQUENCY_POTENTIOMETER_3
    movf FREQUENCY_POTENTIOMETER_1, W
    subwf FREQUENCY_POTENTIOMETER_3, F
    GOTO dig_loop
    
dig_end
    clrf FREQUENCY_POTENTIOMETER_3  ; Remettre à zéro FREQUENCY_POTENTIOMETER_3
    RETURN
    
AssociateExtractDigits
    ; Associating Extracted numbers to FREQUENCY_POTENTIOMETER_X
    movwf FREQUENCY_POTENTIOMETER_0
    movf FREQUENCY_POTENTIOMETER_1, W
     
    movwf FREQUENCY_POTENTIOMETER_1
    movf FREQUENCY_POTENTIOMETER_2, W
    
    movwf FREQUENCY_POTENTIOMETER_2
    movf FREQUENCY_POTENTIOMETER_3, W
    
    movwf FREQUENCY_POTENTIOMETER_3
RETURN    

; Convert from raw to final digits ready to be displayed
ConvertToBCD
    ; - decode FREQUENCY_POTENTIOMETER_0
    movf FREQUENCY_POTENTIOMETER_0, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; returns with mask in w
    movwf FREQUENCY_DISPLAY_0		; Stock the value that will be displayed by the 7 SEG
     ; - decode FREQUENCY_POTENTIOMETER_1
    movf FREQUENCY_POTENTIOMETER_1, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; returns with mask in w
    movwf FREQUENCY_DISPLAY_1		; Stock the value that will be displayed by the 7 SEG
     ; - decode FREQUENCY_POTENTIOMETER_2
    movf FREQUENCY_POTENTIOMETER_2, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; returns with mask in w
    movwf FREQUENCY_DISPLAY_2		; Stock the value that will be displayed by the 7 SEG
     ; - decode FREQUENCY_POTENTIOMETER_3
    movf FREQUENCY_POTENTIOMETER_3, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; returns with mask in w
    movwf FREQUENCY_DISPLAY_3		; Stock the value that will be displayed by the 7 SEG
RETURN
    
; decode the real value of the digit in BCD    
decode_digit
    movf FREQUENCY_TEMPORARY, f
    btfsc STATUS, Z
    GOTO dis_is_0			; Z flag affected, it is 0
    decfsz FREQUENCY_TEMPORARY
    GOTO dis_mark1			; marks to jump
    GOTO dis_is_1			; it is 1   
    
    dis_mark1
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark2
	GOTO dis_is_2			; it is 2

    dis_mark2
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark3
	GOTO dis_is_3			; it is 3

    dis_mark3
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark4
	GOTO dis_is_4			; it is 4

    dis_mark4
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark5
	GOTO dis_is_5			; it is 5

    dis_mark5
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark6
	GOTO dis_is_6			; it is 6

    dis_mark6
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark7
	GOTO dis_is_7			; it is 7

    dis_mark7
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_mark8
	GOTO dis_is_8			; it is 8

    dis_mark8
	decfsz FREQUENCY_TEMPORARY
	GOTO dis_error
	GOTO dis_is_9			; it is 9

    dis_error				; should never arrive here
	GOTO dis_is_error

    ; --- apply mask and continue
    dis_is_0: retlw 0x3F		; mask for 0
    dis_is_1: retlw 0x06		; mask for 1
    dis_is_2: retlw 0x5B		; mask for 2
    dis_is_3: retlw 0x4F		; mask for 3
    dis_is_4: retlw 0x66		; mask for 4
    dis_is_5: retlw 0x6D		; mask for 5
    dis_is_6: retlw 0x7D		; mask for 6
    dis_is_7: retlw 0x07		; mask for 7
    dis_is_8: retlw 0x7F		; mask for 8
    dis_is_9: retlw 0x6F		; mask for 9
    dis_is_error: retlw 0x79		; mask for E 
RETURN

; Displays the frequency on the 7SEG  
DisplayFrequency
    movff FREQUENCY_DISPLAY_0, PORTD	; digit 0 into PORTD
    bsf LATA, RA0			; activate dis0
    CALL DisplayDelay			; wait a little
    bcf LATA, RA0			; deactivate dis0
    movff FREQUENCY_DISPLAY_1, PORTD	; digit 1 into PORTD
    bsf LATA, RA1			; activate dis1
    CALL DisplayDelay			; wait a little
    bcf LATA, RA1			; deactivate dis1
    movff FREQUENCY_DISPLAY_2, PORTD	; digit 2
    bsf LATA, RA2
    CALL DisplayDelay
    bcf LATA, RA2
    movff FREQUENCY_DISPLAY_3, PORTD	; digit 3
    bsf LATA, RA3
    CALL DisplayDelay
    bcf LATA, RA3      
RETURN
    
DisplayDelay
    ; Wait a couple of hundreds of clock cycles
    decfsz count1
    GOTO DisplayDelay
RETURN       
    
    
    
    
END    


