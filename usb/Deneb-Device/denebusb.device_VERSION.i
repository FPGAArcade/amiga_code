VERSION		EQU	1
REVISION	EQU	0
DATE	MACRO
		dc.b	'16.9.2018'
	ENDM
VERS	MACRO
		dc.b	'replayusb 1.0'
	ENDM
VSTRING	MACRO
		dc.b	'replayusb 1.0 (16.9.2018) Based on denebusb.device © 2007-2010 by Chris Hodges',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: replayusb 1.0 (16.9.2018) Based on denebusb.device © 2007-2010 by Chris Hodges',0
	ENDM
