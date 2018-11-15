VERSION		EQU	1
REVISION	EQU	13
DATE	MACRO
		dc.b	'23.3.03'
	ENDM
VERS	MACRO
		dc.b	'bootmouse 1.13'
	ENDM
VSTRING	MACRO
		dc.b	'bootmouse 1.13 (23.3.03) © 2002 by Chris Hodges',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: bootmouse 1.13 (23.3.03) © 2002 by Chris Hodges',0
	ENDM
