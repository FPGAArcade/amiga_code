;APS00000000000000000000000000000000000000000000000000000000000000000000000000000000

; ------------------------------
;
;	   R E P L A Y
;	    SD DRIVER
;
; Nicolas 'Gouky' Hamel
;
; Revision:
;
;	0.1 - alpha version
;
; http://elm-chan.org/docs/mmc/mmc_e.html
;
; Use ASM-Pro and DevPac 3.xx Include3.0
;
; ------------------------------

;	OUTPUT	replaysd.device
	AUTO wo ram:replaysd.device\

; ------------------------------
;	     Includes
; ------------------------------

ENABLE_KPRINTF

	INCDIR 	"Include3.0:Include/"		; from devpac3
	INCLUDE	exec/exec_lib.i
	INCLUDE exec/io.i
	INCLUDE exec/memory.i
	INCLUDE exec/nodes.i
	INCLUDE exec/resident.i
	INCLUDE dos/dos_lib.i
	INCLUDE devices/trackdisk.i
	INCLUDE libraries/configregs.i
	INCLUDE libraries/configvars.i
	INCLUDE libraries/expansion.i
	INCLUDE libraries/expansion_lib.i

	INCDIR	"Devt:sddriver/"
	INCLUDE kprintf.i

; ------------------------------
;	     Defines
; ------------------------------

ENABLE_CMD_LINE_DEBUG	equ	0

REPLAY_MANUFACTURER	equ	5060		; must match the replay vhdl side
REPLAY_PRODUCT		equ	28

FILE_VERSION		equ	0
FILE_REVISION		equ	1

; SD Card enums
SD_CARD_V1		equ 	0
SD_CARD_V2		equ 	1

SD_BLOCK_SIZE		equ 	512
SD_BLOCK_SIZE_SHIFT	equ 	9

; SPI Registers
SPI_REG			equ	$100
SPI_DATA		equ	$102
SPI_CS			equ	$104
 
; to be redo
RSD_SIZEOF		equ	56

; string defines
CR			equ 	13
LF			equ 	10

; SD STATE DEFINES
SD_OK			equ	0
SD_ERROR_TIMEOUT	equ	1

; SD Card driver struct
	RSRESET

device_spi_base		rs.l	1
device_device		rs.l	1
device_unit		rs.b	UNIT_SIZE
device_struct_size	rs.b	0

; ------------------------------
;	    MACROS
; ------------------------------

SPI_SD_CMD	macro
	move.w	#\1,d0
	bsr.w	spi_send_byte		; command
	move.w	#\2,d0
	bsr.w	spi_send_byte		; arg
	move.w	#\3,d0
	bsr.w	spi_send_byte
	move.w	#\4,d0
	bsr.w	spi_send_byte
	move.w	#\5,d0
	bsr.w	spi_send_byte
	move.w	#\6,d0
	bsr.w	spi_send_byte		; crc
	endm

SPI_SET_SPEED macro
	move.w	#\1,SPI_REG(a6)
	endm

SPI_ASSERT_CS macro
	move.w	#0,SPI_CS(a6)
	endm
	
SPI_DEASSERT_CS macro
	move.w	#$FFFF,SPI_CS(a6)
	endm
	
; ------------------------------
;	     SHELL
; ------------------------------

; ----------
; entry
; ----------
entry:
	IFNE	ENABLE_CMD_LINE_DEBUG		; Debug code

	bsr.w	init
	bsr.w 	test_sd
	
.success:
	kprintf	"...finished..."
	
.finish:
	moveq.l	#0,d0
	kprintf "[SDDriver] Shuttind down"
	kprintf "------------------------"	
	ELSE
	
	moveq.l	#-1,d0 				; error
	
	ENDC
	rts


	IFNE	ENABLE_CMD_LINE_DEBUG		; Debug code

; ----------
; test_sd
; ----------
test_sd:
	; init a block of memory with not so random data
	lea 	debug_scratch,a0
	moveq.l #0,d1
	move.l 	#(SD_BLOCK_SIZE/2)-1,d0

