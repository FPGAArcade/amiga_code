	section	oled_test,code_p

ENABLE_KPRINTF

	incdir	sys:code/NDK_3.9/Include/include_i/

	include	"exec/types.i"
	include	"exec/libraries.i"
	include	"exec/semaphores.i"

	include	"exec/ables.i"
	include	"exec/resident.i"
	include	"exec/initializers.i"
	include	"utility/date.i"

	include	"lvo/exec_lib.i"
	include	"lvo/utility_lib.i"

	INCLUDE 'kprintf.i'

_intena      EQU   $dff09a

	BITDEF	I2C,READ,0
	BITDEF	I2C,ACK,8
	BITDEF	I2C,STOP,9
	BITDEF	I2C,START,10
	BITDEF	I2C,BUSY,15

SSPBDAT		equ	$dd0058
I2C_SSD1306	equ	$d0

SSD1306_LCDWIDTH		= 128
SSD1306_LCDHEIGHT		= 64

SSD1306_SET_ADDRESSING_MODE	= $20 ; 00=horiz, 01=vertical, 10=page address
SSD1306_SET_PAGE_ADDRESS	= $22
SSD1306_SET_DISPLAY_START_LINE	= $40 ; 0-63
SSD1306_SET_CONTRAST_CTRL	= $81
SSD1306_CHARGE_PUMP_SETTING	= $8D ; control internal OLED charge pump
SSD1306_SET_SEGMENT_REMAP	= $A0 ; 
SSD1306_SET_DISPLAY_RESUME	= $A4
SSD1306_SET_DISPLAY_IGNORE	= $A5
SSD1306_SET_DISPLAYMODE_NORMAL	= $A6
SSD1306_SET_DISPLAYMODE_INVERT	= $A7
SSD1306_SET_MULTIPLEX_RATIO	= $A8 ; MUX ratio is N+1
SSD1306_SET_COM_SCAN_DIR	= $C0
SSD1306_SET_DISPLAY_OFFSET	= $D3 ; 0-63
SSD1306_SET_DISPLAY_CLOCK_DIV	= $D5 ; b7-4 = freq, b3-0 = divider

SSD1306_SET_PRECHARGE_PERIOD	= $D9 ; b7-4 = phase2, b3-0 = phase1
SSD1306_SET_COM_PINS		= $DA
SSD1306_SET_VCOM_DESELECT_LVL	= $DB


SSD1306_SET_COLUMN_START_LOW	= $00 ; hi/low nibble for column start
SSD1306_SET_COLUMN_START_HIGH	= $10 ; offset, i.e. X offset in page
SSD1306_SET_PAGE_START		= $B0

SSD1306_DISPLAY_OFF		= $AE
SSD1306_DISPLAY_ON		= $AF


;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

S	
		movem.l	d0-a6,-(sp)
		
		kprintf	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		kprintf	"SSD1306 OLED Start"

	; Scan the I2C bus for devices..
			
		bsr.w	ScanI2C

	; Convert REPLAY logo to OLED format

		bsr.w	FlattenAndShrinkLogo

		lea	ReplayLogo(pc),a0
		lea	LogoOLED(pc),a1
		move.w	#OLEDLOGO_WIDTH,d0
		move.w	#OLEDLOGO_HEIGHT,d1
		bsr.w	ConvertBitplaneToOLED

	; Convert font to OLED format
	
		bsr.w	ByteReverseFont

		lea	font8x8_basic(pc),a0
		lea	FontOLED(pc),a1
		move.w	#8,d0
		move.w	#8*128,d1
		bsr.w	ConvertBitplaneToOLED

	; Init OLED and clear display

		lea	SSD1306_InitSequence(pc),a0
		moveq.l	#SSD1306_InitSequenceSize,d0
		moveq.l #$3c,d1
		moveq.l	#$00,d2
		bsr.w	ssd1306_write

		bsr.w	SSD1306_Clear

	; Copy REPLAY logo and print string

		lea	LogoOLED(pc),a0
		move.w	#OLEDLOGO_WIDTH,d0
		move.w	#OLEDLOGO_HEIGHT,d1
		moveq.l	#15,d2			; center logo
		moveq.l	#0,d3
		bsr.w	SSD1306_Copy

		lea	String(pc),a0
		bsr.w	SSD1306_PrintString

		movem.l	(sp)+,d0-a6
		rts	

