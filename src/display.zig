const std = @import("std");

const curses = @cImport({
    @cInclude("curses.h");
});

pub const TermDisplay = struct {
    maxlines: c_int = 32,
    maxcols: c_int = 64,

    pub fn init() !TermDisplay {
        var display = TermDisplay{};
        _ = curses.initscr();
        _ = curses.cbreak();
        _ = curses.noecho();
        _ = curses.clear();

        display.maxlines = curses.LINES - 1;
        display.maxcols = curses.COLS - 1;
        return display;
    }

    pub fn render(self: *TermDisplay, fb: [32][64]bool) u32 {
        _ = self;
        for (0..64) |x| {
            for (0..32) |y| {
                if (fb[y][x]) {
                    _ = curses.mvaddch(@intCast(y), @intCast(x), '*');
                } else {
                    _ = curses.mvaddch(@intCast(y), @intCast(x), ' ');
                }
            }
        }
        _ = curses.refresh();
        _ = curses.nodelay(curses.stdscr, true);
        const key = curses.getch();
        if (key == curses.ERR) {
            return 0;
        }
        return @intCast(key);
    }
};
