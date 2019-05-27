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

	AUTO wo sddriver:replaysd.device\

; ------------------------------
;	     Includes
; ------------------------------

ENABLE_KPRINTF

	INCDIR 	"Include3.0:Include/"		; from devpac3
	INCLUDE	exec/exec_lib.i
	INCLUDE exec/errors.i
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
SD_CARD_NONE		equ	0
SD_CARD_V1		equ 	1
SD_CARD_V2		equ 	2
SD_CARD_SDHC		equ	3

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
SD_OK				equ	0
SD_ERROR_WAIT_READY_TIMEOUT	equ	1
SD_ERROR_INIT_FAILED		equ	2
SD_ERROR_CMD0			equ	3
SD_ERROR_INIT_V1		equ	4

SPI_SLOW_SPEED		equ	$28
SPI_HIGH_SPEED		equ	$0

SPI_SR_BUSY		equ 	(1<<0)

TIMER_TICK_FREQ		equ	50
SD_TIMEOUT_RDY		equ	26		; (((uint32_t)(500)*(TIMER_TICK_FREQ)+999)/1000)

; SD Card CID
	RSRESET

sd_cid_mfr_id		rs.b 	1
sd_cid_app_id		rs.b 	2
sd_cid_product_name 	rs.b 	5
sd_cid_product_rev 	rs.b 	1
sd_cid_product_sn	rs.l 	1
sd_cid_mfr_date 	rs.w 	1
sd_cid_crc		rs.b 	1
sd_cid_struct_size 	rs.b 	0

; SD Card CSD
	RSRESET

sd_csd_structure	rs.b	1		; some info could be bit packed
sd_csd_taac		rs.b	1
sd_csd_nsac		rs.b	1
sd_csd_tran_speed	rs.b	1
sd_csd_ccc		rs.w	1
sd_csd_read_bl_len	rs.b	1
sd_csd_read_bl_partial	rs.b	1
sd_csd_write_blk_mislgn	rs.b	1
sd_csd_read_blk_mislgn	rs.b	1
sd_csd_dsr_imp		rs.b	1
sd_csd_c_size		rs.w	1
sd_csd_vdd_r_curr_min	rs.b	1
sd_csd_vdd_r_curr_max	rs.b	1
sd_csd_vdd_w_curr_min	rs.b	1
sd_csd_vdd_w_curr_max	rs.b	1
sd_csd_c_size_mult	rs.b	1
sd_csd_erase_blk_len	rs.b	1
sd_csd_sector_size	rs.b	1
sd_csd_wp_grp_size	rs.b	1
sd_csd_wp_grp_enable	rs.b	1
sd_csd_r2w_factor	rs.b	1
sd_csd_write_bl_len	rs.b	1
sd_csd_write_bl_partial rs.b	1
sd_csd_file_frmt_grp	rs.b	1
sd_csd_copy		rs.b	1
sd_csd_perm_wrt_prot	rs.b	1
sd_csd_tmp_wrt_prot	rs.b	1
sd_csd_file_format	rs.b	1
sd_csd_crc		rs.b	1
sd_csd_struct_size	rs.b	0

; SD Card driver struct
	RSRESET

device_spi_base		rs.l	1
device_device		rs.l	1
device_unit		rs.b	UNIT_SIZE
sd_card_type		rs.b	1
sd_cid_descr		rs.b	sd_cid_struct_size
sd_csd_descr		rs.b	sd_csd_struct_size
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

	kprintf	"[SDDriver] test mode"
	bsr.w	init
;	bsr.w 	test_sd
	bsr.w	cleanup
.finish:
	moveq.l	#0,d0
	kprintf "----------"

	ELSE
	
	moveq.l	#-1,d0 				; error should not be launched from shell
	
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
	move.l	4.w,a4
	bsr.w 	find_card			; todo: handle fail
	bsr.w	init_sd
	cmp.b 	#SD_ERROR_INIT_FAILED,d0
	beq.s	.fail
	bsr.w	show_cid			; for debugging
	bsr.w	show_csd
	rts
.fail:
	SPI_DEASSERT_CS
	kprintf	"*** INIT FAILED *** %ld",d0
	rts