.loop:
	move.w 	d1,(a0)+
	addi.w 	#1,d1
	dbf	d0,.loop

	; write block to #0
	move.l 	#0,d0 				; address
	move.l 	#SD_BLOCK_SIZE,d1 		; data size in bytes
	lea 	debug_scratch,a0 		; pointer to data
	bsr.w 	sd_write_blocks

	; clean scratch
	move.l	#(SD_BLOCK_SIZE/4)-1,d0
	lea	debug_scratch,a0	
.clean:
	move.l	#$FFFFFFFF,(a0)+
	dbf	d0,.clean

	; read back the block
	kprintf	"[test_sd] read block #0"
	move.l	#0,d0				; address
	move.l 	#SD_BLOCK_SIZE,d1 		; data size in bytes
	lea 	debug_scratch,a0 		; point to data
	bsr.w 	sd_read_blocks
	tst	d0
	bne.s	.done
	kprintf	"read block fail"

.done:
	rts

	ENDC

; ----------
; init
; ----------
init:
	kprintf "[SDDriver] initilization..."
	bsr.w 	find_card			; todo: handle fail
	bsr.w	init_sd
	tst.w	d0
	beq.s	.fail
	rts
			
.fail:
	kprintf	"*** INIT FAILED *** %ld",d0
	rts

; ----------
; init_card
; ----------	
find_card:
	kprintf "[SDDriver] Looking for replaysd card"
	lea	lib_expansion_name,a1
	CALLEXEC OpenLibrary
	tst.l	d0
	beq.s	.failed
	move.l	d0,a6
	move.l	#REPLAY_MANUFACTURER,d0
	move.l 	#REPLAY_PRODUCT,d1
	move.l	#0,a0
	jsr	_LVOFindConfigDev(a6)
	tst	d0
	beq.b	.failed
	move.l	d0,a0				; card base address
	move.l	#device_struct_size,d0
	move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
	jsr	Malloc
	tst	d0
	bne.s	.failed				; cannot allocate memory
	move.l	d0,device_ctx
	move.l	d0,a1				; struct address
	move.l	cd_BoardAddr(a0),device_spi_base(a1)
	move.l 	a0,d0
	move.l	d0,device_device(a1)
;	move.l	cd_BoardAddr(a0),card_base
;	move.l	card_base,d0
	kprintf	"[find_card] base address = %lx",d0
	bra.s	.cleanup
.failed:
	kprintf "[SDDriver][ERROR] no card found!"
	moveq	#0,d0
.cleanup:
	move.l	a6,a1
	CALLEXEC CloseLibrary
	rts

; ------------------------------
;	SD Functions
; ------------------------------

; ----------
; init_sd
; ----------
init_sd:
	move.l	device_ctx,a0
	movea.l	device_spi_base(a0),a6
;	movea.l	card_base,a6			; a6 => base card address
	SPI_DEASSERT_CS
	SPI_SET_SPEED $80			; set spi clock to about 110khz
	moveq	#10,d6				; wait for 88 cycles
	
.wait:
	move.w	#$FF,d0
	bsr.w 	spi_send_byte
 	dbf	d6,.wait
	SPI_ASSERT_CS				; send CMD0 for IDLE and SPI
	moveq	#20,d6

.cmd0:
	bsr.w	sd_cmd0
	cmp.b	#$1,d0
	beq.w	.cmd0_ok
	dbf	d6,.cmd0
	extb.l	d0
	kprintf	"[init_sd] cmd0 failed (ret %ld)",d0
	moveq	#0,d0
	rts					; failed
	
.cmd0_ok:
	bsr.w 	sd_cmd8				; send CMD8
	cmp.w 	#$1,d0 				; v2 version?
	beq.w 	.checktype

.checktype:
	cmp.l	#$1AA,d1			; check r7
	bne.w	.v1_init			; v1 card
	kprintf	"[init_sd] sd v2 found"
	move.l	#$FF,d6

.acmd41:
	bsr.w 	sd_acmd41			; init V2 SD Card
	btst	#0,d0
	beq.s	.acmd41success
	dbf	d6,.acmd41
	kprintf	"[init_sd] acmd41 timeout"
	moveq	#0,d0				; failed
	rts

