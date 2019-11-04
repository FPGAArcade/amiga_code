VASM_FLAGS	:= -quiet -Fhunkexe -align -nosym

TARGET		:= battclock.resource
SOURCE		:= battclock.s
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
