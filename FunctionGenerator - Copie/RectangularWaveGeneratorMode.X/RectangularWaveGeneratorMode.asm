#include <p18F4550.inc>

; Config lines for interrupts        
CONFIG WDT = OFF			; disable watchdog timer 
CONFIG MCLRE = ON			; MCLEAR Pin On
CONFIG DEBUG = OFF			; Disable Debug Mode
CONFIG FOSC = HS			; Oscillator Mode 
CONFIG CPUDIV = OSC1_PLL2
CONFIG PBADEN = OFF
    
; Declaration of constants 
FREQ_MIN equ 10
FREQ_MAX equ 1000
FREQ_SYS equ 8000000
; Declaration of variables
FREQUENCY_POTENTIOMETER equ 0x19
; Raw digits to be displayed
FREQUENCY_POTENTIOMETER_0 equ 0x20
FREQUENCY_POTENTIOMETER_1 equ 0x21
FREQUENCY_POTENTIOMETER_2 equ 0x22
FREQUENCY_POTENTIOMETER_3 equ 0x23
; Temporary used by the decode routine
FREQUENCY_TEMPORARY equ 0x24
; Final digits ready to be displayed
FREQUENCY_DISPLAY_0 equ 0x25
FREQUENCY_DISPLAY_1 equ 0x26 
FREQUENCY_DISPLAY_2 equ 0x27 
FREQUENCY_DISPLAY_3 equ 0x28
duty_cycle equ 0x29
led0_state equ 0x30
led1_state equ 0x31 
led2_state equ 0x32 
led3_state equ 0x33 
led4_state equ 0x34 
led5_state equ 0x35 
led6_state equ 0x36 
led7_state equ 0x37  
 
count1 equ H'FF'			; Counter for DisplayDelay    
 
org 0x0000				; Reset vector
    GOTO INIT
org 0x0008				; ADC interrupt vector 
    GOTO ADCInterrupt
    
INIT
    CALL PortsInit
    CALL ADInit
    CALL InterruptsInit
    CALL PWMInit
    GOTO MAIN_LOOP
  
    
    
; Main function    
MAIN_LOOP
; Display Frequency from the potentiometer on the 7SEG
    CALL ReadPotentiometer
    CALL ExtractDigits
    CALL ConvertToBCD
    CALL DisplayFrequency
; Create a PWM and change duty cycle with buttons
    ; Change the duty cycle by pressing buttons and activate LEDs 
    CALL ReadButtons

    GOTO MAIN_LOOP
    
    
; Initialisation of the ports    
PortsInit
    ; Initialisation of PORTA (for the 7SEG)
    movlw B'11110000'			; Set RA0, RA1, RA2, RA3 as digital outputs and RA5 as analog Input
    movwf TRISA
    ; Initalisation of PORTB (for the buttons)
    setf TRISB				
    clrf PORTB				
    ; initialiaation of PORTD (for the 7SEG)
    clrf TRISD				; PORTD is an OUTPUT 
    clrf PORTD				; Clear PORTD
RETURN
 
; Initialisation of the A/D Module
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
 
; Initialisation of interrupts    
InterruptsInit
    ; Configure interrupts 
    bsf INTCON, GIE			; interrupts
    bsf INTCON, PEIE			; Periph. Int.
    bsf PIE1, ADIE			; active l'interruption ADC
RETURN 
   
; Initialisation of the PWM    
PWMInit
    ; Configuration du module CCP en mode PWM
    bsf STATUS, 5 ; Set RP0 and go to Bank 1
    movlw B'00111100' ; Configure le CCP1 comme sortie PWM
    movwf CCP1CON
    bcf STATUS, 5 ; Clear RP0 and return to Bank 0
    
    ; Configuration du timer2 pour le PWM
    movlw B'00000101' ; Prescaler à 4 et postscaler à 1 pour le Timer2
    movwf T2CON
    
    ; Charge initiale de PR2 pour ajuster la fréquence du PWM
    movlw (FREQ_SYS / (4 * FREQUENCY_POTENTIOMETER)) - 1
    movwf PR2
    
    ; Activation du Timer2
    bsf T2CON, TMR2ON
    
    ; Activation de la sortie PWM sur CCP1
    bsf CCP1CON, CCP1M0
    bsf CCP1CON, CCP1M1 