;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
SSD1306_Clear:	movem.l	d0-d4/a0,-(sp)

		moveq.l	#0,d2
		moveq.l	#0,d4		; page
.page

		lea	SSD1306_SetPageAndColumn(pc),a0
		move.b	d4,(a0)
		or.b	#SSD1306_SET_PAGE_START,(a0)
		moveq.l	#SSD1306_SetPageAndColumnSize,d0
		moveq.l #$3c,d1
		moveq.l	#$00,d2
		bsr.w	ssd1306_write

		lea	SSD1306_EmptyLine(pc),a0
		move.w	#SSD1306_LCDWIDTH,d0
		moveq.l #$3c,d1
		moveq.l	#$40,d2
		bsr.w	ssd1306_write

		addq	#1,d4
		cmp.w	#SSD1306_LCDHEIGHT/8,d4
		blt.w	.page

		movem.l	(sp)+,d0-d4/a0
		rts


;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


SSD1306_Copy:	; d0 = width, d1 = height, d2 = x pos, d3 = y pos
		movem.l	d0-d4/a0-a1,-(sp)

		lea	SSD1306_SetPageAndColumn(pc),a1

		move.w	d2,d4
		and.w	#$0f,d2
		lsr.w	#4,d4

		move.b	d2,1(a1)
		move.b	d4,2(a1)
		or.b	#SSD1306_SET_COLUMN_START_LOW,1(a1)
		or.b	#SSD1306_SET_COLUMN_START_HIGH,2(a1)

		move.w	d3,d4		; start page
		lsr.w	#3,d1
		move.w	d1,d3		; num blocks
		add.w	d4,d3		; end page
.Copy
		movem.l	d0/a0,-(sp)

		lea	SSD1306_SetPageAndColumn(pc),a0
		move.b	d4,(a0)
		or.b	#SSD1306_SET_PAGE_START,(a0)
		moveq.l	#SSD1306_SetPageAndColumnSize,d0
		moveq.l #$3c,d1
		moveq.l	#$00,d2
		bsr.w	ssd1306_write

		movem.l	(sp)+,d0/a0

		; a0 = buffer
		; d0 = width * 8
		moveq.l #$3c,d1
		moveq.l	#$40,d2
		bsr.w	ssd1306_write
		adda.w	d0,a0

		addq	#1,d4
		cmp.w	d3,d4
		blt.w	.Copy

		movem.l	(sp)+,d0-d4/a0-a1
		rts
	
;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SSD1306_PrintString	; a0 = null terminated string

SPACING = 7
	; reset X pos / column
		moveq.l	#0,d0
		
	; get current page and move to next
		move.w	SSD1306_CurPage(pc),d1
		addq.w	#1,d1

		bsr.b	.SetPosAndScroll

		moveq.l	#0,d2
		lea	FontOLED(pc),a1
		
.NextChar:	move.b	(a0)+,d2
		beq.b	.Done

		; treat cr as cr/lf
		cmp.b	#13,d2
		bne.b	.notCR

		bsr.w	.ClearRemaining

		move.b	#0,d0	; reset X
		add.b	#1,d1	; add to Y
		bsr.b	.SetPosAndScroll
		bra.b	.NextChar
		
.notCR
		; skip linefeed
		cmp.b	#10,d2
		beq.b	.NextChar

	; can we fit another char? if not, get another char
		cmp.w	#SSD1306_LCDWIDTH-8,d0
		bgt.b	.NextChar

		bsr.b	.SetPosAndScroll	; for compact printing

	; get glyph ptr
		lea	(a1,d2.w*8),a2

	; send 8x8 char
		movem.l	d0/d1/a0,-(sp)
		
		movea.l	a2,a0
		moveq.l	#8*8/8,d0
		moveq.l #$3c,d1
		moveq.l	#$40,d2
		bsr.w	ssd1306_write

		movem.l	(sp)+,d0/d1/a0

	; 
		add.w	#SPACING,d0
		bra.b	.NextChar
		
