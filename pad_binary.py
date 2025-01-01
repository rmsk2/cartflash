import sys

BLOCK_LEN = 8192

with open(sys.argv[1], "rb") as f:
    data_loader = f.read()

with open(sys.argv[2], "rb") as f:
    data_dcopy = f.read()

data_raw = data_loader + data_dcopy

pad_bytes = BLOCK_LEN - len(data_raw)

if pad_bytes < 0:
    print("Binary is too large. We need another 8K block. Adapt this program, the loader, the makefile and bulk.csv")
    sys.exit(42)

print(f"Bytes to pad in 8K block: {pad_bytes}")

end_pad = bytearray(BLOCK_LEN)
data = data_raw + end_pad[0:pad_bytes]

with open(sys.argv[3], "wb") as f:
    f.write(data)
    
    