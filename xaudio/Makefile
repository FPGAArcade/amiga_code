VASM_FLAGS	:= -quiet -nowarn=1012 -m68020 -nosym -showcrit -no-opt

INCLUDES	:= src/kprintf.i

TARGET1		:= Devs/AHI/replay.audio
SOURCE1		:= src/replay_audio.s
LISTFILE1	:= AHIDriver.txt

TARGET2		:= Devs/AudioModes/replay
SOURCE2		:= src/replay.s
LISTFILE2	:= AudioMode.txt

TARGETS += $(TARGET1) $(TARGET2)

all: $(TARGETS)
	@echo ""

clean:
	rm -rf $(TARGETS) $(LISTFILE1) $(LISTFILE2)

.PHONY: clean

$(TARGETS): Makefile | buildenv
$(TARGETS): $(INCLUDES)

$(TARGET1): $(SOURCE1)
	$(VASM) $< -o $@ -L $(LISTFILE1) $(VASM_FLAGS) -Fhunkexe -kick1hunks -I $(INC_ASM) -I $(AHI)

$(TARGET2): $(SOURCE2)
	$(VASM) $< -o $@ -L $(LISTFILE2) $(VASM_FLAGS) -pic -Fbin -I $(INC_ASM) -I $(AHI)

include ../Makefile.build