.Done:
		bsr.b	.ClearRemaining

		lea	SSD1306_CurPage(pc),a1
		move.w	d1,(a1)
		rts

.SetPosAndScroll
		movem.l	d0-d3/a0,-(sp)

		move.w	d0,d2
		move.w	d0,d3
		and.w	#$f,d2
		lsr.w	#4,d3

		lea	SSD1306_SetPageColumnScroll(pc),a0

		and.b	#$7,d1
		move.b	d1,(a0)
		move.b	d2,1(a0)
		move.b	d3,2(a0)

		move.b	d1,d2
		add.b	#1,d2
		and.b	#7,d2
		lsl.b	#3,d2
		move.b	d2,3(a0)

		or.b	#SSD1306_SET_PAGE_START,(a0)
		or.b	#SSD1306_SET_COLUMN_START_LOW,1(a0)
		or.b	#SSD1306_SET_COLUMN_START_HIGH,2(a0)
		or.b	#SSD1306_SET_DISPLAY_START_LINE,3(a0)

		moveq.l	#SSD1306_SetPageColumnScollSize,d0
		moveq.l #$3c,d1
		moveq.l	#$00,d2
		bsr.w	ssd1306_write

		movem.l	(sp)+,d0-d3/a0
		rts

.ClearRemaining
		bsr.b	.SetPosAndScroll
	
		movem.l	d0/d1/a0,-(sp)

		lea	SSD1306_EmptyLine(pc),a0
		sub.w	#SSD1306_LCDWIDTH,d0
		neg.w	d0
		moveq.l #$3c,d1
		moveq.l	#$40,d2
		bsr.w	ssd1306_write

		movem.l	(sp)+,d0/d1/a0
		rts
	

;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


ScanI2C
		kprintf "OLED: I2C scan"
		movem.l	d0-a6,-(sp)

		DISABLE	a6
		lea	SSPBDAT,a1

		moveq.l	#$1,d2	; start address

.scan		move.w	d2,d0
		add.w	d0,d0
		or.w	#I2CF_START|I2CF_STOP,d0
		move.w	d0,(a1)
		bsr.w	i2c_wait
		beq.b	.error
		btst	#I2CB_ACK,d6
		beq.w	.error

		kprintf	"I2C device found at %lx",d2
		nop

.error		addq	#1,d2
		cmp.w	#$7f,d2	; end address
		ble.b	.scan
	
		ENABLE	a6
		movem.l	(sp)+,d0-a6
		rts


;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

delay		move.w	#6490,d7
.busy		rept	10
		btst	#1,$bfe001
		endr
		dbf	d7,.busy
		rts


;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

i2c_wait:
		move.w	#1024,d7
.busy		btst	#1,$bfe001
		move.w	(a1),d6
		btst	#I2CB_BUSY,d6
		dbeq	d7,.busy
		cmp.w	#$ffff,d7
		rts

