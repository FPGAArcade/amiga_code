ENABLE_KPRINTF

	include	"enc624.i"
	include "kprintf.i"

HW_ResetEth:
		kprintf	"Reset ETH"
		lea	($40000000+$00300000),a0

		kprintf	" > Wait EUDAST stable.."

; 1. Write 1234h to EUDAST.
; 2. Read EUDAST to see if it now equals 1234h. If
; it does not, the SPI/PSP interface may not be
; ready yet, so return to step 1 and try again.

		moveq.l	#100,d1
		move.w	#$1234,d0
.notrdy		move.w	d0,(EUDAST,a0)
		cmp.w	(EUDAST,a0),d0
		beq.b	.psprdy
		bsr	Wait25us
		dbf	d1,.notrdy
		bra	.error

.psprdy
		kprintf	" > Write/Readback .."
		moveq.l	#0,d0
		moveq.l	#0,d1
		moveq.l	#0,d2
		moveq.l	#0,d3
		moveq.l	#0,d4
		moveq.l	#0,d5
		move.w	#32-1,d0
.rwtest		move.w	d0,d1
		and.l	#%11111,d1
		or.w	#$100,d1	; reserved bit 8, set high
		move.w	d1,(MIREGADR,a0)
		move.w	(MIREGADR,a0),d2
		move.w	(MIREGADR,a0),d3
		move.w	(MIREGADR,a0),d4
		move.w	(MIREGADR,a0),d5
		bsr	Wait25us
		kprintf	" > %04lx vs %04lx,%04lx,%04lx,%04lx",d1,d2,d3,d4,d5
;		cmp.w	d1,d0
;		bne	.error
		dbf	d0,.rwtest

		kprintf	" > Wait CLKRDY .."

; 3. Poll CLKRDY (ESTAT<12>) and wait for it to
; become set.

		moveq.l	#100,d1
.noclk		btst	#ESTATB_CLKRDY,(ESTATH,a0)
		bne.b	.clkrdy
		bsr	Wait25us
		dbf	d1,.noclk
		bra	.error

.clkrdy
		kprintf	" > Issue a System Reset .."

; 4. Issue a System Reset command by setting
; ETHRST (ECON2<4>).
; 5. In software, wait at least 25 s for the Reset to
; take place and the SPI/PSP interface to begin
; operating again.

		moveq.l	#100,d1
		move.w	#ECON2F_ETHRST,(ECON2SET,a0)
.waitrst	bsr	Wait25us
		btst	#ECON2B_ETHRST,(ECON2L,a0)
		beq.b	.resetok
		dbf	d1,.waitrst
		bra	.error

.resetok
		kprintf	" > Check EUDAST .."

; 6. Read EUDAST to confirm that the System Reset
; took place. EUDAST should have reverted back
; to its Reset default of 0000h.

		tst.w	(EUDAST,a0)
		bne	.error

		kprintf	" > Wait PHY .."

; 7. Wait at least 256 s for the PHY registers and
; PHY status bits to become available

		bsr	Wait250us


		kprintf	" > Reset PHY .."

; 7.5  PHY Subsystem Reset
; The PHY module may be reset by setting the PRST bit
; (PHCON1<15>). The PHY register contents all revert
; to their default values.

; * The POR and System Resets automatically perform a
; * PHY Reset, so this step does not need to be performed
; * after a System or Power-on Reset. 

		moveq.l	#PHCON1,d0
		move.w	#PHCON1F_PRST,d1
		bsr	HW_WritePhy

; It is recom mended that, after issuing a Reset, the host controller
; polls PRST and waits for it to be cleared by hardware
; before using the PHY.

		kprintf	" > Wait PHY .."

		moveq.l	#100,d7
.waitphy	moveq.l	#PHCON1,d0
		bsr	HW_ReadPhy
		and.w	#PHCON1F_PRST,d0
		beq.b	.ok
		bsr	Wait25us
		dbf	d7,.waitphy

		bra	.error

