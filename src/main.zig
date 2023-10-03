const std = @import("std");
const chip = @import("./chip8.zig");
const display = @import("./display.zig");

pub fn main() !void {
    var emu = chip.CHIP8.init();
    try emu.load_file("roms/maze.ch8");
    var d = try display.TermDisplay.init();
    while (true) {
        const key = d.render(emu.display);
        emu.set_key(key);
        try emu.emulate();
        //std.time.sleep(1420000);
    }
}
