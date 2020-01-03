VASM_FLAGS	:= -quiet -Fhunkexe -kick1hunks

TARGET		:= usb_eth.autoconfig
SOURCE		:= addconfig.s
LISTFILE	:= $(addsuffix .txt,$(basename $(TARGET)))

all: $(TARGET) replayusb.device
	@echo ""

$(TARGET): Makefile | buildenv
$(TARGET): $(SOURCE)
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -I $(INC_ASM)

# export VBCC root env var
.EXPORT_ALL_VARIABLES:

DRIVER_FILES := $(wildcard Deneb-Device/*)

replayusb.device: Makefile $(DRIVER_FILES) | buildenv
	$(MAKE) -C Deneb-Device

clean:
	$(MAKE) -C Deneb-Device clean
	rm -rf $(TARGET) $(LISTFILE) replayusb.device

.PHONY: clean

include ../Makefile.build
