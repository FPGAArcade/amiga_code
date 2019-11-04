ifeq (, $(shell which romtool))
$(error "amitools/romtool not found; see https://github.com/cnvogelg/amitools")
endif

SUBDIRS	:= $(dir $(wildcard */Makefile))

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS) replay.rom
	@echo "** $@ done"

clean: $(addprefix clean-,$(SUBDIRS))
	rm -rf replay.rom
	@echo "** $@ done"

$(SUBDIRS):
	$(MAKE) -C $@

clean-%: %
	$(MAKE) -C $< clean

replay.rom: build_rom.sh
	./build_rom.sh

include Makefile.build
