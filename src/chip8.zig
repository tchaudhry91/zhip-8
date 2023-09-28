const std = @import("std");
const expect = std.testing.expect;

const CHIP8 = struct {
    memory: [4096]u8 = [_]u8{0} ** 4096, // 4096 Bytes Memory
    pc: u16 = 0x200, // Program Counter
    ir: u16 = 0, // Index Register
    stack: [16]u16 = [_]u16{0} ** 16, // Stack
    stack_ptr: u8 = 0, // Stack Pointer
    display: [32][64]bool = [_][64]bool{[_]bool{false} ** 64} ** 32,
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
    keypad: [16]bool = [_]bool{false} ** 16,
    V: [16]u8 = [_]u8{0} ** 16, // Registers

    const fontset: [80]u8 = [_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };
    const fontoffset: u16 = 0x50;

    pub fn init() CHIP8 {
        var chip = CHIP8{};
        for (fontset, 0..) |font, i| {
            chip.memory[i + fontoffset] = font;
        }
        return chip;
    }

    pub fn push_pc(self: *CHIP8) !void {
        if (self.stack_ptr == 15) {
            return error.OutOfMemory;
        }
        self.stack[self.stack_ptr] = self.pc;
        self.stack_ptr += 1;
    }

    pub fn pop_pc(self: *CHIP8) void {
        if (self.stack_ptr == 0) {
            return;
        }
        self.stack_ptr -= 1;
        self.pc = self.stack[self.stack_ptr];
    }

    pub fn emulate(self: *CHIP8) !void {
        var inst_raw: u16 = self.memory[self.pc];
        inst_raw = (inst_raw << 8) | self.memory[self.pc + 1];

        const inst = parse_instruction(inst_raw);
        self.pc += 2;

        switch (inst.op) {
            0x0 => {
                switch (inst.nn) {
                    0xE0 => {
                        // Clear the display
                        self.display = [_][64]bool{[_]bool{false} ** 64} ** 32;
                    },
                    0xEE => {
                        // Return from subroutine
                        self.pop_pc();
                    },
                    else => {
                        // Do Nothing
                    },
                }
            },
            0x1 => {
                // Jump to address
                self.pc = inst.nnn;
            },
            0x2 => {
                try self.push_pc();
                self.pc = inst.nnn;
            },
            0x3 => {
                if (self.V[inst.x] == inst.nn) {
                    self.pc += 2;
                }
            },
            0x4 => {
                if (self.V[inst.x] != inst.nn) {
                    self.pc += 2;
                }
            },
            0x5 => {
                if (self.V[inst.x] == self.V[inst.y]) {
                    self.pc += 2;
                }
            },
            0x6 => {
                self.V[inst.x] = inst.nn;
            },
            0x7 => {
                self.V[inst.x] += inst.nn;
            },
            0x9 => {
                if (self.V[inst.x] != self.V[inst.y]) {
                    self.pc += 2;
                }
            },
            else => {
                // Do Nothing
            },
        }
    }
};

test "emulate clear" {
    var chip = CHIP8.init();
    chip.memory[0x200] = 0x00;
    chip.memory[0x201] = 0xE0;
    try chip.emulate();
    for (chip.display) |row| {
        for (row) |pixel| {
            try expect(pixel == false);
        }
    }
}

test "check stack" {
    var chip = CHIP8.init();
    chip.pc = 0x400;
    try chip.push_pc();
    try expect(chip.stack_ptr == 1);
    try expect(chip.stack[0] == 0x400);
    try expect(chip.pc == 0x400);

    chip.pc = 0x500;
    chip.pop_pc();
    try expect(chip.stack_ptr == 0);
    try expect(chip.pc == 0x400);
}

const Instruction = struct {
    raw: u16,
    op: u4,
    x: u4,
    y: u4,
    n: u4,
    nn: u8,
    nnn: u12,
};

fn parse_instruction(inst: u16) Instruction {
    return Instruction{
        .raw = inst,
        .op = @truncate(inst >> 12),
        .x = @truncate((inst >> 8) & 0xF),
        .y = @truncate((inst >> 4) & 0xF),
        .n = @truncate(inst & 0xF),
        .nn = @truncate(inst & 0xFF),
        .nnn = @truncate(inst & 0xFFF),
    };
}

test "parse_instruction" {
    const inst = parse_instruction(0x1234);

    try expect(inst.raw == 0x1234);
    try expect(inst.op == 0x1);
    try expect(inst.x == 0x2);
    try expect(inst.y == 0x3);
    try expect(inst.n == 0x4);
    try expect(inst.nn == 0x34);
    try expect(inst.nnn == 0x234);
}