.ok
	; read PHY regs

		moveq.l	#PHCON1,d0
		bsr	HW_ReadPhy
		kprintf	" > PHCON1  = $%04lx ($1000)",d0

		moveq.l	#PHSTAT1,d0
		bsr	HW_ReadPhy
		kprintf	" > PHSTAT1 = $%04lx ($7809)",d0

		moveq.l	#PHANA,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANA   = $%04lx ($01e1)",d0

		moveq.l	#PHANLPA,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANLPA = $%04lx ($xxxx)",d0

		moveq.l	#PHANE,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANE   = $%04lx ($0000)",d0

		moveq.l	#PHCON2,d0
		bsr	HW_ReadPhy
		kprintf	" > PHCON2  = $%04lx ($0002)",d0

		moveq.l	#PHSTAT2,d0
		bsr	HW_ReadPhy
		kprintf	" > PHSTAT2 = $%04lx ($xx0x)",d0

		moveq.l	#PHSTAT3,d0
		bsr	HW_ReadPhy
		kprintf	" > PHSTAT3 = $%04lx ($0040)",d0

	; DONE

		kprintf	" > Reset done."
		move.l	#0,d0
		rts

.error:		kprintf " > Reset failed."
		move.l	#1337,d0
		rts

Wait25us:	move.l	d0,-(sp)
		move.w	#25,d0
.wait		tst.b	$bfe001		; approx 1us
		dbf	d0,.wait
		move.l	(sp)+,d0
		rts

Wait250us:	move.w	d0,-(sp)
		move.w	#250,d0
.wait		tst.b	$bfe001		; approx 1us
		dbf	d0,.wait
		move.w	(sp)+,d0
		rts

HW_ReadPhy:	
; To read from a PHY register:
; 1. Write the address of the PHY register to read
; from into the MIREGADR register
; (Register 3-1). Make sure to also set reserved
; bit 8 of this register.
; 2. Set the MIIRD bit (MICMD<0>, Register 3-2).
; The read operation begins and the BUSY bit
; (MISTAT<0>, Register 3-3) is automatically set
; by hardware.
; 3. Wait 25.6 s. Poll the BUSY (MISTAT<0>) bit to
; be certain that the operation is complete. While
; busy, the host controller should not start any
; MIISCAN operations or write to the MIWR
; register. When the MAC has obtained the register
; contents, the BUSY bit will clear itself.
; 4. Clear the MIIRD (MICMD<0>) bit.
; 5. Read the desired data from the MIRD register.
; For 8-bit interfaces, the order that these bytes
; are read is unimportant.

;		move.l	g_MachEnc(a6),a0

		and.l	#%11111,d0
;		kprintf "Read PHY reg $%lx",d0

		or.w	#$100,d0	; reserved bit 8, set high

		moveq.l	#10,d1
.busy		move.w	d0,(MIREGADR,a0)
		bsr	Wait25us
		bset	#MICMDB_MIIRD,(MICMDL,a0)

		bsr	Wait25us

		btst	#MISTATB_BUSY,(MISTATL,a0)
		beq.b	.done

		bsr	Wait25us
		dbf	d1,.busy
		bra.b	.error

.done
		bsr	Wait25us
		bclr	#MICMDB_MIIRD,(MICMDL,a0)
		bsr	Wait25us
		move.w	(MIRD,a0),d0
;		kprintf " > $%lx",d0
		rts

.error:		kprintf " > PHY read %lx failed.",d0
		moveq.l	#-1,d0
		rts

HW_WritePhy:
; To write to a PHY register:
; 1. Write the address of the PHY register to write to
; into the MIREGADR register. Make sure to also
; set reserved bit 8 of this register.
; 2. Write the 16 bits of data into the MIWR register.
; The low byte must be written first, followed by
; the high byte.
; 3. Writing to the high byte of MIWR begins the
; MIIM transaction and the BUSY (MISTAT<0>)
; bit is automatically set by hardware.

;		move.l	g_MachEnc(a6),a0

		and.l	#%11111,d0
;		kprintf "Write PHY reg $%lx data %lx",d0,d1

		or.w	#$100,d0	; reserved bit 8, set high

		bsr	Wait25us
		move.w	d0,(MIREGADR,a0)
		bsr	Wait25us
		move.w	d1,(MIWR,a0)
		bsr	Wait25us

		moveq.l	#10,d1
.busy		bsr	Wait25us
		btst	#MISTATB_BUSY,(MISTATL,a0)
			beq.b	.done
		dbf	d1,.busy
		bra.b	.error

.done		bsr	HW_ReadPhy		; not needed
		rts

.error:		kprintf " > PHY write %lx failed.",d0
		moveq.l	#-1,d0
		rts
