

; Inner interpreters: dolit dolist donext ?branch branch execute exit
; System interface:   emit key ?key
; Memory access:      ! @ c! c@
; Return stack:       rp! r> r@ >r
; Data stack:         sp! drop dup swap over pick depth
; Logic:              0< and or xor
; Arithmetic:         um+
;


; Special CPU registers

pc          equ 0   
pc+2        equ 1
pc+4        equ 2
pc+6        equ 3
[a]         equ 7
a           equ 8
pcs         equ 1     
pcz         equ 2     
pcc         equ 4     
a-          equ 9
a+          equ 11
a^          equ 12
a|          equ 13
a&          equ 14
a>>         equ 15     

; UART registers

tx          equ 0xfffc      ; Transmit register
?tx         equ 0xfffd      ; Bit 0 transmiter busy
rx          equ 0xfffe      ; Receive register
?rx         equ 0xffff      ; Bit 0 receive register empty

            org 0x10

            mov sp,sp0
            mov rp,rp0
            mov pc,start
start       dw cold

; data and return stack

rp0         dw rp0
            org 0x100
underflow   dw 0,0,0,0
sp0         dw underflow

; System variables

sp          dw 0            ; Stack pointer
rp          dw 0            ; Return stack pointer
ip          dw 0            ; Interpreter pointer
t0          dw 0            ; Temporary variables
t1          dw 0
t2          dw 0
t3          dw 0

; Literals

#0          dw 0
#1          dw 1
#2          dw 2
#16         dw 16
#ff         dw 0xff
#ff00       dw 0xff00
#ffff       dw 0xffff

; dolit ( -- w )
; Push an inline literal

dolit       mov a,ip
            mov t0,[a]
            mov a+,#1
            mov ip,a
            mov a,sp
            mov a-,#1
            mov sp,a
            mov [a],t0
            mov pc,$next

; dolist 
; Process colon list t0

dolist      dw dolist1
dolist1     mov a,rp
            mov a+,#1
            mov rp,a
            mov [a],ip
            mov ip,t0
dolist2     mov a,ip
            mov t0,[a]
            mov a+,#1
            mov ip,a
            mov pc,t0

; $next ( -- )
; Execute next word on list        

$next      dw dolist2    

; donext ( -- )
; Run time code for the single index loop

donext      mov a,rp            ; RP points to index
            mov a,[a]
            mov a-,#1           ; Decrement index
            mov t0,a
            mov a,rp
            mov pcc,donext1     ; Jump if loop finished (index was 0 before decrementing)
            mov [a],t0          ; Store new index
            mov a,ip            ; IP points to location of word to jump back to
            mov ip,[a]          
            mov pc,$next
donext1     dw donext2          ; Loop has finished
donext2     mov a-,#1           ; Decrement RP (remove index from return stack)
            mov rp,a
            mov a,ip            ; Skip next word 
            mov a+,#1
            mov ip,a
            mov pc,$next        ; Execute next word on list

; dovar ( -- a )
; Return the address of a variable

dovar       mov a,ip
            mov a+,a
            mov t0,a
            mov a,ip
            mov a+,#1
            mov ip,a
            mov a,sp
            mov a-,#1
            mov sp,a
            mov [a],t0
            mov pc,$next

; ?branch ( f -- )
; Branch if flag is zero

qbranch     mov a,sp
            mov t0,[a]
            mov a+,#1
            mov sp,a
            mov a,ip
            mov t1,[a]
            mov a+,#1
            mov ip,a
            mov a,t0
            mov pcz,pc+4
            mov pc,$next
            mov ip,t1
            mov pc,$next

; branch ( -- )
; Branch to an inline address

branch      mov a,ip
            mov ip,[a]      
            mov pc,$next

; execute ( ca -- )
; Execute the word at ca

_execute    dw 0
            db 7,'execute'
execute     mov a,sp
            mov t0,[a]
            mov a+,#1
            mov sp,a
            mov pc,t0

