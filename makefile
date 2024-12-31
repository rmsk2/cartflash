RM=rm
PORT=/dev/ttyUSB0
SUDO=
FORCE=-f
PYTHON=python3

ifdef WIN
RM=del
PORT=COM3
SUDO=
FORCE=
PYTHON=python
endif

BINARY=fcart

all: $(BINARY).pgz

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(BINARY).pgz


.PHONY: upload
upload: $(BINARY).pgz
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --run-pgz $(BINARY).pgz


$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm

$(BINARY).pgz: $(BINARY)
	$(PYTHON) make_pgz.py $(BINARY)

