const std = @import("std");
const expect = std.testing.expect;

pub const CHIP8 = struct {
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
    //
    var randomizer: std.rand.Xoshiro256 = std.rand.DefaultPrng.init(0);

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

    pub fn load_file(self: *CHIP8, fname: []const u8) !void {
        const file = try std.fs.cwd().openFile(fname, .{});
        defer file.close();
        var buf: [4096 - 0x200]u8 = undefined;
        _ = try file.readAll(&buf);
        for (buf, 0..) |byte, i| {
            self.memory[i + 0x200] = byte;
        }
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
            0x8 => {
                switch (inst.n) {
                    0x0 => {
                        self.V[inst.x] = self.V[inst.y];
                    },
                    0x1 => {
                        self.V[inst.x] |= self.V[inst.y];
                    },
                    0x2 => {
                        self.V[inst.x] &= self.V[inst.y];
                    },
                    0x3 => {
                        self.V[inst.x] ^= self.V[inst.y];
                    },
                    0x4 => {
                        const sum = @addWithOverflow(self.V[inst.x], self.V[inst.y]);
                        self.V[inst.x] = sum[0];
                        // Overflow Check
                        if (sum[1] == 1) {
                            self.V[0xF] = 1;
                        }
                    },
                    0x5 => {
                        const diff = @subWithOverflow(self.V[inst.x], self.V[inst.y]);
                        self.V[inst.x] = diff[0];
                        // Overflow Check
                        if (diff[1] == 0) {
                            self.V[0xF] = 1;
                        }
                    },
                    0x7 => {
                        const diff = @subWithOverflow(self.V[inst.y], self.V[inst.x]);
                        self.V[inst.x] = diff[0];
                        // Overflow Check
                        if (diff[1] == 0) {
                            self.V[0xF] = 1;
                        }
                    },
                    0x6 => {
                        self.V[inst.x] = self.V[inst.y];
                        self.V[inst.x] >>= 1;
                        self.V[0xF] = self.V[inst.y] & 0x1;
                    },
                    0xE => {
                        self.V[inst.x] = self.V[inst.y];
                        self.V[inst.x] <<= 1;
                        self.V[0xF] = (self.V[inst.y] >> 7) & 0x1;
                    },
                    else => {
                        // Do Nothing
                    },
                }
            },
            0x9 => {
                if (self.V[inst.x] != self.V[inst.y]) {
                    self.pc += 2;
                }
            },
            0xA => {
                self.ir = inst.nnn;
            },
            0xB => {
                self.pc = inst.nnn + self.V[0];
            },
            0xC => {
                const rand = randomizer.random().intRangeAtMost(u8, 0, 0xFF);
                self.V[inst.x] = rand & inst.nn;
            },
            0xD => {
                var x = self.V[inst.x] & 63;
                var y = self.V[inst.y] & 31;
                self.V[0xF] = 0;
                for (0..inst.n) |i| {
                    const sprite = self.memory[self.ir + i];
                    for (0..8) |j| {
                        if (x + j > 63) {
                            break;
                        }
                        if (y + i > 31) {
                            break;
                        }
                        const pixel = (sprite >> @intCast(7 - j)) & 0x1;
                        if (pixel == 1) {
                            if (self.display[y + i][x + j]) {
                                self.V[0xF] = 1;
                            } else {
                                self.display[y + i][x + j] = true;
                            }
                        }
                        x += 1;
                    }
                    y += 1;
                }
            },
            0xE => {
                switch (inst.nn) {
                    0x9E => {
                        if (self.keypad[self.V[inst.x]]) {
                            self.pc += 2;
                        }
                    },
                    0xA1 => {
                        if (!self.keypad[self.V[inst.x]]) {
                            self.pc += 2;
                        }
                    },
                    else => {
                        // Do Nothing
                    },
                }
            },
            0xF => {
                switch (inst.nn) {
                    0x07 => {
                        self.V[inst.x] = self.delay_timer;
                    },
                    0x15 => {
                        self.delay_timer = self.V[inst.x];
                    },
                    0x18 => {
                        self.sound_timer = self.V[inst.x];
                    },
                    0x1E => {
                        self.ir += self.V[inst.x];
                    },
                    0x0A => {
                        var pressed = false;
                        for (self.keypad, 0..) |key, i| {
                            if (key) {
                                self.V[inst.x] = @intCast(i);
                                pressed = true;
                            }
                        }
                        if (!pressed) {
                            self.pc -= 2;
                        }
                    },
                    0x29 => {
                        self.ir = fontoffset + (self.V[inst.x] * 5);
                    },
                    0x33 => {
                        self.memory[self.ir] = self.V[inst.x] / 100;
                        self.memory[self.ir + 1] = (self.V[inst.x] / 10) % 10;
                        self.memory[self.ir + 2] = self.V[inst.x] % 10;
                    },
                    0x55 => {
                        for (0..inst.x + 1) |i| {
                            self.memory[self.ir + i] = self.V[i];
                        }
                    },
                    0x65 => {
                        for (0..inst.x + 1) |i| {
                            self.V[i] = self.memory[self.ir + i];
                        }
                    },
                    else => {
                        // Do Nothing
                    },
                }
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