; exit ( -- )
; Terminate a a colon definition
_exit       dw _execute
            db 4,'exit'
exit        mov a,rp
            mov ip,[a]
            mov a-,#1
            mov rp,a
            mov pc,$next

; emit ( c -- )
; Send character c to the output device.
_emit       dw _exit
            db 4,'emit'
emit        mov t0,pc+2         ; Load t0 with address of next instruction
            mov a>>,?tx         ; Shift transmit busy bit into carry
            mov pcc,t0          ; Loop to previous instruction if carry set
            mov a,sp 
            mov tx,[a]          ; Read stack and transmit character
            mov a+,#1           ; Decrement stack pointer
            mov sp,a            ; Store stack pointer
            mov pc,$next

; key ( -- c )
; Return input character
_key        dw _emit
            db 3,'key'
key         mov t0,pc+2         ; Load t0 with address of next instruction
            mov a>>,?rx         ; Shift receive empty bit into carry
            mov pcc,t0          ; Loop to previous instruction if carry set
            mov a,sp 
            mov [a],rx          ; Push character onto stack
            mov a-,#1           ; Increment stack pointer
            mov sp,a            ; Store stack pointer
            mov pc,$next

; ?key ( -- F | c T )
; Return true and input character or false if no character received
_qkey       dw _key
            db 4,'?key'
qkey        mov a,sp            ; Decrement stack pointer
            mov a-,#1
            mov sp,a
            mov a,?rx           ; Read receive status 1 = empty, 0 = full  
            mov a+,#ffff        ; Convert to false 0, true -1 carry will be set if false
            mov t0,a            
            mov a,sp            ; Read stack pointer
            mov pcc,pc+6        ; Skip next 2 instructions if carry set (if rx is false)
            mov [a],rx          ; Push character onto stack
            mov a-,#1           ; Decrement stack pointer
            mov [a],t0          ; Push flag onto stack
            mov a-,#1
            mov sp,a            ; Store stack pointer
            mov pc,$next

; ! ( w a -- )
; Pop the data stack to memory
_store      dw 0
            db 1,'!'
store       mov a,sp
            mov t0,[a]
            mov a+,#1
            mov t1,[a]
            mov a+,#1
            mov sp,a
            mov a>>,t0
            mov [a],t1
            mov pc,$next
        
; @ ( a -- w )
; Push memory location to the data stack
_at         dw _store
            db 1,'@'
at          mov a+,#0
            mov a,sp
            mov a>>,[a]
            mov t0,[a]
            mov a,sp
            mov [a],t0
            mov pc,$next

; c! ( c b -- ) 
; Pop the data stack to byte memory
_cstore     dw _at
            db 2,'c!'
cstore      mov a,sp
            mov t0,[a]          
            mov a+,#1
            mov t1,[a]          
            mov a+,#1
            mov sp,a            ; Update stack pointer
            mov a>>,t0          ; Shift address 
            mov t0,a      
            mov a,[a]           ; Read value from memory
            mov pcc,#cstore1    ; Jump if writing to low byte
            mov a&,#ff
            mov t2,a
            mov a,t1
            mov a+,a
            mov a+,a
            mov a+,a
            mov a+,a
            mov a+,a
            mov a+,a
            mov a+,a
            mov a+,a
            mov pc,#cstore2
cstore1     mov a&,#ff00
            mov t2,a
            mov a,t1
            mov a&,#ff
cstore2     mov a|,t2
            mov t1,a            ; Write a to [t0]
            mov a,t0           
            mov [a],t1
            mov pc,$next
#cstore1    dw cstore1
#cstore2    dw cstore2

; c@ ( b -- c )
; Push byte memory location to the data stack
_cat        dw _cstore
            db 2,'c@'
cat         mov a+,#0           ; Clear carry
            mov a,sp
            mov a>>,[a]         ; Read top value from stack and shift left
            mov a,[a]
            mov pcc,pc+6        ; Skip next 2 instructions if carry set
            mov t0,pc+4         ; t0 address of instruction after next "return address"
            mov pc,cat1         ; Jump to "subtroutine"
            mov a&,#ff
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next
cat1        dw cat2
cat2        mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov a>>,a
            mov pc,t0

