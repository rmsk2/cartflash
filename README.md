# cartflash

This program allows you to write a file which resides on any of your Foenix's drives to a flash extension cartridge.
As the flash cartridge has a size of 256 KB the maximum file size is accordingly 256 KB. The flash cart
organizes its memory in 8 KB blocks (strictly speaking in 4K blocks but the Foenix manages its memory in chunks of
8 = 2 * 4 KB blocks), which in turn means that there are 32 individually addressable blocks available on the cartridge
which are numbered from 0 to 31.

## Usage

Data read from the specified file is written to consecutive 8K blocks on the flash cart. When prompted for the file 
name you can prefix it by a drive number followed by a colon. I.e. for instance `1:file.bin` would try to read 
`file.bin` from drive 1. If no drive number is given it defaults to 0. You have to specify the number of the first 
flash block which is to be used. This value has to be in the range from 0 to 31. `cartflash` checks that all of the 
8K blocks of the file fit into the cartridge when the write operation begins on the given start block.

In contrast to `Red-Fool`'s program available [here](https://github.com/Red-Fool/F256_FlashCart ) `cartflash`
does as a default not erase the whole flash chip before writing new data to it. This allows you to add data to
your flash cartridge in an incremental fashion. The program by `Red-Fool` was very useful to me as it
made clear how the information in the [data sheet](https://ww1.microchip.com/downloads/en/DeviceDoc/20005023B.pdf) 
of the flash chip (SST39LF/VF020) was to be interpreted.

When using `cartflash` as `.pgz` type `/- fcart` or `/- drive number:fcart` (`drive number` = 1 or 2 when the `.pgz` 
file resides on an IEC drive) at the BASIC prompt in order to start the program via `pexec`. When running `cartflash` 
from onboard flash memory you can leave out the `-`, i.e. you simply call `/fcart`.

If you want to delete the whole flash cartridge before writing new data to it you can do that by adding the parameter 
`erasealldata` when starting `fcart`, i.e. you could call `fcart` for instance like this `/fcart erasealldata` or this
`/- fcart erasealldata`.

**WARNING**: When this parameter is detetced `fcart` asks for **no additional confirmation** before erasing all data.

## How to build the program

You will need a python3 interpreter, GNU make and 64tass on your machine to build this software.
Use `make` to build a `.pgz` executable. Alternatively you can use `make upload` to build, upload and start the program 
via the USB debug port.

If you want to write `cartflash` to the onboard flash memory of your Foenix then build the target `flash` via `make flash`. 
Make sure that the serial port designation in the makefile, which is needed for successfully executing  `make upload` or 
`make flash`, matches the hardware available on your system.

If you change the value `BUILD_ONBOARD_FLASH` to 0 in `flashloader.asm` then you can build (via `make dist`) a version 
which expects to be stored in block 31 on the flash cartridge. The resulting binary is stored as `fcartld.bin` in the 
project directory. This allows the cartridge to be self contained in such  a way that no additional software is needed 
to store data on it. If no other KUP headers are present in the cartridge upon boot or a reset then  `fcart` would be 
started automatically. If another KUP header is written in any other block this would take precendence for autostart 
and `fcart` would still be callable via DOS or BASIC. In order to be able to distinguish a version written to cartridge 
flash from another one living in onboard flash, the cartridge version is named `fccart`.

## Binary distribution

Prebuilt binaries are available at the [releases section](https://github.com/rmsk2/cartflash/releases) of this repository. 
Download either the `.pgz` or the `.zip` file from there. The `pgz` is the executable which can be started via `pexec`
after being transferred to your Foenix via an SD card, `dcopy`or `FoenixMgr`. The `.zip` file contains a flash image 
and a `bulk.csv` which can be used to write `fcart` to block $08 of the onboard flash memory via `FoenixMgr`.
