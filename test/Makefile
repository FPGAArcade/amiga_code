VC_FLAGS	:= -v

TARGET		:= test
SOURCE		:= test.c
INCLUDES	:= 
LISTFILE	:= $(addsuffix .txt,$(basename $(TARGET)))

all: $(TARGET)
	@echo ""

$(TARGET): Makefile | buildenv
$(TARGET): $(INCLUDES)
$(TARGET): $(SOURCE)
	$(VC) $< -o $@ $(VC_FLAGS)

clean:
	rm -rf $(TARGET) $(LISTFILE)

.PHONY: clean

# export VBCC root env var
.EXPORT_ALL_VARIABLES:

include ../Makefile.build
