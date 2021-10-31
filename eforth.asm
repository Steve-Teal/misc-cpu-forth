

; MISC-16 eForth port

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

; Data and return stack

rp0         dw rp0
            org 0x100
underflow   dw 0,0,0,0
sp0         dw underflow

; Terminal input buffer

tibb        org 0x12d

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

            dw 0
_execute    db 7,'execute'
execute     mov a,sp
            mov t0,[a]
            mov a+,#1
            mov sp,a
            mov pc,t0

; exit ( -- )
; Terminate a a colon definition
            dw _execute
_exit       db 4,'exit'
exit        mov a,rp
            mov ip,[a]
            mov a-,#1
            mov rp,a
            mov pc,$next

; emit ( c -- )
; Send character c to the output device.
            dw _exit
_emit       db 4,'emit'
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
            dw _emit
_key        db 3,'key'
key         mov t0,pc+2         ; Load t0 with address of next instruction
            mov a>>,?rx         ; Shift receive empty bit into carry
            mov pcc,t0          ; Loop to previous instruction if carry set
            mov a,sp 
            mov a-,#1           ; Increment stack pointer
            mov sp,a            ; Store stack pointer
            mov [a],rx          ; Push character onto stack
            mov pc,$next

; ?key ( -- F | c T )
; Return true and input character or false if no character received
            dw _key
_qkey       db 4,'?key'
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
            dw _qkey
_store      db 1,'!'
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
            dw _store
_at         db 1,'@'
at          mov a+,#0
            mov a,sp
            mov a>>,[a]
            mov t0,[a]
            mov a,sp
            mov [a],t0
            mov pc,$next

; c! ( c b -- ) 
; Pop the data stack to byte memory
            dw _at
_cstore     db 2,'c!'
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
            dw _cstore
_cat        db 2,'c@'
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

; rp! ( a -- )
; Set the return stack pointer
            dw _cat
_rpstore    db 3,'rp!'
rpstore     mov a,sp
            mov rp,[a]
            mov a+,#1
            mov sp,a
            mov pc,$next

; rp0 ( -- a )
; Stack initial return pointer value
            dw _rpstore
_rpzero     db 3,'rp0'
rpzero      mov a,sp
            mov a-,#1
            mov sp,a
            mov [a],rp0
            mov pc,$next

; rp@     ( -- a )
; Push the current return stack pointer to the data stack
            dw _rpzero
_rpat       db 3,'rp@'
rpat        mov a,sp
            mov a-,#1
            mov sp,a        ; Update stack pointer
            mov [a],rp      ; Store rp to stack
            mov pc,$next

; r> ( -- w )
; Pop the return stack to the data stack
            dw _rpat
_rfrom      db 2,'r>'
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
            dw _rfrom
_rat        db 2,'r@'
rat         mov a,rp
            mov t0,[a]      ; Read return stack to t0
            mov a,sp        
            mov a-,#1
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Store value to stack
            mov pc,$next

; >r ( w -- )
; Push the data stack to the return stack
            dw _rat
_tor        db 2,'>r'
tor         mov a,sp
            mov t0,[a]      ; Read stack to t0
            mov a+,#1
            mov sp,a        ; Update stack pointer
            mov a,rp
            mov a+,#1       
            mov rp,a        ; Update return stack pointer
            mov [a],t0      ; Store value to return stack
            mov pc,$next

; sp! ( a -- )
; Set the data stack pointer
            dw _tor
_spstore    db 3,'sp!'
spstore     mov a,sp
            mov sp,[a]
            mov pc,$next

; sp0 ( a -- )
; Initial data stack value
            dw _spstore
_spzero     db 3,'sp0'
spzero      mov a,sp
            mov a-,#1
            mov sp,a
            mov [a],sp0
            mov pc,$next

; sp@ ( -- a )
; Push the current data stack pointer
            dw _spzero
_spat       db 3,'sp@'
spat        mov t0,sp       ; Current stack pointer
            mov a,sp
            mov a-,#1       ; Increment stack point   
            mov sp,a
            mov [a],t0      ; Store previous stack pointer on stack
            mov pc,$next

; drop ( w -- )
; Discard top stack item
            dw _spat
_drop       db 4,'drop'
drop        mov a,sp
            mov a+,#1
            mov sp,a
            mov pc,$next