.acmd41success:
	kprintf	"acmd41 r1 %lx",d0
	bsr.w 	sd_cmd58			; read OCR
	tst.w	d0
	bne.s	.finish
	moveq	#0,d0
	kprintf	"[init_sd] sd_cmd58 failed"

.v1_init:
	kprintf	"[init_sd] sd v1 found"
	moveq	#0,d0				; fail as not supported * TODO *
	bsr.w 	sd_cmd1 			; v1 card

.finish:
	SPI_DEASSERT_CS
	SPI_SET_SPEED $0			; spi maximum clock speed
	moveq	#1,d0				; sucess
	kprintf	"[init_sd] SD Card ready"
	rts


; ----------
; sd_read_blocks
; ----------
sd_read_blocks:
	bsr.w	sd_wait_ready
	SPI_ASSERT_CS
	SPI_SD_CMD $51,$0,$0,$0,$0,$01		; dummy address
	moveq	#8,d6
	
.waitr1:
	bsr.w	spi_receive_byte
	tst	d0
	beq.s	.ack
	dbf	d6,.waitr1
	kprintf	"[sd_read_blocks] sd not ready r1 = %lx",d0
	moveq	#0,d0
	rts

.ack:
	move.l	#$FF,d2


.waitack:
	bsr.w	spi_receive_byte
	cmp.b	#$FE,d0
	beq.s	.read
	dbf	d2,.waitack
	kprintf	"[sd_read_blocks] ack never came"
	moveq	#0,d0
	rts
	
.read:
	move.l	#$200-1,d2			; sector size

.loop:
	bsr.w	spi_receive_byte
	move.b	d0,(a0)+
	dbf	d2,.loop
	bsr.w	spi_wait
	bsr.w	spi_wait
	bsr.w	spi_wait
	SPI_DEASSERT_CS
	move.w	#1,d0
	rts

; ----------
; sd_write_blocks
; ----------
sd_write_blocks:
	bsr.w	sd_wait_ready
	SPI_ASSERT_CS
	SPI_SD_CMD $58,$0,$0,$0,$0,$01
	moveq	#8,d6

.waitr1:
	bsr.w	spi_receive_byte
	tst	d0
	beq.s	.write
	dbf	d6,.waitr1
	kprintf	"[sd_write_block] sd card not ready r1 = %lx",d0
	rts

.write:
	move.w	#$FE,d0				; token
	bsr.w	spi_send_byte
	move.l	#$200-1,d6
	moveq	#0,d0
	
.loop:
	move.b	(a0)+,d0
	bsr.w	spi_send_byte
	dbf	d6,.loop
	move.w	#$FF,d0				; dummy CRC
	bsr.w	spi_send_byte
	move.w	#$FF,d0
	bsr.w	spi_send_byte
	kprintf	"data response %lx",d0
	bsr.w	spi_receive_byte
	and.b	#$0F,d0
	cmp.b	#$5,d0
	beq.s	.done
	kprintf	"[sd_write_blocks] write fail"
	moveq	#0,d0
	rts

.done:
	move.l	#5000,d6			; wait for the write to finish

.waitwrite:
	bsr.w	spi_receive_byte
	cmp.w	#$FF,d0
	beq.s	.finish
	dbf	d6,.waitwrite

.finish:
	kprintf	"[sd_write_blocks] success %lx",d0
	SPI_DEASSERT_CS
	rts

; ----------
; sd_cmd0
; ----------
sd_cmd0:
	SPI_SD_CMD $40,$0,$0,$0,$0,$95
	moveq 	#10,d3
	
.waitr1:
	bsr.w	spi_receive_byte	
	cmp.w	#1,d0
	beq.b	.done
	dbf	d3,.waitr1
	kprintf	"[sd_cmd0] failed ret = %ld",d0
	moveq	#0,d0				; fail
	rts

.done:	
	rts

; ----------
; sd_cmd1
; ----------
sd_cmd1:
	kprintf	"[sd_cmd1] NOT IMPLEMENTED"
	rts

