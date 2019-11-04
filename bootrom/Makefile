VASM_FLAGS	:= -quiet -showcrit -pic -Fbin -m68000

TARGET		:= bootrom.bin
SOURCE		:= bootrom.s
INCLUDES	:= replay_200x77.bin
LISTFILE	:= $(addsuffix .txt,$(basename $(TARGET)))

all: $(TARGET)
	@echo ""

$(TARGET): Makefile | buildenv
$(TARGET): $(INCLUDES)
$(TARGET): $(SOURCE)
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS)

clean:
	rm -rf $(TARGET) $(LISTFILE)

.PHONY: clean

include ../Makefile.build