; dup ( w -- w w )
; Duplicate the top stack item
            dw _drop
_dup        db 3,'dup'
dup         mov a,sp
            mov t0,[a]      ; Read stack to t0
            mov a-,#1
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Write value to stack
            mov pc,$next

; swap ( w1 w2 -- w2 w1 )
; Exchange top two stack items
            dw _dup
_swap       db 4,'swap'
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
            dw _swap
_over       db 4,'over'
over        mov a,sp
            mov a+,#1
            mov t0,[a]      ; Read next on stack to t0
            mov a-,#2
            mov sp,a        ; Update stack pointer
            mov [a],t0      ; Store t0 to stack
            mov pc,$next

; pick ( ... +n -- ... w )
; Copy the nth stack item to tos
            dw _over
_pick       db 4,'pick'
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
            dw _pick
_depth      db 5,'depth'
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
            dw _depth
_zless      db 2,'0<'
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
            dw _zless
_zequal     db 2,'0='
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
            dw _zequal
_and        db 3,'and'
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
            dw _and
_or         db 2,'or'
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
            dw _or
_xor        db 3,'xor'
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
            dw _xor
_uplus      db 3,'um+'
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
            dw _uplus
_onep       db 2,'1+'
onep        mov a,sp
            mov a,[a]
            mov a+,#1
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; 1- ( a -- a-1 )
; Decrement top item
            dw _onep
_onem       db 2,'1-'
onem        mov a,sp
            mov a,[a]
            mov a-,#1
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; 2/ ( w - w/2 )
; Divide the top item by two
            dw _onem
_twod       db 2,'2/'
twod        mov a+,#0           ; Clear carry
            mov a,sp
            mov a>>,[a]
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; 2* ( w - w*2 )
; Multiply the top item by two
            dw _twod
_twom       db 2,'2*'
twom        mov a,sp
            mov a,[a]
            mov a+,a
            mov t0,a
            mov a,sp
            mov [a],t0
            mov pc,$next

; dovar ( -- a )
; Run time routine for variable and create
            dw _twom
_dovar      db 5,'dovar'
dovar       mov t0,pc+4
            mov pc,dolist
            dw rfrom,twom,exit

; cold ( -- )
; The hi-level cold start sequence
            dw _dovar
_cold       db 4,'cold'
cold        mov rp,rp0
            mov sp,sp0
            mov t0,pc+4
            mov pc,dolist


            
            dw dolit,10,base,store          ; Set decimal radix
            dw dolit,endofdict,twom,dp,store     ; Set end of dictionary

            dw dolit,_quit,twom,last,store,overt

           
            

            dw cr,dotqp
            db 14,'eForth MISC-16'
            
            





            
endlp       dw quit,branch,endlp


; cr ( -- )
; Output a carriage return and a line feed
            dw _cold
_cr         db 2,'cr'
cr          mov t0,pc+4
            mov pc,dolist
            dw dolit,13,emit,dolit,10,emit,exit

; space ( -- )
; Send the blank character to the output device
            dw _cr
_space      db 5,'space'
space       mov t0,pc+4
            mov pc,dolist
            dw dolit,32,emit,exit

; equal ( w w -- f )
; Return true if the top two items are equal
            dw _space
_equal      db 1,'='
equal       mov t0,pc+4
            mov pc,dolist
            dw xor,qbranch,equal1
            dw dolit,0,exit
equal1      dw dolit,-1,exit

; + ( w w -- sum )
; Add the top two items
            dw _equal
_plus       db 1,'+'
plus        mov t0,pc+4
            mov pc,dolist
            dw uplus,drop,exit

; type ( b u -- )
; Output u characters from b
            dw _plus
_type       db 4,'type'
type        mov t0,pc+4
            mov pc,dolist
            dw tor,branch,type2
type1       dw dup,cat,emit,onep
type2       dw donext,type1,drop,exit

; count ( b - b+1 u )
; Return byte count of a string and add 1 to byte address
            dw _type
_count      db 5,'count'
count       mov t0,pc+4
            mov pc,dolist
            dw dup,onep,swap,cat,exit

; do$ ( -- b )
; Return the address of a compiled string
            dw _count
_dostr      db 0x83,'do$'
dostr       mov t0,pc+4
            mov pc,dolist
            dw rfrom,rfrom,twom,dup,count,plus
            dw onep,twod,tor,swap,tor,exit

