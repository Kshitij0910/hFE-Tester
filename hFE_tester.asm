#make_bin#

#LOAD_SEGMENT=0500h#
#LOAD_OFFSET=0000h#

; set entry point:
#CS=0500h#	; same as loading segment
#IP=0000h#	; same as loading offset

; set segment registers
#DS=0500h#	; same as loading segment
#ES=0500h#	; same as loading segment

; set stack
#SS=0500h#	; same as loading segment
#SP=FFFEh#	; set to top of loading segment

; set general registers (optional)
#AX=0000h#
#BX=0000h#         
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#
;-------------------------------------------------------------------------------------------------

.MODEL TINY
.DATA

;Total No of experiments to be conducted = 10
cnt         EQU 10
;Number of expt currently conducted
curCt       DB  01
;Sum of hFE values obtained so far
hFE_Sum     DW  00
;Average value of hFE
hFE_Avg     DB  00
;Store digits of hFE_Avg
;DIGIT_hFE   DB 3 DUP(0) 
DIGIT_hFE   DB 03, 02, 01
 

;Using 8253 to generate clock signals
CNT0 EQU 20H 
CREG EQU 26H 

;Controlling the LED display using 8255(1)
;Initializing 8255(1)
PORT1A      EQU 00H
PORT1B      EQU 02H
PORT1C      EQU 04H 
CREG1       EQU 06H

;ADC converter
PORT2A      EQU 10H ;Input to DI device
PORT2B      EQU 12H ;ADC (converted value)
PORT2C      EQU 14H ;PC1 --> SOC, PC2 --> Alarm Signal, PC3 --> Select Input channel, PC5 --> EOC
CREG2       EQU 16H





.CODE
.STARTUP 
        mov curCt, 1
        mov hFE_Sum, 0
        mov hFE_Avg, 0
        ;Initializing 8253
        mov al, 00010110b 
        out CREG, al 
        mov al, 9 
        out CNT0,al 

        ;Initializing 8255(1)
        mov al, 10001000b   ;Upper port to be configured with binary counting
        out CREG1, al
        
        
        ;Initializing 8255(2)
        mov al, 10001010b 
        out CREG2, al
        
        
        
 again: call send_voltage       ;send this V  
        call delay_2ms
        call get_voltage_drop   ;get Vd  
        call delay_2ms
        call curr_hFE
        
        cmp curCt, 10
        jz next   
        inc curCt
        jmp again
        
 next:  call avg_hFE
        call alarm   
        call delay_2ms
        call save_digits
        call display
         
        


.EXIT

;Procedure for sending voltage to DI device-------------------------------------------------------
    ;We are sending multiple of 25 to DI device through DAC. 
    send_voltage proc near
        mov ch, curCt
        
        ;input V = 1
        cmp ch, 1
        jnz v1
        mov al, 25
        out PORT2A, al
        jmp endv
        
        ;input V = 2
    v1: cmp ch, 2 
        jnz v2
        mov al, 50
        out PORT2A, al
        jmp endv
        
        ;input V = 3
    v2: cmp ch, 3
        jnz v3
        mov al, 75
        out PORT2A, al
        jmp endv
        
        ;input V = 4
    v3: cmp ch, 4
        jnz v4 
        mov al, 100
        out PORT2A, al
        jmp endv
        
        ;input V = 5
    v4: cmp ch, 5
        jnz v5
        mov al, 125
        out PORT2A, al
        jmp endv
        
        ;input V = 6
    v5: cmp ch, 6
        jnz v6
        mov al, 150
        out PORT2A, al
        jmp endv
        
        ;input V = 7
    v6: cmp ch, 7
        jnz v7
        mov al, 175
        out PORT2A, al
        jmp endv 
        
        ;input V = 8
    v7: cmp ch, 8 
        jnz v8
        mov al, 200
        out PORT2A, al
        jmp endv    
        
        ;input V = 9
    v8: cmp ch, 9  
        jnz v9
        mov al, 225
        out PORT2A, al
        jmp endv    
        
        ;input V = 10
    v9: cmp ch, 10
        mov al, 250
        out PORT2A, al
    endv:ret
    send_voltage endp
        
        
        
         
        
        
    
;Procedure to get voltage drop across 1K ohm resistor---------------------------------------------
    get_voltage_drop proc near    
        ;select Input Channel IN0
        mov al, 06h     ;PC3 = 0
        out CREG2, al
        call delay_2ms              
                      
        ;reset ALE signal
        mov al, 00h     ;PC0   8255 PC0 --> ALEbar ADC
        out CREG2, al
        call delay_2ms
        
        ;reset SOC signal
        mov al, 02h     ;PC1
        out CREG2, al         
        
        
        ;check this piece of code
        mov al, 01h     ;0_000_000_1 PC0 = 1 set ALE
        out CREG2, al   
        
        mov al, 03h     ;0_000_001_1  
        out CREG2, al   
        
        mov al, 02h     ;reset SOC to start PC1 = 0
        out CREG, al
        
        mov al, 00h     ;reset ALE          PC0 = 0
        out CREG2, al
        
    lp: in  al, PORT2C
        call delay_2ms
        and al, 20h     ;0010 0000 and al = PC5 bit ==> EOC
        cmp al, 20h
        jnz lp
        
        call delay_2ms  ;don't know the reason for this
        in  al, PORT2B  ;Voltage drop transferred to al
        mov ah, 00h
        ret
    get_voltage_drop endp





