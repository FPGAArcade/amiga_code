#
# dradio gcc makefile
#

DEB =
#DEB = -DDEBUG

LIB     =   /gg/morphos/lib

CC_PPC		= ppc-morphos-gcc -I/gg/os-include -I/gg/include -I/include -DPPC -D__MORPHOS__
LD_PPC		= ppc-morphos-ld
LCFLAGS_PPC	= $(DEB) -Wall -O3 -mcpu=603e -mmultiple -fomit-frame-pointer -noixemul -nostdlib
LDFLAGS_PPC	= -v -L$(LIB) -noixemul -nostdlib
LIBS_PPC	= -lsyscall -lstring -lmemblock
LDFLAGS_PPC	= -v -L$(LIB) -noixemul -nostdlib
LIBS2_PPC = -lc -lsyscall -lstringio -lstring -lmemblock


##############################################################################
# object files

OBJS_PPC	= debug.oPPC
HEADERS		= debug.h dradio.h vhi.h myregargs.h declgate.h

##############################################################################
# standard targets

.PHONY:	all install clean

all: DRadioTool.elf install

install:
  copy clone DRadioTool.elf C:

clean:
	$(RM) $(OBJS_68K) $(OBJS_PPC) DRadioTool.oPPC

##############################################################################
# dependicies

##############################################################################

.SUFFIXES:
.SUFFIXES: .c .oPPC

%.oPPC:	%.c
	$(CC_PPC) $(LCFLAGS_PPC) -c $< -o $@

DRadioTool.elf: DRadioTool.oPPC
	$(LD_PPC) $(LDFLAGS_PPC) $(LIB)/startup.o $^ -o $@ $(LIBS2_PPC)
	ppc-morphos-strip $@
	@#ppc-morphos-objdump --syms $@ | grep *UND*