; ."| ( -- )
; Output a compiled string; run time routine of ."
            dw _dostr
_dotqp      db 0x83,'."|'
dotqp       mov t0,pc+4
            mov pc,dolist
            dw dostr,count,type,exit

; base ( -- a )
; Variable base (radix for numeric I/O)
            dw _dotqp
_base       db 4,'base'
base        mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; hld ( -- a )
; Variable hld (hold address used during construction of numeric output strings)
            dw _base
_hld        db 3,'hld'
hld         mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; dp ( -- a )
; Variable dp (Dictionary Pointer, next free address in dictionary)
            dw _hld
_dp         db 2,'dp'
dp          mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; here ( -- a )
; Return next free address in dictionary
            dw _dp
_here       db 4,'here'
here        mov t0,pc+4
            mov pc,dolist
            dw dp,at,exit

; pad ( -- a )
; Return address of temporary text buffer
            dw _here
_pad        db 3,'pad'
pad         mov t0,pc+4
            mov pc,dolist
            dw here,dolit,80,plus,exit

; <#  ( -- )
; Initiate the numeric output process (store the address of the text buffer in hld)
            dw _pad
_bdigs      db 2,'<#'
bdigs       mov t0,pc+4
            mov pc,dolist
            dw pad,hld,store,exit

; 2dup ( w1 w2 -- w1 w2 w1 w2 )
; Duplicate top two items
            dw _bdigs
_ddup       db 4,'2dup'
ddup        mov t0,pc+4
            mov pc,dolist
            dw over,over,exit

; not ( w -- w )
; One's complement top item
            dw _ddup
_not        db 3,'not'
not         mov t0,pc+4
            mov pc,dolist
            dw dolit,-1,xor,exit

; negate ( w -- -w)
; Two's complement top item
            dw _not
_negate     db 6,'negate'
negate      mov t0,pc+4
            mov pc,dolist
            dw not,onep,exit

; dnegate ( d -- -d)
; Two's compliment top two items as a double integer
            dw _negate
_dnegate    db 7,'dnegate'
dnegate     mov t0,pc+4
            mov pc,dolist
            dw not,tor,not          ; Complement 
            dw dolit,1,uplus        ; Add 1 to low item
            dw rfrom,plus,exit      ; Add carry to high item

; - ( w1 w2 -- w1-w2  )
; Subtract the top two items
            dw _dnegate
_sub        db 1,'-'
sub         mov t0,pc+4
            mov pc,dolist
            dw negate,plus,exit

; u<  ( u u -- t )
; Unsigned compare of top two items
            dw _sub
_uless      db 2,'u<'
uless       mov t0,pc+4
            mov pc,dolist
            dw ddup,xor,zless,qbranch,uless1
            dw swap,drop,zless,exit
uless1      dw sub,zless,exit

; 2drop ( w w -- )
; Discard two items on stack
            dw _uless
_ddrop      db 5,'2drop'
ddrop       mov t0,pc+4
            mov pc,dolist
            dw drop,drop,exit

; um* ( u u -- ud)
; Unsigned multiply. Return double product
            dw _ddrop
_umstar     db 3,'um*'
umstar      mov a,sp
            mov t0,[a]
            mov a+,#1
            mov t1,[a]
            mov t2,#0
            mov t3,#16          ; Setup 16 interation loop
umstar1     mov a,t2            ; Left shift t1:t2 into carry
            mov a+,t2
            mov t2,a
            mov a,t1
            mov pcc,pc+6
            mov a+,t1
            mov pc,pc+6
            mov a+,t1
            mov a|,#1
            mov t1,a
            mov pcc,pc+4        ; If carry
            mov pc,#umstar2
            mov a,t0            ; Add t0 to t2
            mov a+,t2
            mov t2,a
            mov pcc,pc+4        ; If carry
            mov pc,#umstar2    
            mov a,t1            ; Add 1 to t1
            mov a+,#1
            mov t1,a
umstar2     mov a,t3            ; Decrement t3
            mov a-,#1
            mov pcz,pc+6        ; If not zero
            mov t3,a
            mov pc,#umstar1     ; Loop
            mov a,sp
            mov [a],t1          ; Copy MS of product to top of stack
            mov a+,#1
            mov [a],t2          ; Copy LS of prodyct to next on stack
            mov pc,$next