RETURN        
 
; ADC interrupt which gives the potentiometer's frequency    
ADCInterrupt
    bcf PIR1, ADIF			; Clear the ADC interrupt flag
    ; A/D result goes into FREQUENCY_POTENTIOMETER
    movf ADRESH, W			; Load the high part of the result into WREG
    movwf FREQUENCY_POTENTIOMETER	; Stock the value in FREQUENCY_POTENTIOMETER
    CALL UpdatePWMFrequency
    CALL LimitFrequency
RETFIE
    
; Read the value of the potentiometer
ReadPotentiometer
    ; start the A/D conversion
    bsf ADCON0, GO_DONE
    ; Wait for the A/D to complete...
    WaitLoop
	btfsc ADCON0, GO_DONE		; Check if the conversion is occuring
    GOTO WaitLoop			; If the conversion is not complete, back to the loop
RETURN
 
; Limitate the frequency > 10
LimitFrequency
    ; Check if FREQUENCY_POTENTIOMETER is below FREQ_MIN    
    movlw FREQ_MIN			; Load the min value in WREG
    subwf FREQUENCY_POTENTIOMETER, W	; Substract FREQUENCY_POTENTIOMETER to FREQ_MIN and stock the result in WREG
    btfss STATUS, Z			; Check if result is 0
    GOTO FrequencyInRange		; If the result is positive, FREQUENCY_POTENTIOMETER is in the range
    
    ; If below FREQ_MIN, set FREQUENCY_POTENTIOMETER to FREQ_MIN
    movlw FREQ_MIN	    
    movwf FREQUENCY_POTENTIOMETER	   
RETURN  
 
; Limitate the frequency < 1000        
FrequencyInRange
    ; Check if FREQUENCY_POTENTIOMETER is above FREQ_MAX
    movlw FREQ_MAX			; Load the max value in WREG
    subwf FREQUENCY_POTENTIOMETER, W	; Substract FREQUENCY_POTENTIOMETER to FREQ_MAX and stock the result in WREG
    btfsc STATUS, Z			; Check the carry flag
    GOTO Done
    
    ; If above FREQ_MAX, set FREQUENCY_POTENTIOMETER to FREQ_MAX
    movlw FREQ_MAX			
    movwf FREQUENCY_POTENTIOMETER
    GOTO Done
 
Done 
    RETURN        
   
; Extract each digit composing the potentiometer's frequency    
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

; No more digit to extract
dig_end
    clrf FREQUENCY_POTENTIOMETER_3  ; Reset FREQUENCY_POTENTIOMETER_3
    RETURN
    
; Convert from raw to final digits ready to be displayed
ConvertToBCD
    ; Decode FREQUENCY_POTENTIOMETER_0
    movf FREQUENCY_POTENTIOMETER_0, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; Returns with mask in w
    movwf FREQUENCY_DISPLAY_0		; Stock the value that will be displayed by the 7 SEG
     ; Decode FREQUENCY_POTENTIOMETER_1
    movf FREQUENCY_POTENTIOMETER_1, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; Returns with mask in w
    movwf FREQUENCY_DISPLAY_1		; Stock the value that will be displayed by the 7 SEG
     ; Decode FREQUENCY_POTENTIOMETER_2
    movf FREQUENCY_POTENTIOMETER_2, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; Returns with mask in w
    movwf FREQUENCY_DISPLAY_2		; Stock the value that will be displayed by the 7 SEG
     ; Decode FREQUENCY_POTENTIOMETER_3
    movf FREQUENCY_POTENTIOMETER_3, 0
    movwf FREQUENCY_TEMPORARY
    CALL decode_digit			; Returns with mask in w
    movwf FREQUENCY_DISPLAY_3		; Stock the value that will be displayed by the 7 SEG
RETURN
    
; Decode the real value of the digit in BCD    
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

    ; Apply mask and continue
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
 
; Short delay to see the display    
DisplayDelay
    ; Wait a couple of hundreds of clock cycles
    decfsz count1
    GOTO DisplayDelay
