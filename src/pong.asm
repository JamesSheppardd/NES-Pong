;---------------------------------------------------------------------------------------------------------;
; ---                                                                                                 --- ; 
; --- TITLE:        Pong                                                                              --- ; 
; --- VERSION:      1.0                                                                               --- ; 
; --- DEVELOPER:    James Sheppard (JamesShepardd on github)                                          --- ; 
; --- LINK:                                                                                           --- ; 
; --- ASSEMBLER:    CA65                                                                              --- ; 
; ---                                                                                                 --- ; 
; --- CONTROLS:                                                                                       --- ; 
; ---           - Player 1:      START to begin game                                                  --- ; 
; ---                            SELECT to end game                                                   --- ; 
; ---           - Both players:  UP/DOWN to move paddle                                               --- ; 
; ---                                                                                                 --- ; 
; --- ABOUT:                                                                                          --- ; 
; --- The first NES game I've developed, following along with the Nerdy Nights tutorials written with --- ; 
; --- the NESASM assembler, so syntax was different. It is just a "Pong" clone, with no sounds and    --- ; 
; --- slightly buggy collision detection. Also my first use of ASM (assembly).                        --- ; 
; ---                                                                                                 --- ;  
;---------------------------------------------------------------------------------------------------------;


.segment "HEADER"
    .byte "NES"
    .byte $1a
    .byte $02
    .byte $01
    .byte %00000001
    .byte $00
    .byte $00
    .byte $00
    .byte $00
    .byte $00, $00, $00, $00, $00

.segment "ZEROPAGE"
    ;; Variables
    gamestate:      .res 1  
    ballx:          .res 1  
    bally:          .res 1
    ballup:         .res 1  ; 1 = ball going up
    balldown:       .res 1  ; 1 = ball going down
    ballleft:       .res 1  ; 1 = ball going left
    ballright:      .res 1  ; 1 = ball going right
    ballspeedx:     .res 1
    ballspeedy:     .res 1
    paddle1ytop:    .res 1
    paddle1ybottom: .res 1
    paddle2ytop:    .res 1
    paddle2ybottom: .res 1
    score1:         .res 1  ; reserve 1 byte of RAM for score1 variable
    score2:         .res 1  ; reserve 1 byte of RAM for score2 variable
    buttons1:       .res 1  ; put controller data for player 1
    buttons2:       .res 1  ; put controller data for player 2 
    paddlespeed:    .res 1
    score1Ones:     .res 1
    score1Tens:     .res 1
    score1Hundreds: .res 1
    score2Ones:     .res 1
    score2Tens:     .res 1
    score2Hundreds: .res 1
    world:          .res 1
    
    ;; Constants
    STATETITLE      = $00   ; is on title screen
    STATEPLAYING    = $01   ; is playing game
    STATEGAMEOVER   = $02   ; is gameover

    RIGHTWALL       = $E9   ; when the ball reaches one of these we'll do some bounce logic
    TOPWALL         = $19
    BOTTOMWALL      = $CD
    LEFTWALL        = $0F

    PADDLE1X        = $15 
    PADDLE2X        = $E3
    ;;;;;;;;;;; 
    BALLSTARTX      = $7B
    BALLSTARTY      = $74

.segment "STARTUP"
.segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Subroutines ;;;
vblankwait: 
    BIT $2002
    BPL vblankwait
    RTS 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup code ;;;
RESET:
    SEI         ; disable IRQs
    CLD         ; disable decimal mode
    LDX #$40
    STX $4017   ; disable APU frame counter 
    LDX #$ff    ; setup the stack
    TXS 
    INX 
    STX $2000   ; disable NMI
    STX $2001   ; disable rendering
    STX $4010   ; disable DMC IRQs

    JSR vblankwait

    TXA         ; make A $00 
clearmem:
    STA $0000,X
    STA $0100,X
    STA $0300,X
    STA $0400,X
    STA $0500,X
    STA $0600,X
    STA $0700,X
    LDA #$FE
    STA $0200,X   ; set aside area in RAM for sprite memory
    LDA #$00
    INX 
    BNE clearmem

    JSR vblankwait

    LDA #$02    ; load A with the high byte for sprite memory
    STA $4014   ; this uploads 256 bytes of data from the CPU page $XX00 - $XXFF (XX is 02 here) to the internal PPU OAM
    NOP         ; takes 513 or 514 CPU cycles, so this basically pauses program I think?