#umstar1    dw umstar1
#umstar2    dw umstar2

; um/mod ( udl udh u -- ur uq )
; Unsigned divide of a double by a single. Return mod and quotient
            dw _umstar
_ummod      db 6,'um/mod'
ummod       mov a,sp
            mov t0,[a]      ; u
            mov a+,#1
            mov t1,[a]      ; udh
            mov a+,#1
            mov t2,[a]      ; udl
            mov t3,#16      ; Setup 16 interation loop
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

; * ( u u -- u )
; Multiply two items to produce a signed single integer product
            dw _ummod
_star       db 1,'*'
star        mov t0,pc+4
            mov pc,dolist
            dw umstar,drop,exit

; m* ( n n -- d )
; Signed multiply return double product
            dw _star
_mstar      db 2,'m*'
            mov t0,pc+4
            mov pc,dolist
            dw ddup,xor,zless,tor
            dw abs,swap,abs,umstar
            dw rfrom,qbranch,mstar1
            dw dnegate
mstar1      dw exit

; m/mod ( d n -- r q )
; Signed floored divide of double by single. Return mod and quotient.
            dw _mstar
_msmod      db 5,'m/mod'
msmod       mov t0,pc+4
            mov pc,dolist
            dw dup,zless,dup,tor
            dw qbranch,msmod1
            dw negate,tor,dnegate,rfrom
msmod1      dw tor,dup,zless
            dw qbranch,msmod2
            dw rat,plus
msmod2      dw rfrom,ummod,rfrom
            dw qbranch,msmod3
            dw swap,negate,swap
msmod3      dw exit

; /mod ( n n -- r q )
; Signed divide. Return mod and quotient
            dw _msmod
_slmod      db 4,'/mod'
slmod       mov t0,pc+4
            mov pc,dolist
            dw over,zless,swap,msmod,exit

; mod ( n n -- r )
; Signed divide. Return mod only
            dw _slmod
_mod        db 3,'mod'
mod         mov t0,pc+4
            mov pc,dolist
            dw slmod,drop,exit

; / ( n n -- q )
; Signed divide. Return quotient only
            dw _mod
_slash      db 1,'/'
slash       mov t0,pc+4
            mov pc,dolist
            dw slmod,swap,drop,exit

; < ( n1 n2 -- t )
; Signed compare of top two items
            dw _slash
_less       db 1,'<'
less        mov t0,pc+4
            mov pc,dolist
            dw ddup,xor,zless
            dw qbranch,less1
            dw drop,zless,exit
less1       dw sub,zless,exit

; digit ( u -- c )
; Convert digit u to a character
            dw _less
_digit      db 5,'digit'
digit       mov t0,pc+4
            mov pc,dolist
            dw dolit,9,over,less
            dw dolit,39,and,plus
            dw dolit,'0',plus,exit

; extract ( n base -- n c )
; Extract the least significant digit from n
            dw _digit
_extract    db 7,'extract'
extract     mov t0,pc+4
            mov pc,dolist
            dw dolit,0,swap,ummod
            dw swap,digit,exit

; hold ( c -- )
; Insert a character into the numeric output string
            dw _extract
_hold       db 4,'hold'
hold        mov t0,pc+4
            mov pc,dolist
            dw hld,at,onem,dup,hld,store,cstore,exit

; # ( u -- u )
; Extract one digit from u and append the digit to output string
            dw _hold
_dig        db 1,'#'
dig         mov t0,pc+4
            mov pc,dolist
            dw base,at,extract,hold,exit

; #s ( u -- 0 )
; Convert u until all digits are added to the output string.
            dw _dig
_digs       db 2,'#s'
digs        mov t0,pc+4
            mov pc,dolist
digs1       dw dig,dup,qbranch,digs2
            dw branch,digs1
digs2       dw exit

; sign ( n -- )
; Add a minus sign to the numeric output string
            dw _digs
_sign       db 4,'sign'
sign        mov t0,pc+4
            mov pc,dolist
            dw zless,qbranch,sign1
            dw dolit,'-',hold
sign1       dw exit

; #> ( w -- b u )
; Prepare the output string to be TYPE'd.
            dw _sign
_edigs      db 2,'#>'
edigs       mov t0,pc+4
            mov pc,dolist
            dw drop,hld,at,pad,over,sub,exit    

