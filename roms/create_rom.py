#!/usr/bin/env python

import binascii

# Create a ROM file from a binary file

def create_rom(instructions, rom):
    rom = open(rom, 'wb')
    for i in instructions:
        rom.write(i)
    rom.close()


def main(args):
    instructions = [
    ]
    print(args)
    # create_rom(instructions, args[0])

if __name__ == "__main__":
    import sys
    main(sys.argv)
