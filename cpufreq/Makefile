AS		= $(VASM)
CC		= $(VC)
LD		= $(VLINK)

ASFLAGS		:= -quiet -Fhunk -kick1hunks -nosym -m68000 -no-opt
CFLAGS_CLI	:= -v -O2 -size -cpu=68060                     -c99 -k -sc #-DDEBUG
CFLAGS		:= -v -O2 -size -cpu=68060 -fastcall -nostdlib -c99 -k -sc #-DDEBUG
LDFLAGS		:= -sc -Bstatic -Cvbcc -nostdlib -Rshort -b amigahunk -s

TARGET		:= cpufreq.exe cpufreq.cli
OBJECTS_CLI	:= cpufreq.o
OBJECTS		:= start.o main.o kprintf.o payload.o
INCLUDE 	:= $(wildcard *.h) $(wildcard *.s)

CRT0		=  $(VBCC)/targets/m68k-amigaos/lib/startup.o  
LDLIBS		= -L$(VBCC)/targets/m68k-amigaos/lib -lvc

.EXPORT_ALL_VARIABLES:

.PHONY: clean

all: $(TARGET)

clean:
	rm -f $(TARGET) $(OBJECTS_CLI) $(OBJECTS_CLI:.o=.asm) $(OBJECTS) $(OBJECTS:.o=.asm) *.txt

cpufreq.exe : $(OBJECTS) Makefile | buildenv
	$(LD) -sc $(OBJECTS) -o $@ -M$@.txt -b amigahunk

cpufreq.cli : cpufreq.o Makefile | buildenv
	$(LD) $(LDFLAGS) $(CRT0) cpufreq.o $(LDLIBS) -o $@ -M$@.txt 

%.o: %.c $(INCLUDE) Makefile | buildenv
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s Makefile | buildenv
	$(AS) $< -o $@ -L $<.txt $(ASFLAGS) -I $(INC_ASM)

payload.o: cpufreq.cli	# payload embeds the cpufreq command
cpufreq.o: CFLAGS=$(CFLAGS_CLI)

include ../Makefile.build
