VERSION		EQU	1
REVISION	EQU	1
DATE	MACRO
		dc.b	'19.11.2018'
	ENDM
VERS	MACRO
		dc.b	'replayusb 1.1'
	ENDM
VSTRING	MACRO
		dc.b	'replayusb 1.1 (19.11.2018) Based on denebusb.device © 2007-2014 by Chris Hodges',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: replayusb 1.1 (19.11.2018) Based on denebusb.device © 2007-2014 by Chris Hodges',0
	ENDM
