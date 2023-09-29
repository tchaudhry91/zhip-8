const std = @import("std");
const chip = @import("./chip8.zig");
const display = @import("./display.zig");

pub fn main() !void {
    var emu = chip.CHIP8.init();
    try emu.load_file("roms/pic.ch8");
    var d = try display.TermDisplay.init();
    while (true) {
        try emu.emulate();
        d.render(emu.display);
    }
}
