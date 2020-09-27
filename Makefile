PREFIX=/usr/local
INSTALL_DIR=$(PREFIX)/bin
MICRATE_SYSTEM=$(INSTALL_DIR)/micrate

OUT_DIR=$(CURDIR)/bin
MICRATE=$(OUT_DIR)/micrate
MICRATE_SOURCES=$(shell find src/ -type f -name '*.cr')

all: build

build: lib $(MICRATE)

lib:
	@shards install --production

$(MICRATE): $(MICRATE_SOURCES) | $(OUT_DIR)
	@echo "Building micrate in $@"
	@crystal build -o $@ src/micrate-bin.cr -p --no-debug

$(OUT_DIR) $(INSTALL_DIR):
	 @mkdir -p $@

run:
	$(MICRATE)

install: build | $(INSTALL_DIR)
	@rm -f $(MICRATE_SYSTEM)
	@cp $(MICRATE) $(MICRATE_SYSTEM)

link: build | $(INSTALL_DIR)
	@echo "Symlinking $(MICRATE) to $(MICRATE_SYSTEM)"
	@ln -s $(MICRATE) $(MICRATE_SYSTEM)

force_link: build | $(INSTALL_DIR)
	@echo "Symlinking $(MICRATE) to $(MICRATE_SYSTEM)"
	@ln -sf $(MICRATE) $(MICRATE_SYSTEM)

clean:
	rm -rf $(MICRATE)

distclean:
	rm -rf $(MICRATE) .crystal .shards libs lib
