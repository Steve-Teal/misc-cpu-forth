hex
fffa constant time
create moves 2 , 50 , -2 , -50 , 
variable head-ptr
variable tail-ptr
variable direction
variable txt-pos
variable txt-col
variable score
variable seed
: title-txt s" Gforth Snake" ;
: gover-txt s" Game Over   " ;
: lfsr dup 1 lshift swap 0 < if 2d xor then ; 
: randomize time dup 0= if drop 1 then @ seed ! ;
: rnd seed @ lfsr dup seed ! ;
: ?lay-egg rnd c8 mod 0= ;
: def-segs 9800 97e0 do 9488 i 8 move 8 +loop ;
: next-head direction @ cells moves + @ head-ptr @ + ;
: move-head direction @ ffc + head-ptr @ !
  next-head head-ptr ! afc head-ptr @ ! ;  
: move-tail tail-ptr @ dup 1 + c@ fc - 2
  * moves + @ tail-ptr +! 
  ?lay-egg if f97 else 0 then swap ! ;
: init-snake 8488 dup head-ptr ! tail-ptr !
  0 direction ! move-head ;    
: horz-bar 2 * over + swap do dup i ! loop drop ;
: vert-bar 50 * over + swap do
  dup i ! 50 +loop drop ;
: border 
  0 8000 28 horz-bar
  0ad0 8050 28 horz-bar
  0ad0 8050 1e vert-bar
  0ad0 8910 28 horz-bar
  0ad0 809e 1e vert-bar ;
: clr-field 8912 80a2 do 0
  i 26 horz-bar 50 +loop ;
: vemit txt-col @ + txt-pos @ !
  2 txt-pos +! ;   
: vtype 0 do dup c@ vemit 1+ loop drop ;  
: pad-score score @ 0 <# # # # # #> ;
: disp-score pad-score 8048 txt-pos ! vtype ;
: title 8000 txt-pos ! title-txt vtype ;
: game-over 8000 txt-pos ! gover-txt vtype ;
: score-txt 803c txt-pos ! s" Score " vtype ;
: init-screen 0f00 txt-col ! border score-txt ;
: init-score 0 score ! disp-score ;
: add-point 1 score +! disp-score ;
: rnd-food rnd 488 mod 2 * 8050 + ; 
: ?free-spot dup @ if dup - else -1 then ; 
: place-food begin rnd-food ?free-spot until
  0a9a swap ! ; 
: wait-key begin key ?dup until ;
: new-game clr-field init-score title
  init-snake place-food ;
: wait-ms time @ + begin dup time @ = until drop ; 
: loop-delay 64 wait-ms ;
: move-snake move-head move-tail ;
: grow-snake move-head add-point place-food ;
: ?game-over next-head @ dup
  0= if move-snake drop 0 exit then
  a9a = if grow-snake 0 exit then -1 ;
: new-direction direction @ = if drop exit then 
  direction ! ; 
: user-input key
  dup 38 = if 3 1 new-direction drop exit then
  dup 36 = if 0 2 new-direction drop exit then 
  dup 32 = if 1 3 new-direction drop exit then  
  34 = if 2 0 new-direction exit then ;
: snake decimal def-segs randomize init-screen
  begin new-game
  begin wait-key 20 = until 
  begin loop-delay user-input ?game-over until
  game-over wait-key 1b = until ;

