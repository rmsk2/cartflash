RM=rm
PORT=/dev/ttyUSB0
SUDO=
FORCE=-f
PYTHON=python3
LOADER=fcartld.bin
LOADERTMP=fcartld_t.bin
ZIPFILE=fcart_flash.zip

ifdef WIN
RM=del
PORT=COM3
SUDO=
FORCE=
PYTHON=python
endif

BINARY=fcart

all: $(BINARY).pgz


.PHONY: dist
dist: $(LOADER) $(BINARY).pgz
	zip $(ZIPFILE) $(LOADER) bulk.csv


.PHONY: clean
clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(BINARY).pgz
	$(RM) $(FORCE) $(LOADER)
	$(RM) $(FORCE) $(LOADERTMP)
	$(RM) $(FORCE) $(ZIPFILE)


.PHONY: upload
upload: $(BINARY).pgz
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --run-pgz $(BINARY).pgz


$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm


$(BINARY).pgz: $(BINARY)
	$(PYTHON) make_pgz.py $(BINARY)


# Build fcart and store it in flash
.PHONY: flash
flash: $(LOADER)
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --flash-bulk bulk.csv


$(LOADER): $(LOADERTMP) $(BINARY) 
	$(PYTHON) pad_binary.py $(LOADERTMP) $(BINARY) $(LOADER)


$(LOADERTMP): flashloader.asm
	64tass --nostart -o $(LOADERTMP) flashloader.asm
