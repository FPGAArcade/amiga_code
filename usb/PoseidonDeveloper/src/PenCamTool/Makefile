#
# pencam gcc makefile
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

OBJS_PPC	= debug.oPPC pencam.vhi.oPPC
HEADERS		= debug.h pencam.h vhi.h myregargs.h declgate.h

##############################################################################
# standard targets

.PHONY:	all install clean

all: PencamTool.elf pencam.vhi.elf install

install:
	copy clone pencam.vhi.elf LIBS:VHI/
  copy clone PencamTool.elf C:

clean:
	$(RM) $(OBJS_68K) $(OBJS_PPC) PencamTool.oPPC

##############################################################################
# dependicies

##############################################################################

.SUFFIXES:
.SUFFIXES: .c .oPPC

%.oPPC:	%.c
	$(CC_PPC) $(LCFLAGS_PPC) -c $< -o $@

pencam.vhi.elf: $(OBJS_PPC)
	$(LD_PPC) $(LDFLAGS_PPC) $^ -o $@ $(LIBS_PPC)
	ppc-morphos-strip $@
	@#ppc-morphos-objdump --syms $@ | grep *UND*

PencamTool.elf: PencamTool.oPPC
	$(LD_PPC) $(LDFLAGS_PPC) $(LIB)/startup.o $^ -o $@ $(LIBS2_PPC)
	ppc-morphos-strip $@
	@#ppc-morphos-objdump --syms $@ | grep *UND*


