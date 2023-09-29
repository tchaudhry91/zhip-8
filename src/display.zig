const std = @import("std");
pub const TermDisplay = struct {
    pub fn render(fb: [32][64]bool) void {
        for (0..32) |y| {
            for (0..64) |x| {
                if (fb[y][x]) {
                    std.debug.print("{s}", .{"█"});
                } else {
                    std.debug.print("{s}", .{" "});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};
