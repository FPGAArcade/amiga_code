
; Example program
; This runs a 5-cycle code loop for N iterations (provided in D0),
; and then returns (in D0) the number of CPU cycles used.

	PUBLIC	_runAsmCode

_runAsmCode:

	bset.b	#1,$bfe001		; trigger logic analyzer
	tst.b	$bfe001			; delay due to SIO on the 060db
	move.l	$40400000,a0		; sample cpu clock counter

.iter:
	addx.l	d1,d1			; pOEP-only
	addx.l	d1,d1			; pOEP-only
	addx.l	d1,d1			; pOEP-only
	addx.l	d1,d1			; pOEP-only

	add.l	d1,d1			; pOEP|sOEP
	subq.l	#1,d0			; pOEP|sOEP
	bne.s	.iter			; is predicted and folded, takes 0 cycles

	sub.l	$40400000,a0		; sample cpu clock counter
	bclr.b	#1,$bfe001		; reset logic analyzer

	moveq.l	#0,d0
	sub.l	a0,d0

	rts