; ----------
; sd_cmd8
; ----------
sd_cmd8:
	SPI_SD_CMD $48,$0,$0,$01,$AA,$87
	moveq	#10,d6
	
.waitr1:
	bsr.w	spi_receive_byte
	cmp.w	#1,d0				; in idle?
	beq.b	.done
	dbf	d6,.waitr1
	kprintf	"[sd_cmd8] failed ret = %lx",d0
	rts

.done:
	moveq	#3,d2
	moveq	#0,d1				; d1 will hold r7


.readr7:
	bsr.w	spi_receive_byte
	lsl.l	#8,d1
	or.b	d0,d1
	dbf	d2,.readr7
	moveq	#1,d0				; success
	rts

; ----------
; sd_cmd23
; ----------
sd_cmd23:
	kprintf "[sd_cmd23} NOT IMPLEMENTED"
	rts


; ----------
; sd_acmd41
; ----------
sd_acmd41:
	movem.l	d1-d6,-(sp)
	bsr.w	sd_wait_ready
	tst.w	d0
	beq	.fail
	SPI_SD_CMD $77,$0,$0,$0,$0,$65		; cmd55
	moveq	#8,d1

.response:
	bsr.w	spi_receive_byte		; r1
	cmp.w	#$FF,d0
	bne.w	.ok
	dbf	d1,.response
	kprintf	"[sd_acmd41] timeout"
	moveq	#0,d0
	rts					; time out

.ok:
	cmpi.w	#1,d0				; stil in IDLE?
	bgt	.fail
	bsr.w	sd_wait_ready
	SPI_SD_CMD $69,$40,$0,$0,$0,$FF		; amcd41
	moveq	#10,d6

.waitr1:
	bsr.w	spi_receive_byte
	cmp.w	#1,d0
	beq.b	.done
	dbf	d6,.waitr1

.fail:
	moveq	#0,d0

.done:
	movem.l	(sp)+,d1-d6
	rts

; ----------
; sd_cmd58
; ----------
sd_cmd58:
	bsr.w	sd_wait_ready
	SPI_SD_CMD $7A,$0,$0,$0,$0,$FF
	moveq	#8,d1

.response:
	bsr.w	spi_receive_byte
	cmp.w	#$FF,d0
	bne.s	.ok
	dbf	d1,.response
	moveq	#0,d0
	rts

.ok:
	moveq	#3,d1
	moveq	#0,d2
	
.readocr:
	bsr.w	spi_receive_byte
	and.b	#$FF,d0
	add.b	d0,d2
	lsl.l	#8,d2
	dbf	d1,.readocr
	moveq	#1,d0
	kprintf	"[sd_cmd58] ocr = %lx",d2
	and.l	#(1<<20)|(1<<21),d2
	beq.s	.done
	moveq	#0,d0
	kprintf	"[sd_cmd58] voltage not supported"
	
.done:
	rts
	
; ----------
; sd_wait_ready
; ----------
sd_wait_ready:
	movem.l	d6,-(sp)
	move.w	SPI_DATA(a6),d0
	move.l	#20,d6			; timeout

.wait:
	move.w	SPI_DATA(a6),d0
	cmp.w	#$FF,d0
	beq.s	.done
	dbf	d6,.wait
	moveq	#SD_ERROR_TIMEOUT,d0
	rts
	
.done:
	moveq	#SD_OK,d0
	movem.l	(sp)+,d6
	rts

; ------------------------------
;	SPI Functions
; ------------------------------

; ----------
; spi_wait
; ----------
spi_wait:
	move.w	#$FF,d1
	
.loop:
	move.w	SPI_REG(a6),d0
	btst	#7,d0			; busy?
	bne.b	.ok
	dbf	d1,.loop		; timeout?
		
.ok:
	rts

; ----------
; spi_send_byte
; ----------
spi_send_byte:
	move.w	d0,SPI_DATA(a6)
	bsr.w	spi_wait
	rts

; ----------
; spi_receive_byte
; ----------
spi_receive_byte:
	movem.l	d1-d2,-(sp)		; stack push
	move.w	#$FF,SPI_DATA(a6)
	bsr.w	spi_wait
	move.w	(SPI_DATA)(a6),d0
	movem.l	(sp)+,d1-d2		; stack pop
	rts
	
