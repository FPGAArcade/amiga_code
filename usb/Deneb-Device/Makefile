#
# highwayusb.device gcc makefile
#

DEB =
#DEB = -DDEBUG

LIB     =   /gg/morphos/lib

CC_PPC		= ppc-morphos-gcc -I/gg/os-include -I/gg/include -I/include -DPPC -D__MORPHOS__
LD_PPC		= ppc-morphos-ld
LCFLAGS_PPC	= $(DEB) -Wall -O3 -mcpu=603e -mmultiple -fomit-frame-pointer -noixemul -nostdlib
LDFLAGS_PPC	= -v -L$(LIB) -noixemul -nostdlib
LIBS_PPC	= -lsyscall

TARGET = PPC

##############################################################################
# object files

OBJS_DMA        =       dev_dma.o$(TARGET) \
                        debug.o$(TARGET) \
                        uhwcmd_dma.o$(TARGET)

OBJS_PIO        =       dev_pio.o$(TARGET) \
                        debug.o$(TARGET) \
                        uhwcmd_pio.o$(TARGET)

OBJS_Z2         =       dev_z2.o$(TARGET) \
                        debug.o$(TARGET) \
                        uhwcmd_z2.o$(TARGET)

GLOBAL	   = declgate.h myregargs.h isp1760.h deneb.h denebusb.h


##############################################################################
# standard targets

.PHONY:	all install clean

all: denebdmausb.device.elf denebpiousb.device.elf denebz2usb.device.elf install

install:
	copy clone denebdmausb.device.elf denebpiousb.device.elf denebz2usb.device.elf DEVS:USBHardware/

clean:
	$(RM) $(OBJS_DMA) $(OBJS_PIO) $(OBJS_Z2) denebdmausb.device.elf denebpiousb.device.elf denebz2usb.device.elf

##############################################################################
# dependicies

##############################################################################

.SUFFIXES:
.SUFFIXES: .c .oPPC

%.oPPC:	%.c
	$(CC_PPC) $(LCFLAGS_PPC) -c $< -o $@

dev_dma.o$(TARGET):             $(SRC)dev.c                     $(GLOBAL) denebusb.device_VERSION.h debug.h
	$(CC_PPC) $(LCFLAGS_PPC) -c $< -o $@

uhwcmd_dma.o$(TARGET):          $(SRC)uhwcmd.c uhwcmd.h $(GLOBAL) debug.h
	$(CC_PPC) $(LCFLAGS_PPC) -c $< -o $@

dev_pio.o$(TARGET):             $(SRC)dev.c                     $(GLOBAL) denebusb.device_VERSION.h debug.h
	$(CC_PPC) -DNODMA $(LCFLAGS_PPC) -c $< -o $@

uhwcmd_pio.o$(TARGET):          $(SRC)uhwcmd.c uhwcmd.h $(GLOBAL) debug.h
	$(CC_PPC) -DNODMA $(LCFLAGS_PPC) -c $< -o $@

dev_z2.o$(TARGET):              $(SRC)dev.c                     $(GLOBAL) denebusb.device_VERSION.h debug.h
	$(CC_PPC) -DNODMA -DZORRO_II $(LCFLAGS_PPC) -c $< -o $@

uhwcmd_z2.o$(TARGET):           $(SRC)uhwcmd.c uhwcmd.h $(GLOBAL) debug.h
	$(CC_PPC) -DNODMA -DZORRO_II $(LCFLAGS_PPC) -c $< -o $@

denebdmausb.device.elf:      $(OBJS_DMA)
	$(LD_PPC) $(LDFLAGS_PPC) $^ -o $@ $(LIBS_PPC)
	ppc-morphos-strip $@

denebpiousb.device.elf:      $(OBJS_PIO)
	$(LD_PPC) $(LDFLAGS_PPC) $^ -o $@ $(LIBS_PPC)
	ppc-morphos-strip $@

denebz2usb.device.elf:      $(OBJS_Z2)
	$(LD_PPC) $(LDFLAGS_PPC) $^ -o $@ $(LIBS_PPC)
	ppc-morphos-strip $@