clearnametables:
    LDA $2002   ; reset PPU status
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006
    LDX #$08    ; prepare to fill 8 pages ($800 bytes)
    LDY #$00    ; X/Y is 16-bit counter, bigh byte in X
    LDA #$24    ; fill with tile $24 (sky block)
clearnametableloop:
    STA $2007
    DEY 
    BNE clearnametableloop
    DEX 
    BNE clearnametableloop

loadpalette:
    LDA $2002 
    LDA #$3f
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00
loadpaletteloop:
    LDA palettedata,X
    STA $2007
    INX 
    CPX #$20
    BNE loadpaletteloop

    ; Initialise world to point to world data - around 7:00 in video 
    LDA #<titleworlddata ; Load the high-order byte from the WorldData variable into the accumulator - has to do this way not the entire 2 bytes as accumulator is only 1 byte
    STA world
    LDA #>titleworlddata ; Get the low-order byte to store
    STA world+1 ; Assembler realises that this means store the variable in the 2nd byte of world

    ; setup address in PPU for nametable data
    BIT $2002 ; 15:00 in video - Actually pretty good to relisten to - reading (in this case using BIT) from $2002 basically resets $2006, so writing to $2006 after this for the first time, the program knows you are writing the firat byte of the desired address, discarding any leftovers from previous usage.
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00
    LDY #$00

loadtitlenametable:
    LDA (world), Y ; load value at world address + Y into A
    STA $2007 ; put world data into PPU memory
    INY
    CPX #$03    ; 960 tiles on screen, 960 is 03C0 in hex, so if X = 03 and Y = C0, then we are done
    BNE :+      ; Jump to the next unnamed label
    CPY #$C0
    BEQ doneloadingtitlenametable
:
    CPY #$00
    BNE loadtitlenametable
    INX             ; If Y = 0, then that means looped over from FF, so incrememnt X then
    INC world+1     ; Increment world high-order byte, basically adding 256 to address
    JMP loadtitlenametable

doneloadingtitlenametable:
    LDX #$00    ; Escape the LoadWorld loop


;;; Set starting game state
    LDA #STATETITLE
    STA gamestate

    CLI             ; clear interrupt flag
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000

    LDA #%00011110  ; background and sprites enable, no clipping on left
    STA $2001

forever:
    JMP forever

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; VBLANK loop - called every frame ;;;
VBLANK:
    LDA #$00
    STA $2003   ; low byte of RAM address
    LDA #$02
    STA $4014   ; high byte of RAM address, start transfer

    JSR drawscore

    ;; PPU clean up section, so rendering the next frame starts properly
    LDA #%10010000  ; enable NMI, sprites from pattern table 0, background from pattern table 1
    STA $2000
    LDA #%00011110  ; enable sprites, background, no left side clipping
    STA $2001
    LDA #$00
    STA $2005       ; no X scrolling
    STA $2005       ; no Y scrolling

    ;;;; all graphics updates run by now, so run game engine
    JSR readcontroller1 ; get current button data for player 1
    JSR readcontroller2 ; get current button data for player 2

GAMEENGINE:
    LDA gamestate
    CMP #STATETITLE
    BEQ enginetitle ; is it on title screen?
    
    LDA gamestate
    CMP #STATEGAMEOVER
    BEQ enginegameover ; is it on gameover screen?
    
    LDA gamestate
    CMP #STATEPLAYING
    BEQ engineplaying ; is it on playing screen?

GAMEENGINEDONEPLAY:
    JSR updatesprites   ; set ball/paddle sprites

    RTI 
GAMEENGINEDONETITLE:
    RTI 
enginetitle:
    ;;  if start button pressed
    ;;      turn screen off
    ;;      load game screen
    ;;      set starting paddle/ball position
    ;;      go to playing state
    ;;      turn screen on
    LDA buttons1
    CMP #%00010000
    BNE enginetitledone

    JSR engineplayinit

enginetitledone:
    JMP GAMEENGINEDONETITLE

enginegameover:
    ;;  if start button pressed
    ;;      turn screen off
    ;;      load title screen
    ;;      go to title screen
    ;;      turn screen on
    BNE enginegameoverdone

    JSR enginegameoverinit