; ------------------------------
;	Device declaration
; ------------------------------
s_resident:
	dc.w	RTC_MATCHWORD		; rt_MatchWord
	dc.l	s_resident		; rt_MatchTags
	dc.l	s_codeend		; rt_EndSkip
	dc.b	RTF_AUTOINIT		; rt_Flags
	dc.b	FILE_VERSION		; rt_Version
	dc.b	NT_DEVICE		; rt_Type
	dc.b	0			; rt_Priority
	dc.l	s_name			; rt_Name
	dc.l	s_idstring		; rt_IdString
	dc.l	s_inittable		; rt_Init

s_name:
	dc.b	"replaysd.device",0
	dc.b	"$VER: "
	
s_idstring:
	dc.b	"replaysd.device 0.1 (03.01.2017)",LF,0
	dc.b	"Replay FPGA Arcade",0
	
	EVEN
	
s_inittable:
	dc.l	RSD_SIZEOF
	dc.l	s_functable
	dc.l	0				; no InitStruct() table
	dc.l	init_device
	
s_functable:
	dc.w	-1				; *offsets not pointers*
	dc.w	open_device-s_functable
	dc.w	close_device-s_functable
	dc.w	expunge_device-s_functable
	dc.w	Null-s_functable
	dc.w	begin_io-s_functable
	dc.w	abort_io-s_functable
	dc.w	-1
	
	EVEN

;
; ramlib/LoadDevice()
;
; d0 <- &device
; a0 <- SegList
; a6 <- &ExecBase
; d0 -> &Device or 0
init_device:
	kprintf "[SDDRIVER] Load Device"
;	move.l	a4,-(sp)
;	move.l	d0,a4				; Fill device struct info
;	move.l	a6,RSD_ExecBase(a4)
;	move.l	a0,RSD_SegList(a4)
;	move.b	#NT_DEVICE,LN_Type(a4)
;	lea	s_name(pc),a0
;	move.l	a0,LN_Name(a4)
;	move.b	#LIBF_SUMUSED+LIBF_CHANGED,LIB_Flags(a4)
;	move.b	#FILE_VERSION<<16+FILE_REVISION,LIB_Version(a4)
;	lea	s_idstring(pc),a0
;	move.l	a0,LIB_IdString(a4)		; TODO : base address
;	move.l	a4,d0				; Success 
;	move.l	(sp)+,a4
	rts
	
;
; exec/OpenDevice()
;
; d0 <- Unit#
; d1 <- Flags
; a0 <- devName
; a1 <- &IORequest
; a6 <- &Device
;
open_device:
	kprintf "[SDDRIVER] opening device"
	movem.l	d2-d3/a2-a4,-(sp)
	; TODO
	movem.l (sp)+,d2-d3/a2-a4
;	move.l	#IOERR_OPENFAIL,d0
	rts
	
;
; exec/CloseDevice()
;
; a1 <- &IORequest
; a6 <- &Device
; d0 -> SegList or 0
;
close_device:
	moveq #0,d0
	rts

; ----------
; expunge_device
; ----------
expunge_device:
	clr.l	d0
	rts

; ----------
; abort_io
; ----------
abort_io:
	clr.l	d0
	rts

; ----------
; Null
; ----------
Null:
	clr.l	d0
	rts


; ----------
; begin_io
;
; a1 <- &IORequest
; a6 <- &Device
; ----------
begin_io:
	movem.l	a2-a4,-(SP)
	move.l	a1,a2
	bsr.w 	.functiontable	
	
.ioend:
	movem.l (SP)+,a2-a4
	rts

.functiontable:
	clr.l	d0
	move.w	IO_COMMAND(a2),d0
	lsl.w 	#1,d0
	lea 	io_func_table,a0
	move.w 	(a0,d0),d0
;	bsr.w 	(d0)
	rts