; rp! ( -- )
; Init return stack pointer
_rpsto      dw _cat
            db 3,'rp!'
rpsto       mov rp,rp0
            mov pc,$next

; r> ( -- w )
; Pop the return stack to the data stack
_rfrom      dw _rpsto
            db 2,'r>'
rfrom       mov a,rp
            mov t0,[a]      ; Read return stack to t0
            mov a-,#1
            mov rp,a        ; Update return stack pointer
            mov a,sp
            mov a-,#1
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Store value to stack
            mov pc,$next

; r@ ( -- w )
; Copy top of return stack to the data stack
_rat        dw _rfrom
            db 2,'r@'
rat         mov a,rp
            mov t0,[a]      ; Read return stack to t0
            mov a,sp        
            mov a-,#1
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Store value to stack
            mov pc,$next

; >r ( w -- )
; Push the data stack to the return stack
_tor        dw _rat
            db 2,'>r'
tor         mov a,sp
            mov t0,[a]      ; Read stack to t0
            mov a+,#1
            mov sp,a        ; Update stack pointer
            mov a,rp
            mov a+,#1       
            mov rp,a        ; Update return stack pointer
            mov [a],t0      ; Store value to return stack
            mov pc,$next

; sp! ( -- )
; Init data stack pointer
_spsto      dw _tor
            db 3,'sp!'
spsto       mov sp,sp0
            mov pc,$next

; drop ( w -- )
; Discard top stack item
_drop       dw _spsto
            db 4,'drop'
drop        mov a,sp
            mov a+,#1
            mov sp,a
            mov pc,$next

; dup ( w -- w w )
; Duplicate the top stack item
 _dup       dw _drop
            db 3,'dup'
dup         mov a,sp
            mov t0,[a]      ; Read stack to t0
            mov a-,#1
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Write value to stack
            mov pc,$next

; swap ( w1 w2 -- w2 w1 )
; Exchange top two stack items
_swap       dw _dup
            db 4,'swap'
swap        mov a,sp
            mov t0,[a]      ; Read stack to t0
            mov a+,#1
            mov t1,[a]      ; Read next on stack to t1
            mov [a],t0      ; Write t0 to next on stack
            mov a-,#1
            mov [a],t1      ; Write t1 to stack
            mov pc,$next

; over ( w1 w2 -- w1 w2 w1 )
; Copy second stack item to top
_over       dw _swap
            db 4,'over'
over        mov a,sp
            mov a+,#1
            mov t0,[a]      ; Read next on stack to t0
            mov a-,#2
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Store t0 to stack
            mov pc,$next

; pick ( ... +n -- ... w )
; Copy the nth stack item to tos
_pick       dw _over
            db 4,'pick'
pick        mov a,sp
            mov a,[a]       ; Read stack
            mov a+,sp       ; Move stack pointer back by value
            mov a+,#1       ; Plus one to account for value just read
            mov t0,[a]      ; Read stack
            mov a,sp        ; Restore stack pointer
            mov [a],t0      ; Store value read to stack
            mov pc,$next

; depth ( -- n )
; Return the depth of the data stack
_depth      dw _pick
            db 5,'depth'
depth       mov a,sp0       ; Read location of start fo stack
            mov a-,sp       ; Subract stack pointer
            mov t0,a        ; t0 is depth
            mov a,sp        ; Push depth onto stack
            mov a-,#1
            mov sp,a
            mov [a],t0      
            mov pc,$next

; 0< ( n -- t )
; Return true if n is negative
_zless      dw _depth
            db 2,'0<'
zless       mov a,sp
            mov a,[a]       ; Read stack
            mov pcs,pc+6    ; Skip next two insructions if negative
            mov t0,#0       ; False flag
            mov pc,pc+4     ; Skip next instruction
            mov t0,#ffff    ; True flag
            mov a,sp        ; Get stack pointer
            mov [a],t0      ; Write flag to stack
            mov pc,$next