enginegameoverdone:
    JMP GAMEENGINEDONETITLE
engineplaying:

moveballright:
    LDA ballright   ; is ball moving right?
    BEQ moveballrightdone   ; if ballright = 0 then skip

    LDA ballx 
    CLC     ; clear carry cos we adding 
    ADC ballspeedx 
    STA ballx 

    LDA ballx 
    CMP #RIGHTWALL  ; if ball x < right wall, still on screen, then skip next section - CMP sets Carry if >=
    BCC moveballrightdone 
    
    JSR increment1score  ; increase player 1 score
    ;;; reset ball location
    LDA score1 
    CLC 
    ADC #$01
    STA score1 

    LDA #$00 
    STA ballright 
    LDA #$01
    STA ballleft    ; set moving right to falase, and bounce

    LDA #BALLSTARTY
    STA bally
    LDA #BALLSTARTX
    STA ballx
    
moveballrightdone:

moveballleft:
    LDA ballleft   ; is ball moving left?
    BEQ moveballleftdone   ; if ballleft = 0 then skip

    LDA ballx 
    SEC     ; set carry cos we subtracting 
    SBC ballspeedx 
    STA ballx 

    LDA ballx 
    CMP #LEFTWALL  ; if ball x > left wall, still on screen, then skip next section - CMP sets Carry if >=
    BCS moveballleftdone   ; branch if carry
    
    JSR increment2score  ; increase player 1 score
    LDA score2
    CLC 
    ADC #$01
    STA score2 

    LDA #$00 
    STA ballleft 
    LDA #$01
    STA ballright    ; set moving left to falase, and bounce

    ;;; reset ball location
    LDA #BALLSTARTY
    STA bally
    LDA #BALLSTARTX
    STA ballx

moveballleftdone:

moveballup:
    LDA ballup   ; is ball moving up?
    BEQ moveballupdone   ; if ballup = 0 then skip

    LDA bally 
    SEC     ; set carry cos we subtracting 
    SBC ballspeedy 
    STA bally 

    LDA bally 
    CMP #TOPWALL  ; if ball y > top wall, still on screen, then skip next section - CMP sets Carry if >=
    BCS moveballupdone   ; branch if carry
    LDA #$00 
    STA ballup 
    LDA #$01
    STA balldown    ; set moving up to falase, and bounce
moveballupdone:

moveballdown:
    LDA balldown   ; is ball moving down?
    BEQ moveballdowndone   ; if balldown = 0 then skip

    LDA bally 
    CLC     ; clear carry cos we adding 
    ADC ballspeedy 
    STA bally 

    LDA bally 
    CMP #BOTTOMWALL  ; if ball y < bottom wall, still on screen, then skip next section - CMP sets Carry if >=
    BCC moveballdowndone   ; branch if carry

    LDA #$00 
    STA balldown 
    LDA #$01
    STA ballup    ; set moving down to falase, and bounce
moveballdowndone:

movepaddle1up:
    ;;  if up pressed
    ;;      if paddle top > top wall
    ;;          move paddle top and bottom up
    LDA buttons1
    AND #%00001000          ; up in buttons is at bit3
    BEQ movepaddle1updone   ; is up being pressed

    LDA paddle1ytop 
    CMP #TOPWALL        ; if paddle < topwall, skip movement code
    BCC movepaddle1updone

    LDA paddle1ytop
    SEC 
    SBC paddlespeed
    STA paddle1ytop

    LDA paddle1ybottom
    SEC 
    SBC paddlespeed
    STA paddle1ybottom


movepaddle1updone:

movepaddle1down:
    ;;  if down pressed
    ;;      if paddle bottom < bottom wall
    ;;          move paddle top and bottom down

    LDA buttons1
    AND #%00000100          ; down in buttons is at bit2
    BEQ movepaddle1downdone   ; is up being pressed

    LDA paddle1ybottom 
    CMP #BOTTOMWALL        ; if paddle > bottomwall, skip movement code
    BCS movepaddle1downdone

    LDA paddle1ytop
    CLC 
    ADC paddlespeed
    STA paddle1ytop

    LDA paddle1ybottom
    CLC 
    ADC paddlespeed
    STA paddle1ybottom