; u. ( u -- )
; Display an unsigned integer in free format
            dw _edigs
_udot       db 2,'u.'
udot        mov t0,pc+4
            mov pc,dolist
            dw bdigs,digs,edigs,space,type,exit

; abs ( n -- n )
; Return the absolute value of n
            dw _udot
_abs        db 3,'abs'
abs         mov t0,pc+4
            mov pc,dolist
            dw dup,zless
            dw qbranch,abs1
            dw negate
abs1        dw exit

; str ( n -- b u )
; Convert a signed integer to a numeric string
            dw _abs
_str        db 3,'str'
str         mov t0,pc+4
            mov pc,dolist
            dw dup,tor,abs,bdigs,digs,rfrom,sign,edigs,exit

; . ( w -- )
; Display an integer in free format, preceeded by a space
            dw _str
_dot        db 1,'.'
dot         mov t0,pc+4
            mov pc,dolist
            dw base,at,dolit,10,xor
            dw qbranch,dot1
            dw udot,exit
dot1        dw str,type,space,exit

; ? ( a -- )
; Display the contents in a memory cell
            dw _dot
_quest      db 1,'?'
quest       mov t0,pc+4
            mov pc,dolist
            dw at,dot,exit

; hex ( -- )
; Use radix 16 as base for numeric conversions
            dw _quest
_hex        db 3,'hex'
hex         mov t0,pc+4
            mov pc,dolist
            dw dolit,16,base,store,exit

; decimal ( -- )
; Use radix 10 as base for numeric conversions
            dw _hex
_decimal    db 7,'decimal'
decimal     mov t0,pc+4
            mov pc,dolist
            dw dolit,10,base,store,exit

; max ( n1 n2 -- n )
; Return the greater of two top stack items
            dw _decimal
_max        db 3,'max'
max         mov t0,pc+4
            mov pc,dolist
            dw ddup,less,qbranch,max1
            dw swap
max1        dw drop,exit

; min ( n1 n2 -- n )
; Return the smaller of top two stack items
            dw _max
_min        db 3,'min'
min         mov t0,pc+4
            mov pc,dolist
            dw ddup,swap,less,qbranch,min1
            dw swap
min1        dw drop,exit

; within ( u ul uh -- t )
; Return true if u is within the range of ul and uh; ul<=u<uh.)
            dw _min
_within     db 6,'within'
within      mov t0,pc+4
            mov pc,dolist
            dw over,sub,tor,sub,rfrom,uless,exit

; spaces  ( n -- )
; Send n spaces to the output device
            dw _within
_spaces     db 6,'spaces'
spaces      mov t0,pc+4
            mov pc,dolist
            dw dolit,0,max,tor
            dw branch,spaces2
spaces1     dw space
spaces2     dw donext,spaces1,exit

; .r ( n +n -- )
; Display an integer in a field of n columns, right justified
            dw _spaces
_dotr       db 2,'.r'
dotr        mov t0,pc+4
            mov pc,dolist
            dw tor,str,rfrom,over,sub
            dw spaces,type,exit

; u.r ( u +n -- )
; Display an unsigned integer in n column, right justified
            dw _dotr
_udotr      db 3,'u.r'
udotr       mov t0,pc+4
            mov pc,dolist
            dw tor,bdigs,digs,edigs
            dw rfrom,over,sub
            dw spaces,type,exit

; tib ( -- a )
; Return the address of the terminal input buffer
            dw _udotr
_tib        db 3,'tib'
tib         mov t0,pc+4
            mov pc,dolist
            dw dolit,tibb,twom,exit

; tibl ( -- n )
; Return the length of the terminal input buffer
            dw _tib
_tibl       db 4,'tibl'
tibl        mov t0,pc+4
            mov pc,dolist
            dw dolit,sp,twom,tib,sub,exit

; #tib ( -- a )
; Variable #tib (the current count of the terminal input buffer)
            dw _tibl
_ntib       db 4,'#tib'
ntib        mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; ^h ( bot eot cur -- bot eot cur )
; Backup the cursor by one character
            dw _ntib
_bksp       db 2,'^h'
bksp        mov t0,pc+4
            mov pc,dolist
            dw tor,over,rfrom,swap,over,xor
            dw qbranch,bksp1
            dw dolit,8,dup,emit,space,emit
            dw onem
bksp1       dw exit

