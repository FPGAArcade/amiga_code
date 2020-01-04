
SHELL   =   /bin/sh

##############################################################################

TARGET      =   PPC
CODETYPE    =   PPC
VERSION     =   1

##############################################################################

G_IPATH     =   -I/gg/os-include -I/gg/include -I/include
G_DEFINES   =   -D$(CODETYPE) -D__MORPHOS__
G_OPTFLAGS  =   -O2         \
			-fomit-frame-pointer    \
			-fverbose-asm       \
			-mno-prototype      \
			-mcpu=604       \
			-mregnames      \
			-Wformat        \
			-Wunused        \
			-Wuninitialized     \
			-Wconversion        \
			-Wstrict-prototypes \
			-Werror-implicit-function-declaration


APATH       =   -iinclude/
AFLAGS      =   -M4000

##############################################################################

all:    bootmouse.class.elf bootmouse.class.elf.rom

##############################################################################

.SUFFIXES: .o$(TARGET) .asm

.c.o$(TARGET):
	ppc-morphos-gcc $(G_CFLAGS) $(G_OPTFLAGS) $(G_DEBUG) $(G_DEFINES) $(G_IPATH) -S -o $*.s $*.c
	ppc-morphos-as -v -o$*.o$(TARGET) $*.s

.s.o$(TARGET):
	ppc-morphos-as -o$*.o$(TARGET) $*.s


.asm.o$(TARGET):
	basm $(AFLAGS) $(APATH) -o$*.o$(TARGET) $*.asm

##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################
#
# amiga Emulation
#

LIB     =   /gg/morphos/lib

SRC     =

GLOBAL      =   libdata.h

bootmouse.class.o$(TARGET):         $(SRC)bootmouse.class.c $(SRC)bootmouse.class_VERSION.h

OBJS        =   bootmouse.class.o$(TARGET)\

#####################################################################
#
# Link Project
#

#####################################################################
#
# Project keyboardppc.elf.library
#

bootmouse.class.elf:    $(OBJS)         \
		  $(LIB)/libmemblock.a    \
		  $(LIB)/libmath.a    \
		  $(LIB)/libsyscall.a
		ppc-morphos-ld -v -L$(LIB) $(OBJS) $(LIB)/libmemblock.a $(LIB)/libmath.a $(LIB)/libsyscall.a -o $@ -lm -lamigastubs
		ppc-morphos-strip bootmouse.class.elf

bootmouse.class.elf.rom:    $(OBJS)         \
		  $(LIB)/libmemblock.a    \
		  $(LIB)/libmath.a    \
		  $(LIB)/libsyscall.a
		ppc-morphos-ld -r -v -L$(LIB) $(OBJS) $(LIB)/libmemblock.a $(LIB)/libmath.a $(LIB)/libsyscall.a -o $@ -lm -lamigastubs

BUMP:
	bumprev2 VERSION=$(VERSION) FILE=$(SRC)bootmouse.class_VERSION TAG=bootmouse.class ADD="© 2002 by Chris Hodges"


DUMP:
	ppc-morphos-objdump --section-headers --all-headers --reloc --disassemble-all bootmouse.class.elf >bootmouse.class.elf.dump

##############################################################################
.PHONY: all

install: all 

/classes/usb/bootmouse.class.elf: bootmouse.class.elf
	cp bootmouse.class.elf /classes/usb/

clean:
	-rm *.o$(TARGET)