movepaddle1downdone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
movepaddle2up:
    ;;  if up pressed
    ;;      if paddle top > top wall
    ;;          move paddle top and bottom up
    LDA buttons2
    AND #%00001000          ; up in buttons is at bit3
    BEQ movepaddle2updone   ; is up being pressed

    LDA paddle2ytop 
    CMP #TOPWALL        ; if paddle < topwall, skip movement code
    BCC movepaddle2updone

    LDA paddle2ytop
    SEC 
    SBC paddlespeed
    STA paddle2ytop

    LDA paddle2ybottom
    SEC 
    SBC paddlespeed
    STA paddle2ybottom


movepaddle2updone:

movepaddle2down:
    ;;  if down pressed
    ;;      if paddle bottom < bottom wall
    ;;          move paddle top and bottom down

    LDA buttons2
    AND #%00000100          ; down in buttons is at bit2
    BEQ movepaddle2downdone   ; is up being pressed

    LDA paddle2ybottom 
    CMP #BOTTOMWALL        ; if paddle > bottomwall, skip movement code
    BCS movepaddle2downdone

    LDA paddle2ytop
    CLC 
    ADC paddlespeed
    STA paddle2ytop

    LDA paddle2ybottom
    CLC 
    ADC paddlespeed
    STA paddle2ybottom

movepaddle2downdone:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

checkpaddle1collision:
    ;;  if ball x < paddle 1 x
    ;;      if ball y > paddle y top
    ;;          if ball y < paddle y bottom
    ;;              bounce, ball move left now
    LDA ballx 
    SEC 
    SBC ballspeedx                  ; add the ball speex x to balls current position to get better detection
    CMP #PADDLE1X                    ; sets Carry if ballx >= PADDLE1X
    BCS checkpaddle1collisiondone   ; if ballx < paddle 1 x, skip
    
    LDA bally 
    CMP paddle1ytop 
    BCC checkpaddle1collisiondone 
    
    LDA bally
    CMP paddle1ybottom 
    BCS checkpaddle1collisiondone 

    LDA #$00
    STA ballleft
    LDA #$01
    STA ballright
checkpaddle1collisiondone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
checkpaddle2collision:
    ;;  if ball x > paddle 2 x
    ;;      if ball y > paddle y top
    ;;          if ball y < paddle y bottom
    ;;              bounce, ball move left now
    LDA ballx 
    CLC 
    ADC ballspeedx                  ; add the ball speed x to collision for more precise detection
    CMP #PADDLE2X                    ; sets Clear if ballx >= PADDLE1X
    BCC checkpaddle2collisiondone   ; if ballx < paddle 1 x, skip
    
    LDA bally 
    CMP paddle2ytop 
    BCC checkpaddle2collisiondone 
    
    LDA bally
    CMP paddle2ybottom 
    BCS checkpaddle2collisiondone 

    LDA #$00
    STA ballright
    LDA #$01
    STA ballleft
checkpaddle2collisiondone:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Check for gameover state
checkifgameover:
    LDA buttons1
    CMP #%00100000  ; if select button pressed, set gamestate
    BNE checkifgameoverdone

    LDA #STATEGAMEOVER
    STA gamestate 
checkifgameoverdone:

    JMP GAMEENGINEDONEPLAY

updatesprites:
    ;; ball sprites
    LDA bally 
    STA $0200

    LDA #$03    ; tile
    STA $0201

    LDA #$00
    STA $0202

    LDA ballx 
    STA $0203

    ;; paddle 1 sprites
    LDA paddle1ytop
    STA $0204
    LDA #$00
    STA $0205
    LDA #$00
    STA $0206
    LDA #PADDLE1X
    STA $0207

    LDA paddle1ybottom
    STA $0208
    LDA #$00
    STA $0209
    LDA #$00
    STA $020A
    LDA #PADDLE1X
    STA $020B

    ;; paddle 2 sprites
    LDA paddle2ytop
    STA $020C
    LDA #$01
    STA $020D
    LDA #$00
    STA $020E
    LDA #PADDLE2X
    STA $020F
    
    LDA paddle2ybottom
    STA $0210
    LDA #$01
    STA $0211
    LDA #$00
    STA $0212
    LDA #PADDLE2X
    STA $0213

    RTS

