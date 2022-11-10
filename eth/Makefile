VASM_FLAGS	:= -quiet -nowarn=1012 -m68020 -Fhunkexe -kick1hunks -nosym -showcrit

TARGET		:= replayeth.device
SOURCE		:= replayeth.s
INCLUDES	:= kprintf.i enc624.i
LISTFILE	:= $(addsuffix .txt,$(basename $(TARGET)))

all: $(TARGET)
	@echo ""

$(TARGET): Makefile | buildenv
$(TARGET): $(INCLUDES)
$(TARGET): $(SOURCE)
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -I $(INC_ASM) -I $(SANA2)/include

reseteth: reseteth.s
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -I $(INC_ASM) -I $(SANA2)/include

clean:
	rm -rf $(TARGET) $(LISTFILE)

.PHONY: clean

include ../Makefile.build