; ----------
; cleanup
; ----------
cleanup:
	tst.l	device_ctx(pc)
	beq.s	.finished
	move.l	#device_struct_size,d0
	movea.l	device_ctx,a1	
	jsr	MFree
	move.l	#0,a1
.finished:
	rts

; ----------
; init_card
; a4 => execlibrary base
; ----------	
find_card:
	movem.l	d1-d6/a0-a6,-(SP)
	kprintf "[SDDriver] Looking for replaysd card"
	lea	lib_expansion_name(pc),a1
	move.l	a1,d0
	CALLEXEC OpenLibrary
	tst.l	d0
	bne.s	.findconfig
	kprintf	"[SDDriver] cannot open expansion library"
	bra.w	.failed
.findconfig:
	move.l	d0,a6
	move.l	#REPLAY_MANUFACTURER,d0
	move.l 	#REPLAY_PRODUCT,d1
	move.l	#0,a0
	jsr	_LVOFindConfigDev(a6)
	tst	d0
	bne.s	.initdev
	kprintf	"[SDDriver]cannot find device"
	bra.w	.failed
.initdev:
	move.l	d0,a0				; card base address
	move.l	#device_struct_size,d0
	move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
	jsr	Malloc
	tst	d0
	bne.s	.fill_device
	kprintf	"[SDDriver] cannot allocate memory"
	bra.w	.failed
.fill_device:
	move.l	d0,device_ctx
	move.l	d0,a1				; struct address
	move.l	cd_BoardAddr(a0),device_spi_base(a1)
	move.l 	a0,d0
	move.l	d0,device_device(a1)
	kprintf	"[find_card] base address = %lx",d0
	move.l	device_spi_base(a1),d0
	kprintf	"[find_card] spi base address = %lx",d0
	bra.s	.cleanup
.failed:
	kprintf "[SDDriver][ERROR] no card found!"
	moveq	#0,d0
.cleanup:
	move.l	a6,a1
	CALLEXEC CloseLibrary
	jsr	_LVOCloseLibrary(a4)
	movem.l	(SP)+,d1-d6/a0-a6
	rts

; ------------------------------
;	SD Functions
; ------------------------------

; ----------
; init_sd
; ----------
init_sd:
	movem.l	d1-d6/a0-a6,-(SP)
	move.l	device_ctx,a0
	movea.l	device_spi_base(a0),a6
	SPI_DEASSERT_CS
	SPI_SET_SPEED SPI_SLOW_SPEED		; set spi clock to about 110khz
	SPI_ASSERT_CS
	moveq	#$10,d6				; wait for 88 cycles
	
.wait:
	move.w	#$FF,d0
	bsr.w 	spi_send_byte
 	dbf	d6,.wait
	SPI_DEASSERT_CS
	move.w	#$FF,d0
	bsr.w 	spi_send_byte
	move.w	#$FF,d0
	bsr.w 	spi_send_byte
	SPI_ASSERT_CS
	move.l	#$FF,d6				; send CMD0 for IDLE and SPI

.cmd0:
	bsr.w	sd_cmd0
	cmp.b	#$1,d0
	beq.s	.cmd0_ok
	dbf	d6,.cmd0
	kprintf	"[init_sd] cmd0 failed %ld",d0
	moveq	#SD_ERROR_INIT_FAILED,d0
	bra.w	.done
	
.cmd0_ok:
	kprintf "[init_sd] SD card in IDLE mode"
	bsr.w 	sd_cmd8				; send CMD8
	cmp.b 	#$1,d0 				; v2 version?
	bne.w 	.v1_init
	bsr.w 	sd_get_r7			; check voltage
	cmp.l	#$1AA,d0
	beq.s 	.v2_init
	moveq	#SD_ERROR_INIT_FAILED,d0
	bra.w	.done

.v2_init:
	kprintf	"[init_sd] sd v2 found"
	move.l	#$FF,d6

.acmd41:
	bsr.w 	sd_acmd41			; init V2 SD Card
	btst	#0,d0
	beq.s	.acmd41success
	dbf	d6,.acmd41
	kprintf	"[init_sd] acmd41 timeout"
	moveq	#SD_ERROR_INIT_FAILED,d0				; failed
	bra.w	.done