; tap ( bot eot cur c -- bot eot cur )
; Accept and echo the key stroke and bump the cursor
            dw _bksp
_tap        db 3,'tap'
tap         mov t0,pc+4
            mov pc,dolist
            dw dup,emit,over,cstore,onep,exit

; ktap ( bot eot cur c -- bot eot cur )
; Process a key stroke, CR or backspace
            dw _tap
_ktap       db 4,'ktap'
ktap        mov t0,pc+4
            mov pc,dolist
            dw dup,dolit,13,xor
            dw qbranch,ktap1
            dw dolit,8,xor
            dw qbranch,ktap2
            dw bl,tap,exit
ktap1       dw space,drop,swap,drop,dup,exit
ktap2       dw bksp,exit

; bl ( -- 32 )
; Return 32, the blank character
            dw _ktap
_bl         db 2,'bl'
bl          mov t0,pc+4
            mov pc,dolist
            dw dolit,32,exit

; accept  ( b u -- b u )
; Accept characters to input buffer. Return with actual count
            dw _bl
_accept     db 6,'accept'
accept      mov t0,pc+4
            mov pc,dolist
            dw over,plus,over
accept1     dw ddup,xor,qbranch,accept4
            dw key,dup
            dw bl,dolit,127,within
            dw qbranch,accept2
            dw tap
            dw branch,accept3
accept2     dw ktap
accept3     dw branch,accept1
accept4     dw drop,over,sub,exit

; >in ( -- a )
; Variable >in (character pointer while parsing input stream)
            dw _accept
_inn        db 2,'>in'
inn         mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; query ( -- )
; Accept input stream to terminal input buffer and initialize parsing pointer
            dw _inn
_query      db 5,'query'
query       mov t0,pc+4
            mov pc,dolist
            dw tib,tibl,accept,ntib,store
            dw drop,dolit,0,inn,store,exit

; +! ( n a -- )
; Add n to the contents at address a
            dw _query
_pstore     db 2,'+!'
pstore      mov t0,pc+4
            mov pc,dolist
            dw swap,over,at,plus,swap,store,exit

; cell+ ( w -- w )
; Add cell size in bytes to top item
            dw _pstore
_cellp      db 5,'cell+'
cellp       mov t0,pc+4
            mov pc,dolist
            dw dolit,2,plus,exit

; cell- ( w -- w )
; Subtract cell size in bytes from top item
            dw _cellp
_cellm      db 5,'cell-'
cellm       mov t0,pc+4
            mov pc,dolist
            dw dolit,2,sub,exit

; ?dup ( w -- w w | 0 )
; Duplicate item if its is not zero
            dw _cellm
_qdup       db 4,'?dup'
qdup        mov t0,pc+4
            mov pc,dolist
            dw dup,qbranch,qdup1,dup
qdup1       dw exit

; 'eval ( -- a )
; Variable 'eval (execution vector of eval)
            dw _qdup
_teval      db 5,39,'eval'
teval       mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; context ( -- a )
; Variable context (Pointer to name field of last command in dictionary)
            dw _teval
_context    db 7,'context'
context     mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; last ( -- a )
; Variable last (Pointer to name field of last command in dictionary)
            dw _context
_last       db 4,'last'
last        mov t0,pc+4
            mov pc,dolist
            dw dovar,0

; overt ( -- )
; Link a successfully defined word into the dictionary
            dw _last
_overt      db 5,'overt'
overt       mov t0,pc+4
            mov pc,dolist
            dw last,at,context,store,exit

; digit?  ( c base -- u t )
; Convert a character to its numeric value. A flag indicates success
            dw _overt
_digitq     db 6,'digit?'
digitq      mov t0,pc+4
            mov pc,dolist
            dw tor,dolit,'0',sub
            dw dolit,9,over,less
            dw qbranch,digitq1
            dw dolit,39,sub
            dw dup,dolit,10,less,or
digitq1     dw dup,rfrom,uless,exit

; number? ( a -- n T | a F )
; Convert a number string to integer. Push a flag on tos
            dw _digitq
_numberq    db 7,'number?'
numberq     mov t0,pc+4
            mov pc,dolist
            dw base,at,tor,dolit,0,over,count
            dw over,cat,dolit,'$',equal
            dw qbranch,numberq1
            dw hex,swap,onep,swap,onem
