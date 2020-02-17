VASM_FLAGS	:= -quiet -Fhunkexe -kick1hunks -nosym -m68000

TARGET		:= AddReplayMem
SOURCE		:= addmem.asm
INCLUDES	:= kprintf.i
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
