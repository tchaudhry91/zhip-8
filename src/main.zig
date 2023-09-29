const std = @import("std");
const chip = @import("./chip8.zig");
const display = @import("./display.zig");

pub fn main() !void {
    const emu = chip.CHIP8.init();
    display.TermDisplay.render(emu.display);
}