.acmd41success:
	bsr.w 	sd_cmd58			; read OCR
	cmp.b	#0,d0
	beq.s	.readocr
	kprintf	"[init_sd] sd_cmd58 failed $%lx",d0
	moveq	#SD_ERROR_INIT_FAILED,d0
	bra.w	.done

.readocr:
	bsr.w	sd_get_r7
	kprintf	"[init_sd] reading ocr $%lx",d0
	and.l	#(1<<30),d0
	beq.s	.finish
	kprintf	"[init_sd] SDHC detected"
	bra.s	.finish

.v1_init:
	kprintf	"[init_sd] sd v1 found cmd8 r1 : %ld",d0
	moveq	#SD_ERROR_INIT_V1,d0				; fail as not supported * TODO *
	bra.w	.done
	
.finish:
	kprintf	"[init_sd] SD Card ready"
	bsr.w	sd_cmd10
	cmp.b	#0,d0
	beq.s	.decode_card
	kprintf	"[init_sd] sd_cmd10 failed $%lx",d0
	moveq	#SD_ERROR_INIT_FAILED,d0
	bra.w	.done
	
.decode_card:
	kprintf "[init_sd] reading block"
	bsr.w	sd_read_cid
	cmp.b	#0,d0
	beq.s	.read_csd
	kprintf	"[init_sd] failed to read csd"

.read_csd:
	bsr.w	sd_cmd9
	cmp.b	#0,d0
	beq.s	.decode_csd
	kprintf	"[init_sd] sd_cmd9 failed $%lx",d0
	moveq	#SD_ERROR_INIT_FAILED,d0
	bra.s	.done

.decode_csd:
	bsr	sd_read_csd
	SPI_DEASSERT_CS
	SPI_SET_SPEED SPI_HIGH_SPEED		; spi maximum clock speed
	moveq	#SD_OK,d0			; sucess

.done:
	movem.l	(SP)+,d1-d6/a0-a6
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
	movem.l	d1-d6,-(SP)
	bsr.w	sd_wait_ready
	SPI_SD_CMD $40,$0,$0,$0,$0,$95
	bsr.w	spi_wait_r1
	movem.l	(SP)+,d1-d6
	rts

; ----------
; sd_cmd1
; ----------
sd_cmd1:
	kprintf	"[sd_cmd1] NOT IMPLEMENTED"
	rts

; ----------
; sd_cmd8
; Only for SDC V2
; ----------
sd_cmd8:
	movem.l d1-d6,-(SP)
	bsr.w	sd_wait_ready
	SPI_SD_CMD $48,$0,$0,$01,$AA,$87
	bsr.w	spi_wait_r1
	movem.l (SP)+,d1-d6
	rts

sd_read_uint:
	movem.l	d1,-(SP)
	moveq	#0,d0
	moveq	#0,d1
	bsr.w 	spi_receive_byte	; d0 = x
	move.b 	d0,d1 			; d1 = x
	lsl.w 	#8,d1 			; d1 = (x<<8)
	bsr.w 	spi_receive_byte	; d0 = y
	move.b 	d0,d1 			; d1.b = y
	swap 	d1 			; d1 = xy00
	bsr.w 	spi_receive_byte
	lsl.w	#8,d0
	move.w 	d0,d1
	bsr.w 	spi_receive_byte
	move.b 	d0,d1
	move.l	d1,d0
	movem.l	(SP)+,d1
	rts

