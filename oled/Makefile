VASM_FLAGS	:= -quiet -m68020 -Fhunkexe -nosym -showcrit

TARGET		:= oled.exe
SOURCE		:= oled.s
INCLUDES	:= kprintf.i font8x8_basic.i replay_208x77.bin
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