numberq1    dw over,cat,dolit,'-',equal,tor        
            dw swap,rat,sub,swap,rat,plus,qdup
            dw qbranch,numberq6
            dw onem,tor
numberq2    dw dup,tor,cat,base,at,digitq
            dw qbranch,numberq4
            dw swap,base,at,star,plus,rfrom
            dw onep,donext,numberq2
            dw rat,swap,drop
            dw qbranch,numberq3
            dw negate
numberq3    dw swap
            dw branch,numberq5
numberq4    dw rfrom,rfrom,ddrop,ddrop,dolit,0
numberq5    dw dup
numberq6    dw rfrom,ddrop
            dw rfrom,base,store,exit

; cfa ( na -- ca )
; Return code address from name address
            dw _numberq
_cfa        db 3,'cfa'
cfa         mov t0,pc+4
            mov pc,dolist
            dw dup,cat,plus,twod,onep,exit

; sameq ( a a -- a a F )
; Compare two strings return true if they match 
            dw _cfa
_sameq      db 5,'same?'
sameq       mov t0,pc+4
            mov pc,dolist
            dw over,over
            dw dup,cat,dolit,0x3F,and,tor   ; Setup for loop with character count
            dw branch,sameq2                ; Branch for first iteration
sameq1      dw over,cat,over,cat            ; Get string characters
            dw equal,qbranch,sameq3         ; Compare, branch if no match
sameq2      dw onep,swap,onep               ; Increment pointers
            dw donext,sameq1                ; Next
            dw ddrop,dolit,-1,exit          ; Strings match, tidy up and return true
sameq3      dw rfrom,drop                   ; Match failed, cleanup for loop
            dw ddrop,dolit,0,exit           ; Strings don't match tidy up and return false

; name? ( a -- ca na | a F )
; Search dictionary for a string, return code and name field address if found else false
            dw _sameq
_nameq      db 5,'name?'
nameq       mov t0,pc+4
            mov pc,dolist
            dw context,at                   ; Last word in dictionary
nameq1      dw dup,qbranch,nameq2           ; Branch if start of dictionary reached
            dw over,at,over,at              ; First two cells of strings
            dw dolit,0x3fff,and             ; Mask dictionary string compile and immediate flags 
            dw equal,qbranch,nameq3         ; Branch if first cells are not equal
            dw sameq,qbranch,nameq3         ; Branch if strings don't match
            dw swap,drop,dup,cfa,swap       ; Name found, drop search string and push code field address
nameq2      dw exit
nameq3      dw cellm,at,twom,branch,nameq1  ; Move to next word in dictionary 

; $interpret ( a -- )
; Interpret a word. If failed, try to convert it to an integer
            dw _sameq
_interpret  db 10,'$interpret'
interpret   mov t0,pc+4
            mov pc,dolist

            
            dw nameq,qdup,qbranch,interpret1

            dw drop,execute,exit

interpret1  dw numberq,qbranch,interpret2

            dw exit

interpret2  dw space,count,type,dotqp
            db 2,' ?'
            dw quit,exit

