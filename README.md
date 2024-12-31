# cartflash

## Usage
This program allows you to write a file which resides on any of your Foenix's drives to the flash cartridge.
As the flash cartridge has a size of 256 KB the maximum file size is accordingly 256 KB. The flash cart
organizes its memory in 8 KB blocks. Which in turn means that there are 32 blocks available on the cart.

This program allows you to write the data read from the specified file to consecutive 8K blocks on the
flash cart. When prompted for the file name you can prefix it by a drive number followed by a colon. I.e.
for instance `1:file.bin` would try to read `file.bin` from drive 1. If no drive number is given it
defaults to 0. You have to specify the number of the first flash block which is to be used. This value 
has to be in the range from 0 to 31. `cartflash` checks that all of the blocks of the file fit into the 
cartridge when the write operation begins on the given start block.

In contrast to to the program available [here](https://github.com/Red-Fool/F256_FlashCart ) `cartflash`
does not erase the whole flash chip before writing new data to it. This allows you to write data to
your flash cartridge in an incremental fashion. The program by `Red-Fool` was very useful to me as it
made clear how the information in the [data sheet](https://ww1.microchip.com/downloads/en/DeviceDoc/20005023B.pdf) 
of the flash chip (SST39LF/VF020) was to be interpreted.

## How to build the program

You will need a python3 interpreter, GNU make and 64tass on your machine to build this software.
Use `make` to build a `.pgz` executable and transfer it to your machine via an SD-card or `dcopy`.
Alternatively you can use `make upload` to upload and start the program via the USB debug port.
