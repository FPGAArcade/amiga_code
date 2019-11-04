VASM_FLAGS	:= -quiet -nowarn=1012 -cnop=0x0000 -m68020 -Fhunkexe -kick1hunks -nosym -no-opt

TARGET		:= Replay.card
SOURCE		:= replay.card.asm
INCLUDES	:= P96BoardInfo.i P96CardStruct.i P96ModeInfo.i vde.i
LISTFILE	:= $(addsuffix .txt,$(basename $(TARGET)))

all: $(TARGET)
	@echo ""

$(TARGET): Makefile | buildenv
$(TARGET): $(INCLUDES)
$(TARGET): $(SOURCE)
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -I $(INC_ASM)

clean:
	rm -rf $(TARGET) $(LISTFILE)

.PHONY: clean

include ../Makefile.build
