#
# replayusb.device vbcc makefile
#

DEB = 
#DEB = -DDEBUG -k

CC		= vc
LD		= vc
LCFLAGS	= $(DEB) -O2 -speed -cpu=68020 -fastcall -cpp-comments -I../PoseidonDeveloper/includes -nostdlib
LDFLAGS	= $(LCFLAGS) -v -nostdlib -lvc

TARGET = 68K

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

#all: replaydmausb.device replayusb.device replayz2usb.device install
all: replayusb.device

clean:
	$(RM) $(OBJS_DMA) $(OBJS_PIO) $(OBJS_Z2) replaydmausb.device replayusb.device replayz2usb.device

##############################################################################
# dependicies

##############################################################################

.SUFFIXES:
.SUFFIXES: .c .o$(TARGET)

%.o$(TARGET):	%.c
	$(CC) $(LCFLAGS) -c $< -o $@

dev_dma.o$(TARGET):             $(SRC)dev.c                     $(GLOBAL) denebusb.device_VERSION.h debug.h
	$(CC) $(LCFLAGS) -c $< -o $@

uhwcmd_dma.o$(TARGET):          $(SRC)uhwcmd.c uhwcmd.h $(GLOBAL) debug.h
	$(CC) $(LCFLAGS) -c $< -o $@

dev_pio.o$(TARGET):             $(SRC)dev.c                     $(GLOBAL) denebusb.device_VERSION.h debug.h
	$(CC) -DNODMA $(LCFLAGS) -c $< -o $@

uhwcmd_pio.o$(TARGET):          $(SRC)uhwcmd.c uhwcmd.h $(GLOBAL) debug.h
	$(CC) -DNODMA $(LCFLAGS) -c $< -o $@

dev_z2.o$(TARGET):              $(SRC)dev.c                     $(GLOBAL) denebusb.device_VERSION.h debug.h
	$(CC) -DNODMA -DZORRO_II $(LCFLAGS) -c $< -o $@

uhwcmd_z2.o$(TARGET):           $(SRC)uhwcmd.c uhwcmd.h $(GLOBAL) debug.h
	$(CC) -DNODMA -DZORRO_II $(LCFLAGS) -c $< -o $@

replaydmausb.device:      $(OBJS_DMA)
	$(LD) $(LDFLAGS) $^ -o $@ $(LIBS)

replayusb.device:      $(OBJS_PIO)
	$(LD) $(LDFLAGS) $^ -o $@ $(LIBS)

replayz2usb.device:      $(OBJS_Z2)
	$(LD) $(LDFLAGS) $^ -o $@ $(LIBS)
