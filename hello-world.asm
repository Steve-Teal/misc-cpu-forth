

; 
; CPU operation source addresses
;

pc          equ 0   
pc+2        equ 1
pc+4        equ 2
pc+6        equ 3
[a]         equ 7
a           equ 8
sf          equ 9
zf          equ 10
cf          equ 12

;
; CPU operation destination addresses
;

pcs         equ 1      ; pc if negative
pcz         equ 2      ; pc if zero
pcc         equ 4      ; pc if carry
a-          equ 9
-a          equ 10
a+          equ 11
a^          equ 12
a|          equ 13
a&          equ 14
a>>         equ 15 

;
; UART addresses
;

tx          equ 0xfffc

            org 0x10

            mov pc,#start

hello       db 'Hello World!',0
#hello      dw hello
#0          dw 0
#1          dw 1
#ff         dw 0xff
ptr         dw 0
#ptr        dw 0
#start      dw start
#lp1        dw lp1
#end        dw end


start       mov a,#hello
            mov #ptr,a
lp1         mov a,[a]
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a&,#ff
            mov pcz,#end
            mov tx,a
            mov a,#ptr
            mov a,[a]
            mov a&,#ff
            mov pcz,#end
            mov tx,a
            mov a,#ptr
            mov a+,#1
            mov #ptr,a
            mov pc,#lp1
end         mov pc,#end

; End of file