RETURN       
 
; Detect which button is pressed    
ReadButtons
    CALL TurnOffLEDS
    btfsc PORTB, RB0
    CALL Button0
    btfsc PORTB, RB1
    CALL Button1
    btfsc PORTB, RB2
    CALL Button2
    btfsc PORTB, RB3
    CALL Button3
    btfsc PORTB, RB4
    CALL Button4
    btfsc PORTB, RB5
    CALL Button5
    btfsc PORTB, RB6
    CALL Button6
    btfsc PORTB, RB7
    CALL Button7
RETURN
	
; Turn off all the LEDs    
TurnOffLEDS
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN	

; Set duty cycle to 0.1 and activate the LED    
Button0
    ; Mise à jour de la valeur duty cycle 
    movlw (1/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton0
    btfss led0_state, 0
    bsf PORTB, RB0
    ; Mise à jour de l'état de la LED
    bsf led0_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN

; Set duty cycle to 0.2 and activate the LED      
Button1
    ; Mise à jour de la valeur duty cycle 
    movlw (2/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton1
    btfss led1_state, 0
    bsf PORTB, RB1
    ; Mise à jour de l'état de la LED
    bsf led1_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN   
  
; Set duty cycle to 0.3 and activate the LED      
Button2
    ; Mise à jour de la valeur duty cycle 
    movlw (3/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton2
    btfss led2_state, 0
    bsf PORTB, RB2
    ; Mise à jour de l'état de la LED
    bsf led2_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN

; Set duty cycle to 0.4 and activate the LED      
Button3
    ; Mise à jour de la valeur duty cycle 
    movlw (4/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton3
    btfss led3_state, 0
    bsf PORTB, RB3
    ; Mise à jour de l'état de la LED
    bsf led3_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN

; Set duty cycle to 0.5 and activate the LED      
Button4
    ; Mise à jour de la valeur duty cycle 
    movlw (5/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton4
    btfss led4_state, 0
    bsf PORTB, RB4
    ; Mise à jour de l'état de la LED
    bsf led4_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB5
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN
 
; Set duty cycle to 0.6 and activate the LED      
Button5
    ; Mise à jour de la valeur duty cycle 
    movlw (6/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton5
    btfss led5_state, 0
    bsf PORTB, RB5
    ; Mise à jour de l'état de la LED
    bsf led5_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB6
    bcf PORTB, RB7
RETURN
 
; Set duty cycle to 0.7 and activate the LED      
Button6
    ; Mise à jour de la valeur duty cycle 
    movlw (7/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton6
    btfss led6_state, 0
    bsf PORTB, RB6
    ; Mise à jour de l'état de la LED
    bsf led6_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB7
RETURN
  
; Set duty cycle to 0.8 and activate the LED      
Button7
    ; Mise à jour de la valeur duty cycle 
    movlw (8/10)
    movwf duty_cycle
    CALL UpdatePWM
    ; Allumage de la LED du bouton7
    btfss led7_state, 0
    bsf PORTB, RB7
    ; Mise à jour de l'état de la LED
    bsf led7_state, 0
    ; Eteindre toutes les autres LED
    bcf PORTB, RB0
    bcf PORTB, RB1
    bcf PORTB, RB2
    bcf PORTB, RB3
    bcf PORTB, RB4
    bcf PORTB, RB5
    bcf PORTB, RB6
RETURN
    
; Update the PWM according to the duty cycle    
UpdatePWM
    ; Load the value of duty cycle in CCPR1L
    movf duty_cycle, W
    movwf CCPR1L
RETURN    
   
; Update the PWM according to the potentiometer's frequency    
UpdatePWMFrequency
    ; Recalculate PR2 based on the new frequency from the potentiometer
    movlw (FREQ_SYS / (4 * FREQUENCY_POTENTIOMETER)) - 1
    movwf PR2
    ; Update the PWM frequency
    bsf STATUS, 5 ; Set RP0 and go to Bank 1
    movf PR2, W
    movwf T2CON
    bcf STATUS, 5 ; Clear RP0 and return to Bank 0
RETURN    
    
    
END    