drawscore:
    ;;; Player 1 ;;;
    LDA $2002           ; clear PPU high/low latch
    LDA #$20
    STA $2006
    LDA #$20
    STA $2006           ; draw score at PPu $2020 - position in nametable

    LDA score1Hundreds   ; get first digit
    STA $2007           ; write to PPU address $2020
    LDA score1Tens       ; next digit
    STA $2007
    LDA score1Ones       ; last digit
    STA $2007

    ;;; Player 2 ;;;
    LDA $2002           ; clear PPU high/low latch
    LDA #$20
    STA $2006
    LDA #$3D
    STA $2006           ; draw score at PPu $202D - position in nametable

    LDA score2Hundreds   ; get first digit
    STA $2007           ; write to PPU address $202D
    LDA score2Tens       ; next digit
    STA $2007
    LDA score2Ones       ; last digit
    STA $2007
    RTS 

increment1score:
inc1ones:
    LDA score1Ones       ; load the lowest digit of the number
    CLC 
    ADC #$01            ; add one
    STA score1Ones 
    CMP #$0A            ; check for overflow, now equal 10
    BNE inc1done 
inct1ens:
    LDA #$00
    STA score1Ones       ; reset ones digit from 9 to 0
    LDA score1Tens       ; load second digit
    CLC 
    ADC #$01            ; add one, the carry from the previous digit
    STA score1Tens
    CMP #$0A            ; check if overflowed
    BNE inc1done
inc1hundreds:
    LDA #$00
    STA score1Tens       ; reset tens to 0 for overflow
    LDA score1Hundreds   ; load the last digit
    CLC 
    ADC #$01            ; add 1, the carry from the last digit
    STA score1Hundreds 
inc1done:


readcontroller1:
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016
    LDX #$08
readcontroller1loop:
    LDA $4016
    LSR A           ; Logical shift right - all bits in A are shifted to the right, bit7 is 0 and whatever is in bit0 goes to Carry flag
    ROL buttons1    ; Rotate left - opposite of LSR
    ;; used as a smart way to read controller inputs, as when each button is read, the button data is in bit0, and doing LSR puts the button 
    ;; in the Carry. Then ROL shifts the previous button data over and puts the carry back into bit0
    DEX 
    BNE readcontroller1loop
    RTS 

increment2score:
inc2ones:
    LDA score2Ones       ; load the lowest digit of the number
    CLC 
    ADC #$01            ; add one
    STA score2Ones 
    CMP #$0A            ; check for overflow, now equal 10
    BNE inc2done 
inct2ens:
    LDA #$00
    STA score2Ones       ; reset ones digit from 9 to 0
    LDA score2Tens       ; load second digit
    CLC 
    ADC #$01            ; add one, the carry from the previous digit
    STA score2Tens
    CMP #$0A            ; check if overflowed
    BNE inc2done
inc2hundreds:
    LDA #$00
    STA score2Tens       ; reset tens to 0 for overflow
    LDA score2Hundreds   ; load the last digit
    CLC 
    ADC #$01            ; add 1, the carry from the last digit
    STA score2Hundreds 
inc2done:


    
readcontroller2:
    LDA #$01
    STA $4017
    LDA #$00
    STA $4017
    LDX #$08
readcontroller2loop:
    LDA $4017
    LSR A           ; Logical shift right - all bits in A are shifted to the right, bit7 is 0 and whatever is in bit0 goes to Carry flag
    ROL buttons2    ; Rotate left - opposite of LSR
    ;; used as a smart way to read controller inputs, as when each button is read, the button data is in bit0, and doing LSR puts the button 
    ;; in the Carry. Then ROL shifts the previous button data over and puts the carry back into bit0
    DEX 
    BNE readcontroller2loop
    RTS 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLAY INIT ;;;
engineplayinit:
    ;;; load playing nametable ;;;
engineplayloadnametable:
    ; disable sprite and background visibility to unlock PPU RAM
    LDA #$00
    STA $2001


    LDA #<playworlddata ; Load the high-order byte from the WorldData variable into the accumulator - has to do this way not the entire 2 bytes as accumulator is only 1 byte
    STA world
    LDA #>playworlddata ; Get the low-order byte to store
    STA world+1 ; Assembler realises that this means store the variable in the 2nd byte of world

    ; setup address in PPU for nametable data
    BIT $2002 ; 15:00 in video - Actually pretty good to relisten to - reading (in this case using BIT) from $2002 basically resets $2006, so writing to $2006 after this for the first time, the program knows you are writing the firat byte of the desired address, discarding any leftovers from previous usage.
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00
    LDY #$00