;Procedure to calculate curr_hFE------------------------------------------------------------------
    curr_hFE proc near 
        mov ch, curCt
        
        cmp ch, 1
        jnz ch1
        mov bx, 1000    ;hFE = (Vd * 1000)/V, V = 1, we are calculating 1000/V
        jmp val
    
    ch1:cmp ch, 2
        jnz ch2
        mov bx, 500      ;@ V = 2, 1000/V = 500
        jmp val 
        
    ch2:cmp ch, 3
        jnz ch3
        mov bx, 333      ;@ V = 3, 1000/V = 333
        jmp val
        
    ch3:cmp ch, 4
        jnz ch4
        mov bx, 250      ;@ V = 4, 1000/V = 250
        jmp val
        
    ch4:cmp ch, 5
        jnz ch5
        mov bx, 200      ;@ V = 5, 1000/V = 200
        jmp val
        
    ch5:cmp ch, 6
        jnz ch6
        mov bx, 167      ;@ V = 6, 1000/V = 167
        jmp val
        
    ch6:cmp ch, 7
        jnz ch7
        mov bx, 143      ;@ V = 7, 1000/V = 143
        jmp val
        
    ch7:cmp ch, 8
        jnz ch8
        mov bx, 125      ;@ V = 8, 1000/V = 125
        jmp val
        
    ch8:cmp ch, 9
        jnz ch9
        mov bx, 111      ;@ V = 9, 1000/V = 111
        jmp val
       
    ch9:cmp ch, 10
        mov bx, 100      ;@ V = 10, 1000/V = 100
        
        
    val:mul bx          ;hFE = Vd * (bx)
         lea si, hFE_Sum
         add [si], ax
         
         ;lea di, curCt
         ;inc BYTE PTR[di]
         
         jmp e1
         
    e1:  ret
    curr_hFE endp
    




;Procedure to calculate average hFE---------------------------------------------------------------
    avg_hFE proc near
        lea si, hFE_Sum
        lea di, hFE_Avg
        mov ax, [si]
        div curCt
        mov [di], al 
        ret
    avg_hFE endp 
    





;Procedure to store the digits of avg_HFE---------------------------------------------------------
    save_digits proc near
        lea si, hFE_Avg
	    mov ax, [si]
		mov cl, 3
		mov bl, 10
		lea di, DIGIT_hFE
	up:	div bl
		mov [di], ah
		inc di
		mov ah, 0
		dec cl
		jnz up
		ret
	save_digits endp 
    




;Procedure to display on 7seg----------------------------------------------------------------------
     display proc near

        
        ;Intialise porta as input & portb, portc as output
	mov al,90h  ;1-> i/o mode 
		    ;00 -> mode 0
		    ;1 -> i/p
		    ;1 -> upper port C o/p lookup
		    ;000 -> port B mode 0 o/p port C lower o/p
		out CREG1,al 
     x2:mov cx,3
		mov bl,00000001b
		lea si,DIGIT_hFE	

     x1:mov al,bl       ;al = 1
		out PORT1C,al   ;port c
		mov al,[si]       ;al = 1
		out PORT1B,al   ;port b    
		call sub1
		call sub1
		call sub1
		call sub1
		rol bl,1
		inc si
		loop x1
 
	jmp x2
	ret
      display endp 
     
    
    sub1 proc near
        push cx
        mov  cx,10 ; delay generated will be approx 0.45 secs
    x3:	loop x3 
        pop  cx
		ret
	sub1 endp
    
    
    
    

;Procedure to set alarm----------------------------------------------------------------------------
    alarm proc near
        lea si, hFE_Avg
        mov al, [si]
        cmp al, 20
        jnb np
        mov al, 05h ;set PC2 0_000_010_1
        out CREG2, al
        
        call delay_2ms
        mov al, 04h
        mov CREG2, al
    np: mov cx, 10
    z3: call delay_2ms
        loop z3
        ret
    alarm endp
                  
                  
                  
    
;Delay Procedure-----------------------------------------------------------------------------------    
    ;2ms
    delay_2ms proc near
        mov cx, 500
    dlp:nop
        loop dlp
        ret
    delay_2ms endp     
        
            
        
        
    

			    
         
                       
                       
        
        
                           
                        
             


END  



