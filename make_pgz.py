import sys
import os

load_address = 0x0300
start_address = 0x0300

def make_24bit_address(addr):
    help, lo = divmod(addr, 256)
    higher, hi = divmod(help, 256)
    return (lo, hi, higher)

loadl, loadm, loadh = make_24bit_address(load_address)
lenl, lenm, lenh = make_24bit_address(os.path.getsize(sys.argv[1]))
startl, startm, starth = make_24bit_address(start_address)

pgz_header = bytes([90, loadl, loadm, loadh, lenl, lenm, lenh])
pgz_footer = bytes([startl, startm, starth, 0, 0, 0])

with open(sys.argv[1], "rb") as f:
    data = f.read()


with open(sys.argv[1]+".pgz", "wb") as f:
    f.write(pgz_header)
    f.write(data)
    f.write(pgz_footer)