; ----------
; show_cid
; ----------
show_cid:
	movem.l d0-d6/a0-a6,-(SP)
	moveq	#0,d0
	moveq	#0,d1
	move.l	device_ctx(pc),a0
	lea	sd_cid_descr(a0),a0
	move.b	sd_cid_mfr_id(a0),d0
	kprintf	"[CID] Manufacturer ID:0x%lx",d0
	move.b	sd_cid_app_id(a0),d0
	move.b	sd_cid_app_id+1(a0),d1
	kprintf	"[CID] App ID 0x%lx%lx",d0,d1
	move.b	sd_cid_product_name(a0),d0
	move.b	sd_cid_product_name+1(a0),d1
	move.b	sd_cid_product_name+2(a0),d2
	move.b	sd_cid_product_name+3(a0),d3
	move.b	sd_cid_product_name+4(a0),d4
	kprintf "[CID] Product name %c%c%c%c%c",d0,d1,d2,d3,d4
	move.l	sd_cid_product_sn(a0),d0
	kprintf "[CID] Product S/N 0x%lx",d0
	moveq	#0,d0
	move.b	sd_cid_product_rev(a0),d0
	kprintf "[CID] Product rev %ld",d0
	move.w	sd_cid_mfr_date(a0),d0
	kprintf "[CID] Manufacturer date 0x%lx",d0
	moveq	#0,d0
	move.b	sd_cid_crc(a0),d0
	kprintf "[CID] CRC7 Checksum 0x%lx",d0
	movem.l (SP)+,d0-d6/a0-a6
	rts

; ----------
; show_csd
; ----------
show_csd:
	movem.l d0-d6/a0-a6,-(SP)
	moveq	#0,d0
	moveq	#0,d1
	move.l	device_ctx(pc),a0
	lea	sd_csd_descr(a0),a0
	move.b	sd_csd_structure(a0),d0
	kprintf "[CSD] Structure %lx",d0
	move.b	sd_csd_taac(a0),d0
	kprintf "[CSD] Taac %lx",d0
	move.b	sd_csd_nsac(a0),d0
	kprintf "[CSD] Nsac %lx",d0
	move.b	sd_csd_tran_speed(a0),d0
	kprintf "[CSD] Max transfert rate 0x%lx",d0
	
	movem.l (SP)+,d0-d6/a0-a6
	rts

; ----------
; sd_wait_data_stream
; ----------
sd_wait_data_stream:
	bsr.w	spi_receive_byte
	cmp.b	#$FF,d0
	beq.s	sd_wait_data_stream
	rts

; ----------
; sd_read_cid
; ----------
sd_read_cid:
	movem.l	d1-d6,-(SP)
	bsr.w	sd_wait_data_stream	; now waiting for the datastream
	cmp.b	#$FE,d0
	beq.s	.read_data
	moveq	#1,d0
	bra.w	.finish
.read_data:
	bsr.w	sd_read_uint
	move.l	d0,d1
	bsr.w	sd_read_uint
	move.l	d0,d2
	bsr.w	sd_read_uint
	move.l	d0,d3
	bsr.w	sd_read_uint
	move.l	d0,d4
	bsr.w	sd_read_uint				; Read CRC but we dont use it
	bsr.w	sd_read_uint
	move.l	device_ctx(pc),a0
	lea	sd_cid_descr(a0),a0
	kprintf	"[CID]: $%lx $%lx $%lx $%lx",d1,d2,d3,d4
	move.l	d1,d6					; manufacturer
	swap	d6
	lsr.w	#8,d6
	and.b	#$FF,d6
	move.b	d6,sd_cid_mfr_id(a0)
	move.l	d1,d6					; app id
	lsr.l	#8,d6
	move.b	d6,sd_cid_app_id+1(a0)
	lsr.w	#8,d6
	move.b	d6,sd_cid_app_id+0(a0)
	move.l	d1,d6					; product name
	move.b	d6,sd_cid_product_name+0(a0)
	move.l	d2,d6
	move.b	d6,sd_cid_product_name+4(a0)
	lsr.w	#8,d6
	move.b	d6,sd_cid_product_name+3(a0)
	swap	d6
	move.b	d6,sd_cid_product_name+2(a0)
	lsr.w	#8,d6
	move.b	d6,sd_cid_product_name+1(a0)
	move.l	d3,d6					; product sn
	lsl.l	#8,d6
	andi.l	#$FFFFFF00,d6
	move.l	d4,d5
	swap	d5
	lsr.w	#8,d5
	or.b	d5,d6
	move.l	d6,sd_cid_product_sn(a0)
	move.l	d3,d6					; product rev
	swap	d6
	lsr.w	#8,d6
	move.b	d6,sd_cid_product_rev(a0)
	move.l	d4,d6					; mfg date
	lsr.l	#8,d6
	andi.l	#$FFF,d6
	move.w	d6,sd_cid_mfr_date(a0)
	move.l	d4,d6					; crc
	lsr.l	#1,d6
	andi.l	#$7F,d6
	move.b	d6,sd_cid_crc(a0)
	moveq	#0,d0