; [ ( -- )
; Start the text interpreter
            dw _interpret
_lbracket   db 0x41,'['
lbracket    mov t0,pc+4
            mov pc,dolist
            dw dolit,interpret,teval,store,exit

; tib> ( -- F | c T)
; Return true and the next character from the input buffer or false if the buffer is empty
            dw _lbracket
_tibfrom    db 4,'tib>'
tibfrom     mov t0,pc+4
            mov pc,dolist
            dw inn,at,ntib,at,xor,dup,qbranch,tibfrom1  ; Buffer empty?
            dw tib,inn,at,plus,cat                      ; No, read character
            dw dolit,1,inn,pstore                       ; Increment parsing pointer
            dw swap,zequal,not                          ; True flag
tibfrom1    dw exit                                     

; parse ( c -- b u )
; Scan input stream and return counted string delimited by c

            dw _tibfrom
_parse      db 5,'parse'
parse       mov t0,pc+4
            mov pc,dolist    
            dw tor                              ; Save delimiter 
            dw rat,bl,xor,not,qbranch,parse2    ; Branch if delimiter is not space       
parse1      dw tibfrom,qbranch,parse2           ; Read next character, branch if buffer is empty
            dw bl,xor,qbranch,parse1            ; Loop if character is space
            dw dolit,-1,inn,pstore              ; Backup parsing index to first character after spaces
parse2      dw inn,at,tib,plus                  ; Address of start of string
            dw dolit,0                          ; Initialize character count
parse3      dw tibfrom,qbranch,parse4           ; Read next character, branch if buffer empty
            dw rat,xor,qbranch,parse4           ; Branch if delimeter
            dw onep,branch,parse3               ; Increment character count
parse4      dw rfrom,drop,exit                  ; Remove delimiter from return stack       

; cmove ( b1 b2 u -- )
; Copy u bytes from b1 to b2

            dw _parse
_cmove      db 5,'cmove'
cmove       mov t0,pc+4
            mov pc,dolist
            dw tor
            dw branch,cmove2
cmove1      dw tor,dup,cat
            dw rat,cstore,onep
            dw rfrom,onep
cmove2      dw donext,cmove1
            dw ddrop,exit

; pack$ ( b u a -- a )
; Build a counted string with u characters from b

            dw _cmove
_packs      db 5,'pack$'
packs       mov t0,pc+4
            mov pc,dolist
            dw dup,tor              ; Save address of word buffer
            dw ddup,cstore          ; Store the character count first
            dw onep,ddup,plus       ; Go to the end of the string
            dw dolit,0,swap,store   ; Fill then end with 0's
            dw swap,cmove           ; Copy the string
            dw rfrom,exit           ; Leave only the buffer address

; word ( c -- a )
; Parse a word from the input stream and copy to the dictionary
            dw _packs
_word       db 4,'word'
word        mov t0,pc+4
            mov pc,dolist
            dw parse,here,packs,exit

; atexecute ( a -- )
; Execute vector stored in address a
            dw _word
_atexecute  db 8,'@execute'
atexecute   mov t0,pc+4
            mov pc,dolist
            dw at,qdup              ; Addrees or 0?
            dw qbranch,atexecute1   ; Exit if 0
            dw execute              ; Execute if not 0
atexecute1  dw exit

; qstack
; Abort if the data stack underflows
            dw _atexecute
_qstack     db 6,'?stack'
qstack      mov t0,pc+4
            mov pc,dolist
            dw depth,zless              ; Stack depth < 0?
            dw qbranch,qstack1,dotqp    ; Yes, display error message
            db 16,' stack underflow'
            dw spzero,spstore,quit      ; Reset stack pointer
qstack1     dw exit

; eval ( -- )
; Interpret the input stream
            dw _qstack
_eval       db 4,'eval'
eval        mov t0,pc+4
            mov pc,dolist
eval1       dw bl,word,dup,cat        ; Parse a word
            dw qbranch,eval2          ; Branch if character count is 0
            dw teval,atexecute,qstack ; Evaluate and check for stack underflow
            dw branch,eval1           ; Repeat until word gets a null string
eval2       dw drop,exit              ; Discard string address and display prompt

; words ( -- )
; List all words in dictionary avoiding splitting words at line breaks
            dw _eval
_words      db 5,'words'
words       mov t0,pc+4
            mov pc,dolist
            dw cr,context,at        ; End of dictionary
            dw dolit,0,tor          ; Track characters on current line
words1      dw qdup,qbranch,words2  ; Branch if start of dictionary
            dw dup,count            ; Get string length byte
            dw dolit,0x3f,and       ; Mask immediate and compile flags
            dw dup,rfrom,plus       ; Add character count to tracking count
            dw dolit,64,over,less   ; Less than width of terminal?
            dw qbranch,words3       
            dw drop,cr,dup          ; Yes, start new line and set tracking count to length of word
words3      dw onep,tor             ; Update tracking count and add one for space
            dw type,space           ; Display word followed by space
            dw cellm,at,twom        ; Move to next word in dictionary
            dw branch,words1        
words2      dw rfrom,drop,exit      ; Drop tracking count and exit

; quit ( -- )
; Reset return stack pointer and start text interpreter.
            dw _words
_quit       db 4,'quit'
quit        mov t0,pc+4
            mov pc,dolist
            dw rpzero,rpstore         
            dw cr
            dw lbracket               ; Start interpretation
quit1       
            dw query,eval             ; Get and evaluate input
            dw dotqp
            db 3,' ok'
            dw cr,branch,quit1           ; Continue till error


endofdict   dw 0

; End of file


