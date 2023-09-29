#!/usr/bin/env python

import binascii

# Create a ROM file from a binary file

def create_rom(instructions, rom):
    rom = open(rom, 'wb')
    for i in instructions:
        rom.write(binascii.unhexlify(i))
    rom.close()


def main(args):
    instructions = [
            "610A",
            "6214",
            "A214",
            "D005",
            "A219",
            "D106",
            "A214",
            "D205",
            "F00A",
            "0000",
            "FFC3",
            "FFC3",
            "C318",
            "18FF",
            "FF18",
            "18",
    ]
    create_rom(instructions, args[0])

if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