loadplaynametable:
    LDA (world), Y ; load value at world address + Y into A
    STA $2007 ; put world data into PPU memory
    INY
    CPX #$03    ; 960 tiles on screen, 960 is 03C0 in hex, so if X = 03 and Y = C0, then we are done
    BNE :+      ; Jump to the next unnamed label
    CPY #$C0
    BEQ doneloadingplaynametable
:
    CPY #$00
    BNE loadplaynametable
    INX             ; If Y = 0, then that means looped over from FF, so incrememnt X then
    INC world+1     ; Increment world high-order byte, basically adding 256 to address
    JMP loadplaynametable

doneloadingplaynametable:
    LDX #$00    ; Escape the LoadWorld loop

loadstartingvalues:
;;; set intial ball values
    LDA #$01
    STA ballright
    STA ballup
    LDA #$00
    STA balldown
    STA ballleft

    LDA #BALLSTARTY
    STA bally

    LDA #BALLSTARTX
    STA ballx

    LDA #$02
    STA ballspeedx
    STA ballspeedy

;;; set paddle speed + start position
    LDA #$03
    STA paddlespeed
    LDA #$70
    STA paddle1ytop
    LDA #$78
    STA paddle1ybottom

    LDA #$70
    STA paddle2ytop
    LDA #$78
    STA paddle2ybottom

    ;;; load playing gamestate ;;;
    LDA #STATEPLAYING   
    STA gamestate       ; change gamestate to be playing
engineplayinitdone:
    RTS 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GAMEOVER INIT ;;;
enginegameoverinit:
    ;;; load title nametable ;;;
enginegameoverloadnametable:
    ; disable sprite and background visibility to unlock PPU RAM
    LDA #$00
    STA $2001


    LDA #<titleworlddata ; Load the high-order byte from the WorldData variable into the accumulator - has to do this way not the entire 2 bytes as accumulator is only 1 byte
    STA world
    LDA #>titleworlddata ; Get the low-order byte to store
    STA world+1 ; Assembler realises that this means store the variable in the 2nd byte of world

    ; setup address in PPU for nametable data
    BIT $2002 ; 15:00 in video - Actually pretty good to relisten to - reading (in this case using BIT) from $2002 basically resets $2006, so writing to $2006 after this for the first time, the program knows you are writing the firat byte of the desired address, discarding any leftovers from previous usage.
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00
    LDY #$00
loadgameovernametable:
    LDA (world), Y ; load value at world address + Y into A
    STA $2007 ; put world data into PPU memory
    INY
    CPX #$03    ; 960 tiles on screen, 960 is 03C0 in hex, so if X = 03 and Y = C0, then we are done
    BNE :+      ; Jump to the next unnamed label
    CPY #$C0
    BEQ doneloadinggameovernametable
:
    CPY #$00
    BNE loadgameovernametable
    INX             ; If Y = 0, then that means looped over from FF, so incrememnt X then
    INC world+1     ; Increment world high-order byte, basically adding 256 to address
    JMP loadgameovernametable

doneloadinggameovernametable:
    LDX #$00    ; Escape the LoadWorld loop

    LDA #STATETITLE
    STA gamestate 

enginegameoverinitdone:
    RTS 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Sprite / palette / nametable / attributes ;;;
palettedata:
    .byte $0f,$20,$10,$00,   $0f,$20,$10,$00,   $0f,$20,$10,$00,   $0f,$20,$10,$00  ; background palette data
    .byte $0f,$20,$10,$00,   $0f,$20,$10,$00,   $0f,$20,$10,$00,   $0f,$20,$10,$00  ; sprite palette data

titleworlddata:
    .incbin "title.nam"

playworlddata:
    .incbin "pong.nam"

spritedata:
    ;      Y  tile  attr  X
    .byte $80, $32, $00, $80 ; ball
    .byte $80, $33, $00, PADDLE1X
    .byte $88, $34, $00, $80
    .byte $88, $35, $00, PADDLE1X


.segment "VECTORS"
    .word VBLANK
    .word RESET
    .word 0
.segment "CHARS"
    .incbin "pong.chr"