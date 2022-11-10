AS		= $(VASM)
CC		= $(VC)
LD		= $(VLINK)

ASFLAGS		:= -quiet -Fhunk -kick1hunks -nosym -m68000 -no-opt
CFLAGS		:= -v -O2 -size -cpu=68060 -c99 -k -sc -DDEBUG
LDFLAGS		:= -sc -Bstatic -Cvbcc -nostdlib -Rshort -b amigahunk -s

TARGET		:= timer
OBJECTS		:= main.o timer.o
INCLUDE 	:= $(wildcard *.h) $(wildcard *.s)

CRT0		=  $(VBCC)/targets/m68k-amigaos/lib/startup.o  
LDLIBS		= -L$(VBCC)/targets/m68k-amigaos/lib -lvc

.EXPORT_ALL_VARIABLES:

.PHONY: clean

all: $(TARGET)

clean:
	rm -f $(TARGET) $(OBJECTS) $(OBJECTS:.o=.asm) *.txt

$(TARGET) : $(OBJECTS) Makefile | buildenv
	$(LD) $(LDFLAGS) $(CRT0) $(OBJECTS) $(LDLIBS) -o $@ -M$@.txt 

%.o: %.c $(INCLUDE) Makefile | buildenv
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s Makefile | buildenv
	$(AS) $< -o $@ -L $<.txt $(ASFLAGS) -I $(INC_ASM)

include ../Makefile.build