.finish:
	movem.l	(SP)+,d1-d6
	rts

; ----------
; sd_read_csd
; ----------
sd_read_csd:
	movem.l	d1-d6,-(SP)
	bsr.w	sd_wait_data_stream	; now waiting for the datastream
	cmp.b	#$FE,d0
	beq.s	.read_data
	moveq	#1,d0
	bra.w	.finish
.read_data:
	bsr.w	sd_read_uint
	move.l	d0,d1
	bsr.w	sd_read_uint
	move.l	d0,d2
	bsr.w	sd_read_uint
	move.l	d0,d3
	bsr.w	sd_read_uint
	move.l	d0,d4
	bsr.w	sd_read_uint				; Read CRC but we dont use it
	bsr.w	sd_read_uint
	move.l	device_ctx(pc),a0
	lea	sd_csd_descr(a0),a0
	kprintf	"[CSD]: $%lx $%lx $%lx $%lx",d1,d2,d3,d4
	move.l	d1,d6					; max transfert rate
	move.b	d6,sd_csd_tran_speed(a0)
	lsl.w	#8,d6					; nsac
	move.b	d6,sd_csd_nsac(a0)
	swap	d6					; taac
	move.b	d6,sd_csd_taac(a0)
	lsr.w	#8,d6					; csd struct
	lsr.w	#6,d6
	move.b	d6,sd_csd_structure(a0)
	moveq	#0,d0
.finish:
	movem.l	(SP)+,d1-d6
	rts

; ----------
; sd_cmd9
; ----------
sd_cmd9:
	bsr.w	sd_wait_ready
	SPI_SD_CMD $49,$0,$0,$0,$0,$1
	bsr.w	spi_wait_r1
	rts

; ----------
; sd_cmd10
; ----------
sd_cmd10:
	bsr.w	sd_wait_ready
	SPI_SD_CMD $4A,$0,$0,$0,$0,$1
	bsr.w	spi_wait_r1
	rts

; ----------
; sd_get_r7
; ----------
sd_get_r7:
	moveq	#0,d0
	moveq	#0,d1
	bsr.w 	spi_receive_byte	; d0 = x
	move.b 	d0,d1 			; d1 = x
	lsl.w 	#8,d1 			; d1 = (x<<8)
	bsr.w 	spi_receive_byte	; d0 = y
	move.b 	d0,d1 			; d1.b = y
	swap 	d1 			; d1 = xy00
	bsr.w 	spi_receive_byte
	lsl.w	#8,d0
	move.w 	d0,d1
	bsr.w 	spi_receive_byte
	move.b 	d0,d1
	move.l	d1,d0
	rts

; ----------
; sd_cmd23
; ----------
sd_cmd23:
	kprintf "[sd_cmd23] NOT IMPLEMENTED"
	rts

; ----------
; sd_acmd41
; ----------
sd_acmd41:
	movem.l	d1-d6,-(sp)
	bsr.w	sd_wait_ready
	SPI_SD_CMD $77,$0,$0,$0,$0,$FF		; cmd55
	bsr.w	spi_wait_r1
	cmp.b	#$1,d0
	bgt	.fail
	bsr.w	sd_wait_ready
	SPI_SD_CMD $69,$40,$0,$0,$0,$FF		; amcd41
	bsr.w	spi_wait_r1
	bra.s	.done
	
.fail:
	moveq	#0,d0
	kprintf "[sd_acmd41] fail"

.done:
	movem.l	(sp)+,d1-d6
	rts

; ----------
; sd_cmd58
; ----------
sd_cmd58:
	bsr.w	sd_wait_ready
	SPI_SD_CMD $7A,$0,$0,$0,$0,$FF
	bsr.w	spi_wait_r1
	rts
	
