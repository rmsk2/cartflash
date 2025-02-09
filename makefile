RM=rm
CP=cp
PORT=/dev/ttyUSB0
SUDO=
FORCE=-f
PYTHON=python3
CARTBLOCK=cartridge.bin
FLASHBLOCK=fcartld.bin
FLASHLOADER=flashloader.bin
ZIPFILE=onboard.zip
DIST=dist/

FLASH_ONBOARD = 1
FLASH_CARTRIDGE = 0

ifdef WIN
DIST=\
RM=del
CP=copy
PORT=COM3
SUDO=
FORCE=
PYTHON=python
endif

BINARY=fcart

all: $(BINARY).pgz


.PHONY: dist
dist: clean $(FLASHBLOCK) $(CARTBLOCK) $(BINARY).pgz
	zip $(ZIPFILE) $(FLASHBLOCK) bulk.csv
	$(CP) $(ZIPFILE) $(DIST)
	$(CP) $(BINARY).pgz $(DIST)
	$(CP) $(CARTBLOCK) $(DIST)
	


.PHONY: clean
clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(BINARY).pgz
	$(RM) $(FORCE) $(FLASHBLOCK)
	$(RM) $(FORCE) $(CARTBLOCK)
	$(RM) $(FORCE) $(FLASHLOADER)
	$(RM) $(FORCE) $(ZIPFILE)
	$(RM) $(FORCE) $(DIST)$(ZIPFILE)
	$(RM) $(FORCE) $(DIST)$(BINARY).pgz
	$(RM) $(FORCE) $(DIST)$(CARTBLOCK)


.PHONY: upload
upload: $(BINARY).pgz
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --run-pgz $(BINARY).pgz


$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm


$(BINARY).pgz: $(BINARY)
	$(PYTHON) make_pgz.py $(BINARY)


# Build fcart and store it in flash
.PHONY: flash
flash: $(FLASHBLOCK)
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --flash-bulk bulk.csv


$(FLASHBLOCK): flashloader.asm $(BINARY) 
	64tass --nostart -D BUILD_ONBOARD_FLASH=$(FLASH_ONBOARD) -o $(FLASHLOADER) flashloader.asm
	$(PYTHON) pad_binary.py $(FLASHLOADER) $(BINARY) $(FLASHBLOCK)


$(CARTBLOCK): flashloader.asm $(BINARY) 
	64tass --nostart -D BUILD_ONBOARD_FLASH=$(FLASH_CARTRIDGE) -o $(FLASHLOADER) flashloader.asm
	$(PYTHON) pad_binary.py $(FLASHLOADER) $(BINARY) $(CARTBLOCK)