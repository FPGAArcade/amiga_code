VERSION		EQU	1
REVISION	EQU	2
DATE	MACRO
		dc.b	'03.01.2020'
	ENDM
VERS	MACRO
		dc.b	'replayusb 1.2'
	ENDM
VSTRING	MACRO
		dc.b	'replayusb 1.2 (03.01.2020) Based on denebusb.device © 2007-2014 by Chris Hodges',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: replayusb 1.2 (03.01.2020) Based on denebusb.device © 2007-2014 by Chris Hodges',0
	ENDM
