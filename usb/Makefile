VASM_FLAGS	:= -quiet -Fhunkexe -kick1hunks

TARGET		:= usb_eth.autoconfig
SOURCE		:= addconfig.s
LISTFILE	:= $(addsuffix .txt,$(basename $(TARGET)))

all: $(TARGET)
	@echo ""

$(TARGET): Makefile | buildenv
$(TARGET): $(SOURCE)
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -I $(INC_ASM)

clean:
	rm -rf $(TARGET) $(LISTFILE)

.PHONY: clean

include ../Makefile.build