; a0.l = buffer
; d0.w = length
; d1.b = oled i2c address
; d2.b = control byte (bit 7 = Co, bit 6 = D/C#)
; 
;
; d0 = bytes written (negative if error)
;

ssd1306_write:
		movem.l	d1/d2/d6/d7/a0/a1/a6,-(sp)
		DISABLE	a6

		lea	SSPBDAT,a1

		and.w	#$7f,d1		; i2c address valid range 0-7f
		lsl.w	d1		; bit 0 is read/write marker
		or.w	#I2CF_START,d1	; mark stream start

	; transmit START+ADDRESS+WRITE
		move.w	d1,(a1)
		bsr.b	i2c_wait
		beq.b	.error
		btst	#I2CB_ACK,d6
		beq.b	.error

		moveq.l	#-1,d1		; clear bytes written
		and.w	#$00ff,d2	; make sure control byte is "clean"

		tst.w	d0		; zero length packet?
		bne.b	.send
		or.w	#I2CF_STOP,d2	; make sure we STOP if len == 0
		bra.b	.send

.loop		move.b	(a0)+,d2

.send
	; transmit DATA (+STOP)
		move.w	d2,(a1)
		bsr.b	i2c_wait
		beq.b	.error
		btst	#I2CB_ACK,d6
		beq.b	.error

		addq.l	#1,d1		; another byte sent

	; 
		subq.w	#1,d0
		bmi.b	.done
		bne.b	.loop

		move.w	#I2CF_STOP,d2
		bra.b	.loop

.error		moveq.l	#-1,d1

.done		move.l	d1,d0

		movem.l	(sp)+,d1/d2/d6/d7/a0/a1/a6
		ENABLE	a6
		rts
	
;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

String	dc.b	"Replay OLED Driver",13,13,0
	even

SSD1306_InitSequence:
	dc.b	SSD1306_DISPLAY_OFF
	dc.b	SSD1306_SET_DISPLAY_CLOCK_DIV
	dc.b	$80			; %1000 + %0000 = RESET value

	dc.b	SSD1306_SET_MULTIPLEX_RATIO
	dc.b	$3f			; 63 = RESET value
	dc.b	SSD1306_SET_DISPLAY_OFFSET
	dc.b	$00
	dc.b	SSD1306_SET_DISPLAY_START_LINE|$0
	dc.b	SSD1306_SET_ADDRESSING_MODE
	dc.b	$00			; horizontal addressing mode

	; flip display in X and Y
	dc.b	SSD1306_SET_COM_SCAN_DIR|$08
	dc.b	SSD1306_SET_SEGMENT_REMAP|$01

	dc.b	SSD1306_SET_COM_PINS
	dc.b	$12			; b5-4 pin config (%01 = RESET value)
	dc.b	SSD1306_SET_CONTRAST_CTRL
	dc.b	$7f			; $7f = RESET value
	dc.b	SSD1306_SET_PRECHARGE_PERIOD
	dc.b	$22			; %0010 + %0010 = RESET value 
	dc.b	SSD1306_SET_VCOM_DESELECT_LVL
	dc.b	$40
	dc.b	SSD1306_SET_DISPLAY_RESUME
	dc.b	SSD1306_SET_DISPLAYMODE_NORMAL
	dc.b	SSD1306_CHARGE_PUMP_SETTING
	dc.b	$14			; %00010000 = off, %00010100 = on
	dc.b	SSD1306_DISPLAY_ON
SSD1306_InitSequenceSize = *-SSD1306_InitSequence
	even

SSD1306_SetPageAndColumn:
	dc.b	SSD1306_SET_PAGE_START+0
	dc.b	SSD1306_SET_COLUMN_START_LOW+0
	dc.b	SSD1306_SET_COLUMN_START_HIGH+0
SSD1306_SetPageAndColumnSize = *-SSD1306_SetPageAndColumn
	even

SSD1306_SetPageColumnScroll:
	dc.b	SSD1306_SET_PAGE_START+0
	dc.b	SSD1306_SET_COLUMN_START_LOW+0
	dc.b	SSD1306_SET_COLUMN_START_HIGH+0
	dc.b	SSD1306_SET_DISPLAY_START_LINE+0
SSD1306_SetPageColumnScollSize = *-SSD1306_SetPageColumnScroll
	even

SSD1306_EmptyLine
	dcb.b	SSD1306_LCDWIDTH,$00
	even

SSD1306_CurPage	dc.w	OLEDLOGO_HEIGHT/8-1

;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; Size of the original bitplane Replay logo
LOGO_WIDTH	= 208
LOGO_HEIGHT	= 77
LOGO_BPLSIZE	= (LOGO_WIDTH*LOGO_HEIGHT/8)

; Size of the logo when converted to OLED memory layout
OLEDLOGO_WIDTH	= (LOGO_WIDTH/2)
OLEDLOGO_HEIGHT	= ((LOGO_HEIGHT/2+$3)&(~$3))

LogoOLED:	; 104x40
	dcb.b (OLEDLOGO_WIDTH*OLEDLOGO_HEIGHT/8),$aa

FontOLED:
	dcb.b 1024,$00


ReplayLogo: ; 208x77
		incbin	replay_208x77.bin

;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FlattenAndShrinkLogo

		lea	ReplayLogo(pc),a0
		movea.l	a0,a4

		move.w	#(LOGO_HEIGHT)/2-1,d6
.flatteny
		lea	LOGO_BPLSIZE(a0),a1
		lea	LOGO_BPLSIZE(a1),a2
		lea	LOGO_BPLSIZE(a2),a3

		move.w	#(LOGO_WIDTH/8)/2-1,d7
.flattenx
		; flatten bitplanes
		move.w	(a0)+,d0
		or.w	(a1)+,d0
		or.w	(a2)+,d0
		or.w	(a3)+,d0

		; collapse odd bits
		move.w	d0,d1
		and.w	#$1111,d0
		and.w	#$4444,d1
		lsr.w	d1
		or.w	d1,d0

		move.w	d0,d1
		and.w	#$0303,d0
		and.w	#$3030,d1
		lsr.w	#2,d1
		or.w	d1,d0

		move.w	d0,d1
		and.w	#$000f,d0
		and.w	#$0f00,d1
		lsr.w	#4,d1
		or.w	d1,d0

		move.b	d0,(a4)+
		dbf	d7,.flattenx

		add.w	#(LOGO_WIDTH/8),a0

		dbf	d6,.flatteny

		move.w	#(LOGO_HEIGHT/2+$3)&(~$3)-(LOGO_HEIGHT/2)-1,d6
.cleary		rept	LOGO_WIDTH/8/2
		move.b	#0,(a4)+
		endr
		dbf	d6,.cleary
		
		rts

;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ConvertBitplaneToOLED: ; a0 = input, a1 = output, d0 = width, d1 = height

		movem.l	d0-d7/a0-a2,-(sp)

		move.w	d0,d4		; original width

		lsr.w	#3,d0		; num 8x8 blocks horizontally
		lsr.w	#3,d1		; num 8x8 blocks veritcally

		sub.w	d0,d4		; block stride (8*width/8-width/8)

		move.w	d0,d5		; bitmap stride
		move.w	d1,d6
		subq.w	#1,d6
.loop_y
		move.w	d5,d7
		subq.w	#1,d7		; width/8-1
.loop_x
	; convert 8x8 block, rotating it 90 degrees counter clockwise
	; this is highly ineffecient but makes for simple and small code..

		moveq.l	#0,d1		; output register collecting bits
		moveq.l	#8,d2		; current bit num (-> 0)

.loop_blocky
		movea.l	a0,a2
		moveq.l	#8-1,d3		; loop 8 times - collect one byte

.loop_blockx	move.b	(a2),d0		; fetch bitplane data
		add.w	d5,a2		; walk bitplane vertically

		roxr.b	d2,d0		; shift out the current bit to X
		roxr.b	#1,d1		; shift X in to output reg

		dbf	d3,.loop_blockx

		move.b	d1,(a1)+	; store rotated bits

		subq.b	#1,d2		; move to next bit
		bne.b	.loop_blocky

	; 8x8 block done

		adda.w	#1,a0		; move to next block

		dbf	d7,.loop_x

		adda.w	d4,a0	; skip all processed blocks

		dbf	d6,.loop_y

		movem.l	(sp)+,d0-d7/a0-a2
		rts

;  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ByteReverseFont
		lea	font8x8_basic(pc),a0
		move.w	#8*8*128/8/4-1,d7

.swap		move.l	(a0),d0

		move.l	d0,d1
		and.l	#$0f0f0f0f,d0
		and.l	#$f0f0f0f0,d1
		lsl.l	#4,d0
		lsr.l	#4,d1
		or.l	d1,d0
		
		move.l	d0,d1
		and.l	#$33333333,d0
		and.l	#$cccccccc,d1
		lsl.l	#2,d0
		lsr.l	#2,d1
		or.l	d1,d0

		move.l	d0,d1
		and.l	#$55555555,d0
		and.l	#$aaaaaaaa,d1
		lsl.l	#1,d0
		lsr.l	#1,d1
		or.l	d1,d0
		
		move.l	d0,(a0)+
		dbf	d7,.swap
		rts

	include "font8x8_basic.i"