; 0= ( n -- t)
; Return true if n is zero
_zequal     dw _zless
            db 2,'0='
zequal      mov a,sp
            mov a,[a]
            mov pcz,pc+4
            mov a,#1
            mov a-,#1
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; and ( w w -- w )
; Bitwise and
_and        dw _zequal
            db 3,'and'
and         mov a,sp
            mov t0,[a]
            mov a+,#1
            mov sp,a
            mov a,[a]
            mov a&,t0
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; or ( w w -- w )
; Bitwise inclusive or
_or         dw _and
            db 2,'or'
or          mov a,sp
            mov t0,[a]
            mov a+,#1
            mov sp,a
            mov a,[a]
            mov a|,t0
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; xor ( w w -- w)
; Bitwise exclusive or
_xor        dw _or
            db 3,'xor'
xor         mov a,sp
            mov t0,[a]
            mov a+,#1
            mov sp,a
            mov a,[a]
            mov a^,t0
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; um+ ( w w -- w cy )
; Add two numbers, return the sum and carry flag
_uplus      dw _xor
            db 2,'um+'
uplus       mov a,sp
            mov t0,[a]
            mov a+,#1
            mov a,[a]
            mov a+,t0
            mov t0,a
            mov a,sp
            mov [a],#1
            mov pcc,pc+4
            mov [a],#0
            mov a+,#1
            mov [a],t0
            mov pc,$next

; 1+ ( a -- a+1 )
; Increment top item
_onep       dw _uplus
            db 2,'1+'
onep        mov a,sp
            mov a,[a]
            mov a+,#1
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; 1- ( a -- a-1 )
; Decrement top item
_onem       dw _onep
            db 2,'1-'
onem        mov a,sp
            mov a,[a]
            mov a-,#1
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; 2/ ( w - w/2 )
; Divide the top item by two
_twod       dw _onem
            db 2,'2/'
twod        mov a+,#0           ; Clear carry
            mov a,sp
            mov a>>,[a]
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; 2* ( w - w*2 )
; Multiply the top item by two
_twom       dw _twod
            db 2,'2*'
twom        mov a,sp
            mov a,[a]
            mov a+,a
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; cold ( -- )
; The hi-level cold start sequence
_cold       dw _twom
            db 4,'cold'
cold        mov t0,pc+4
            mov pc,dolist

            dw rpsto,spsto    ; Bodge for now

            
            dw dolit,10,base,store          ; Set decimal radix
            dw dolit,endofdict,twom,dp,store     ; Set end of dictionary
            

            dw cr,dotqp
            db 14,'eForth MISC-16'

            
            dw cr,dolit,20,tor
lp1         dw rat,dolit,10,negate,plus,dot
            dw donext,lp1

            dw dolit,16,base,store
            dw dolit,0x1234,cr,dot,cr

        
endloop     dw branch,endloop



            
            dw cr,exit

; cr ( -- )
; Output a carriage return and a line feed
_cr         dw _cold
            db 2,'cr'
cr          mov t0,pc+4
            mov pc,dolist
            dw dolit,13,emit,dolit,10,emit,exit

; space ( -- )
; Send the blank character to the output device
_space      dw _cr
            db 5,'space'
space       mov t0,pc+4
            mov pc,dolist
            dw dolit,32,emit,exit

; + ( w w -- sum )
; Add the top two items
_plus       dw _space
            db 1,'+'
plus        mov t0,pc+4
            mov pc,dolist
            dw uplus,drop,exit

; type ( b u -- )
; Output u characters from b
_type       dw _plus
            db 4,'type'
type        mov t0,pc+4
            mov pc,dolist
            dw tor,branch,type2
type1       dw dup,cat,emit,onep
type2       dw donext,type1,drop,exit