;	moveq	#8,d1
;.response:
;	bsr.w	spi_receive_byte
;	cmp.w	#$FF,d0
;	bne.s	.ok
;	dbf	d1,.response
;	moveq	#0,d0
;	rts
;.ok:
;	moveq	#3,d1
;	moveq	#0,d2
;	
;.readocr:
;	bsr.w	spi_receive_byte
;	and.b	#$FF,d0
;	add.b	d0,d2
;	lsl.l	#8,d2
;	dbf	d1,.readocr
;	moveq	#1,d0
;	kprintf	"[sd_cmd58] ocr = %lx",d2
;	and.l	#(1<<20)|(1<<21),d2
;	beq.s	.done
;	moveq	#0,d0
;	kprintf	"[sd_cmd58] voltage not supported"
;	
;.done:
;	rts

; ----------
; sd_wait_ready
; ----------
sd_wait_ready:
	movem.l	d1-d6,-(sp)
	bsr.w	spi_receive_byte
	bsr.w 	get_tick_count
	move.l 	d0,d6 				; timer start
	move.w	SPI_DATA(a6),d0
.wait:
	bsr.w	spi_receive_byte
	cmp.w	#$FF,d0
	beq.s	.success
	bsr.w 	get_tick_count
	move.l 	d6,d1
	sub.l 	d0,d1
	cmp.l 	#SD_TIMEOUT_RDY,d1
	blt.s 	.wait
	moveq	#SD_ERROR_WAIT_READY_TIMEOUT,d0
	kprintf	"[sd_wait_ready] timeout"
	bra.s 	.done
.success:
	moveq	#SD_OK,d0
.done:
	movem.l	(sp)+,d1-d6
	rts

; ----------
; get_tick_count
; ----------
get_tick_count:
	moveq	#0,d0
	move.b 	$bfea01,d0
	swap 	d0
	move.b 	$bfe901,d0
	lsl.w 	#8,d0
	move.b 	$bfe801,d0
	rts

; ------------------------------
;	SPI Functions
; ------------------------------

; ----------
; spi_wait
; ----------
spi_wait:
	move.w	SPI_REG(a6),d0
	btst	#7,d0
	beq.s	spi_wait
	rts

; ----------
; spi_send_byte
; ----------
spi_send_byte:
	move.w	d0,SPI_DATA(a6)
	bsr.w	spi_wait
	rts

spi_delay:
	move.w	#$FF,SPI_DATA(a6)
	bsr.w	spi_wait
	rts
	
; ----------
; spi_receive_byte
; ----------
spi_receive_byte:
	bsr.w	spi_delay
	move.w	(SPI_DATA)(a6),d0
	and.w	#$FF,d0
	rts

; ----------
; spi_wait_r1
; ----------
spi_wait_r1:
	movem.l	d1-d2,-(SP)
	moveq	#20,d2
.l:
	bsr.w	spi_receive_byte
	btst	#7,d0
	beq.s	.done
	dbf	d2,.l
.done:
	movem.l	(SP)+,d1-d2
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
	kprintf "[SDDRIVER] Init Device"
	move.l	a6,d1
	move.l	a4,-(SP)
	move.l	d0,a4
	bsr.w	find_card
	cmp.b	#0,d0
	beq.w	.error
	lea	device_ctx(pc),a0
	move.l	a4,d0
	move.l	d0,device_device(a0)		; set device pointer
	bsr.w	init_sd
;	move.l	a6,RSD_ExecBase(a4)
;	move.l	a0,RSD_SegList(a4)
;	move.b	#NT_DEVICE,LN_Type(a4)
	lea	s_name(pc),a0
	move.l	a0,LN_NAME(a4)
	move.b	#LIBF_SUMUSED+LIBF_CHANGED,LIB_FLAGS(a4)
	move.l	#FILE_VERSION<<16+FILE_REVISION,LIB_VERSION(a4)
	lea	s_idstring(pc),a0
	move.l	a0,LIB_IDSTRING(a4)
	move.l	d0,a4
	moveq	#1,d0
.error:
	kprintf	"[SDDRIVER] failed init_device"
	moveq	#0,d0