io_func_table:
	dc.w	cmd_invalid-io_func_table		; CMD_INVALID		- *
	dc.w	cmd_reset-io_func_table			; CMD_RESET
	dc.w	cmd_read-io_func_table			; CMD_READ
	dc.w	cmd_write-io_func_table			; CMD_WRITE
	dc.w	cmd_invalid-io_func_table		; CMD_UPDATE		- *
	dc.w	cmd_invalid-io_func_table		; CMD_CLEAR		- *
	dc.w	cmd_stop-io_func_table			; CMD_STOP
	dc.w	cmd_start-io_func_table			; CMD_START
	dc.w	cmd_flush-io_func_table			; CMD_FLUSH
	dc.w	td_motor-io_func_table			; TD_MOTOR
	dc.w	cmd_invalid-io_func_table		; TD_SEEK		- *
	dc.w	cmd_invalid-io_func_table		; TD_FORMAT		- *
	dc.w	cmd_invalid-io_func_table		; TD_REMOVE		- *
	dc.w	cmd_invalid-io_func_table		; TD_CHANGENUM		- *
	dc.w	cmd_invalid-io_func_table		; TD_CHANGESTATE	- *
	dc.w	td_protect-io_func_table		; TD_PROTSTATUS
	dc.w	cmd_invalid-io_func_table		; TD_RAWREAD		- *
	dc.w	cmd_invalid-io_func_table		; TD_RAWWRITE		- *
	dc.w	td_get_drive_type-io_func_table		; TD_GETDRIVETYPE
	dc.w	cmd_invalid-io_func_table		; TD_GETNUMTRACKS	- *
	dc.w	cmd_invalid-io_func_table		; TD_ADDCHANGEINT	- *
	dc.w	cmd_invalid-io_func_table		; TD_REMCHANGEINT	- *
	dc.w	cmd_invalid-io_func_table		; TD_GETGEOMETRY	- *
	dc.w	cmd_invalid-io_func_table		; TD_EJECT		- *

; ----------
; cmd_invalid
; ----------
cmd_invalid:
	clr.l	d0
	rts

; ----------
; cmd_reset
; ----------
cmd_reset:
	clr.l	d0
	rts

; ----------
; cmd_read
; ----------
cmd_read:
	clr.l	d0
	rts

; ----------
; td_get_drive_type
; ----------
td_get_drive_type:
	move.w 	#0,IO_ERROR(a2)
	move.l 	#DG_DIRECT_ACCESS,IO_ACTUAL(a2)
	rts

; ----------
; td_protect
; ----------
td_protect:	
	clr.l	d0
	move.l	d0,IO_ACTUAL(a2)
	rts
		
; ----------
; cmd_write
; ----------
cmd_write:
	clr.l	d0
	rts
	
; ----------
; cmd_stop
; ----------
cmd_stop:
	clr.l	d0
	rts
	
; ----------
; cmd_start
; ----------
cmd_start:
	clr.l	d0
	rts	

; ----------
; td_motor
; ----------
td_motor:
	rts

; ----------
; cmd_flush
; ----------
cmd_flush:
	clr.l	d0
	rts

; ------------------------------
; Memory Functions
; ------------------------------
Malloc:
	movem.l d1-d7/a0-a6,-(sp)
	CALLEXEC AllocMem
	tst.l	d0
	bne.s	.success
	move.l	#-1,d0

.success:	
	movem.l (sp)+,d1-d7/a0-a6
	rts

MFree:
	movem.l d1-d7/a0-a6,-(sp)
	move.l	d1,a1
	CALLEXEC FreeMem
	tst.l	d0
	bne.s	.success
	move.l	#-1,d0

.success:
	movem.l (sp)+,d1-d7/a0-a6
	rts

; ------------------------------
;	    	 STRINGS
; ------------------------------

	EVEN

lib_expansion_name:
	EXPANSIONNAME

; ------------------------------
;	     VARIABLES
; ------------------------------

	EVEN

device_ctx:
	dc.l	0

	IFNE ENABLE_CMD_LINE_DEBUG

; only use of testing purpose
debug_scratch:
	dcb.b 	SD_BLOCK_SIZE

	ENDC

; ------------------------------
;	     	END
; ------------------------------

s_codeend:
	end