; count ( b - b+1 u )
; Return byte count of a string and add 1 to byte address
_count      dw _type
            db 5,'count'
count       mov t0,pc+4
            mov pc,dolist
            dw dup,onep,swap,cat,exit

; do$ ( -- b )
; Return the address of a compiled string
_dostr      dw _count
            db 0x83,'do$'
dostr       mov t0,pc+4
            mov pc,dolist
            dw rfrom,rfrom,twom,dup,count,plus
            dw onep,twod,tor,swap,tor,exit

; ."| ( -- )
; Output a compiled string; run time routine of ."
_dotqp      dw _dostr
            db 0x83,'."|'
dotqp       mov t0,pc+4
            mov pc,dolist
            dw dostr,count,type,exit

; base ( -- a )
; Return address of variable 'base' (radix for numeric I/O)
_base       dw _dotqp
            db 4,'base'
base        mov t0,pc+4
            mov pc,dolist
            dw dovar,0,exit

; hld ( -- a)
; Return address of variable 'hld' (hold address used during construction of numeric output strings)
_hld        dw _base
            db 3,'hld'
hld         mov t0,pc+4
            mov pc,dolist
            dw dovar,0,exit

; dp ( -- a)
; Return address of variable 'dp' (Dictionary Pointer, next free address in dictionary)
_dp         dw _hld
            db 2,'dp'
dp          mov t0,pc+4
            mov pc,dolist
            dw dovar,0,exit

; here ( -- a)
; Return next free address in dictionary
_here       dw _dp
            db 4,'here'
here        mov t0,pc+4
            mov pc,dolist
            dw dp,at,exit

; pad ( -- a)
; Return address of temporary text buffer
_pad        dw _here
            db 3,'pad'
pad         mov t0,pc+4
            mov pc,dolist
            dw here,dolit,80,plus,exit

; <#  ( -- )
; Initiate the numeric output process (store the address of the text buffer in hld)
_bdigs      dw _pad
            db 2,'<#'
bdigs       mov t0,pc+4
            mov pc,dolist
            dw pad,hld,store,exit

; 2dup ( w1 w2 -- w1 w2 w1 w2 )
; Duplicate top two items
_ddup       dw _bdigs
            db 4,'2dup'
ddup        mov t0,pc+4
            mov pc,dolist
            dw over,over,exit

; not ( w -- w )
; One's complement top item
_not        dw _ddup
            db 3,'not'
not         mov t0,pc+4
            mov pc,dolist
            dw dolit,-1,xor,exit

; negate ( w -- -w)
; Two's complement top item
_negate     dw _not
            db 5,'negate'
negate      mov t0,pc+4
            mov pc,dolist
            dw not,onep,exit

; - ( w1 w2 -- w1-w2  )
; Subtract the top two items
_sub        dw _negate
            db 1,'-'
sub         mov t0,pc+4
            mov pc,dolist
            dw negate,plus,exit

; u<  ( u u -- t )
; Unsigned compare of top two items
_uless      dw _sub
            db 2,'u<'
uless       mov t0,pc+4
            mov pc,dolist
            dw ddup,xor,zless,qbranch,uless1
            dw swap,drop,zless,exit
uless1      dw sub,zless,exit

; 2drop ( w w -- )
; Discard two items on stack
_ddrop      dw _uless
            db 5,'2drop'
ddrop       mov t0,pc+4
            mov pc,dolist
            dw drop,drop,exit

; um/mod ( udl udh u -- ur uq )
; Unsigned divide of a double by a single. Return mod and quotient
_ummod      dw _ddrop
            db 6,'um/mod'
ummod       mov a,sp
            mov t0,[a]      ; u
            mov a+,#1
            mov t1,[a]      ; udh
            mov a+,#1
            mov t2,[a]      ; udl
            mov a,#16       ; Setup 16 interation loop
            mov t3,a
