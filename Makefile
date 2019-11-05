ifeq (, $(shell which romtool))
$(error "amitools/romtool not found; see https://github.com/cnvogelg/amitools")
endif

SUBDIRS	:= $(dir $(wildcard */Makefile))

.PHONY: all clean

all: replay.rom
	@echo "** $@ done"

clean: $(addprefix clean-,$(SUBDIRS))
	rm -rf replay.rom
	@echo "** $@ done"

build-%: %
	$(MAKE) -C $<

clean-%: %
	$(MAKE) -C $< clean

replay.rom: $(addprefix build-,$(SUBDIRS))
	./build_rom.sh

include Makefile.build