.finish:
	movem.l	(sp)+,a4
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
	tst.l	a1
	beq.s	.fail
	cmp.l	#0,d0
	beq.s	.fail
	bsr.w	init_sd
	cmp.l	#SD_OK,d0
	bne.s	.fail
	lea	device_ctx(pc),a2
	lea	device_unit(a2),a2
	move.l	a2,d2
	move.l	d2,IO_UNIT(a1)			; set pointer to our unit
	move.b	#UNITF_ACTIVE,UNIT_FLAGS(a2)	; update device struct
	move.w	#1,UNIT_OPENCNT(a2)	
	moveq	#0,d0				; all ok
	bra.s	.done
.fail:
	move.l	#IOERR_OPENFAIL,d0
.done:
	movem.l (sp)+,d2-d3/a2-a4
	rts
	
;
; exec/CloseDevice()
;
; a1 <- &IORequest
; a6 <- &Device
; d0 -> SegList or 0
;
close_device:
	kprintf "[SDDriver] Close Device"
	moveq #0,d0
	rts

; ----------
; expunge_device
; ----------
expunge_device:
	kprintf "[SDDriver] expunge device"
	clr.l	d0
	rts

; ----------
; abort_io
; ----------
abort_io:
	kprintf "[SDDriver] abort io"
	clr.l	d0
	rts

; ----------
; Null
; ----------
Null:
	kprintf "[SDDriver] null"
	clr.l	d0
	rts


; ----------
;
; a1 <- &IORequest
; a6 <- &Device
; ----------
begin_io:
	movem.l	a2-a4,-(SP)
	kprintf "[SDDriver] begin IO"
	move.b	#0,IO_ERROR(a1)
	clr.l	d0
	move.w	IO_COMMAND(a1),d0
	cmp.w	#24,d0
	blt.s	.do_io
	kprintf "skipping command"
	bra.w	.noio

.do_io:
	lsl.l 	#1,d0
	lea 	io_func_table(pc),a6
	move.l	a6,d1
	clr.l	d1
	move.w	(a6,d0.l),d1
	add.w	(a6,d0.l),a6
	move.l	a6,d0
	jsr	(a6)

.noio:
	movem.l (SP)+,a2-a4
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
io_func_table_end:

; ----------
; cmd_invalid
; ----------
cmd_invalid:
	kprintf "[SDDriver] cmd invalid"
	move.b #0,IO_ERROR(a1)
	rts

; ----------
; cmd_reset
; ----------
cmd_reset:
	kprintf "[SDDriver] cmd reset"
	clr.l	d0
	rts

; ----------
; cmd_read
; ----------
cmd_read:
	kprintf "[SDDriver] cmd read"
	clr.l	d0
	rts

; ----------
; td_get_drive_type
; ----------
td_get_drive_type:
	kprintf "[SDDriver] get drive type"
	move.w 	#IOERR_NOCMD,IO_ERROR(a2)
	move.l 	#DG_DIRECT_ACCESS,IO_ACTUAL(a2)
	rts

; ----------
; td_protect
; ----------
td_protect:	
	kprintf "[SDDriver] td prorect"
	clr.l	d0
	move.l	d0,IO_ACTUAL(a2)
	rts
		
; ----------
; cmd_write
; ----------
cmd_write:
	kprintf "[SDDriver] cmd write"
	clr.l	d0
	rts
	
; ----------
; cmd_stop
; ----------
cmd_stop:
	kprintf "[SDDriver] cmd stop"
	clr.l	d0
	rts
	
; ----------
; cmd_start
; ----------
cmd_start:
	kprintf "[SDDriver] cmd start"
	clr.l	d0
	rts	

; ----------
; td_motor
; ----------
td_motor:
	kprintf "[SDDriver] td motor"
	rts

; ----------
; cmd_flush
; ----------
cmd_flush:
	kprintf "[SDDriver] cmd flush"
	clr.l	d0
	rts

; ------------------------------
; Memory Functions
; ------------------------------
Malloc:
	movem.l d1-d7/a0-a6,-(sp)
;	jsr	_LVOAllocMem(a4)
	CALLEXEC AllocMem
	tst.l	d0
	bne.s	.success
	move.l	#-1,d0

.success:	
	movem.l (sp)+,d1-d7/a0-a6
	rts

MFree:
	movem.l d1-d7/a0-a6,-(sp)
;	jsr	_LVOFreeMem(a4)
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