um1         mov a,t1        ; Left shift udh
            mov a+,t1
            mov t1,a
            mov a,t2        ; Left shift udl
            mov a+,t2
            mov t2,a
            mov a,t1        ; Add carry to udh
            mov pcc,pc+4
            mov pc,pc+4
            mov a+,#1
            mov t1,a
            mov a-,t0       ; Subtract U from udh
            mov pcc,#um2    ; Skip if borrow
            mov t1,a        ; Update udh
            mov a,t2
            mov a+,#1       ; Add bit to udl
            mov t2,a
um2         mov a,t3        ; Decrement loop counter
            mov a-,#1
            mov t3,a
            mov pcz,pc+4
            mov pc,#um1     ; Loop
            mov a,sp        ; End loop
            mov a+,#1       ; Decrement stack
            mov sp,a
            mov [a],t2      ; Quotent
            mov a+,#1
            mov [a],t1      ; Remainder
            mov pc,$next
#um1        dw um1            
#um2        dw um2

; < ( n1 n2 -- t )
; Signed compare of top two items
_less       dw _ummod
            db 1,'<'
less        mov t0,pc+4
            mov pc,dolist
            dw ddup,xor,zless
            dw qbranch,less1
            dw drop,zless,exit
less1       dw sub,zless,exit

; digit ( u -- c )
; Convert digit u to a character
_digit      dw _less
            db 5,'digit'
digit       mov t0,pc+4
            mov pc,dolist
            dw dolit,9,over,less
            dw dolit,7,and,plus
            dw dolit,'0',plus,exit

; extract ( n base -- n c )
; Extract the least significant digit from n
_extract    dw _digit
            db 7,'extract'
extract     mov t0,pc+4
            mov pc,dolist
            dw dolit,0,swap,ummod
            dw swap,digit,exit

; hold ( c -- )
; Insert a character into the numeric output string
_hold       dw _extract
            db 4,'hold'
hold        mov t0,pc+4
            mov pc,dolist
            dw hld,at,onem,dup,hld,store,cstore,exit

; # ( u -- u )
; Extract one digit from u and append the digit to output string
_dig        dw _hold
            db 1,'#'
dig         mov t0,pc+4
            mov pc,dolist
            dw base,at,extract,hold,exit

; #s ( u -- 0 )
; Convert u until all digits are added to the output string.
_digs       dw _dig
            db 2,'#s'
digs        mov t0,pc+4
            mov pc,dolist
digs1       dw dig,dup,qbranch,digs2
            dw branch,digs1
digs2       dw exit

; sign ( n -- )
; Add a minus sign to the numeric output string
_sign       dw _digs
            db 4,'sign'
sign        mov t0,pc+4
            mov pc,dolist
            dw zless,qbranch,sign1
            dw dolit,'-',hold
sign1       dw exit

; #> ( w -- b u )
; Prepare the output string to be TYPE'd.
_edigs      dw _sign
            db 2,'#>'
edigs       mov t0,pc+4
            mov pc,dolist
            dw drop,hld,at,pad,over,sub,exit    

; u. ( u -- )
; Display an unsigned integer in free format
_udot       dw _edigs
            db 2,'u.'
udot        mov t0,pc+4
            mov pc,dolist
            dw bdigs,digs,edigs,space,type,exit

; abs ( n -- n )
; Return the absolute value of n
_abs        dw _udot
            db 3,'abs'
abs         mov t0,pc+4
            mov pc,dolist
            dw dup,zless
            dw qbranch,abs1
            dw negate
abs1        dw exit

; str ( n -- b u )
; Convert a signed integer to a numeric string
_str        dw _abs
            db 3,'str'
str         mov t0,pc+4
            mov pc,dolist
            dw dup,tor,abs,bdigs,digs,rfrom,sign,edigs,exit

; . ( w -- )
; Display an integer in free format, preceeded by a space
_dot        dw _str
            db 1,'.'
dot         mov t0,pc+4
            mov pc,dolist
            dw base,at,dolit,10,xor
            dw qbranch,dot1
            dw udot,exit
dot1        dw str,space,type,exit

            
endofdict   dw 0
; End of file
