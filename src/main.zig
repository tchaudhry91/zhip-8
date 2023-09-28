const std = @import("std");
const chip = @import("chip");

pub fn main() !void {
    const chipper = try chip.init();
    _ = chipper;
}
