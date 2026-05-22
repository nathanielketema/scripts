//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const assert = std.debug.assert;

const stdx = @import("include/stdx.zig");
const Shell = stdx.Shell;
const Io = std.Io;

const Allocator = std.mem.Allocator;

const usage =
    \\Usage: pomo [start | break] [total_minutes]
    \\
    \\Defaults:
    \\    start: 60 mins
    \\    break: 10 mins
;

pub fn main(init: std.process.Init) !void {
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    const argc = argv.len;
    if (argc < 2 or argc > 3) {
        std.log.err("{}\n{s}", .{ error.InvalidArg, usage });
        return;
    }
    const option = Option.from_str(argv[1]) orelse {
        std.log.err("{}\n{s}", .{ error.InvalidOption, usage });
        return;
    };
    const shell: Shell = .init(init.io, init.arena.allocator());

    var total: i64 = switch (option) {
        .start => 60,
        .@"break" => 10,
    };
    if (argc == 3) {
        total = try std.fmt.parseInt(i64, argv[2], 10);
    }
    std.log.info("Timer started for {} minutes...", .{total});

    const interval: i64 = switch (option) {
        .start => 5,
        .@"break" => 1,
    };
    var elapsed: i64 = 0;
    while (elapsed < total) {
        try init.io.sleep(.fromSeconds(interval * 60), .real);
        elapsed += interval;
        std.log.info(
            "[{}/{}] minutes elapsed ({}min remaining)",
            .{ elapsed, total, total - elapsed },
        );
    }
    std.log.info("Pomodoro finished!", .{});
    _ = try shell.run("say 'Congrats!! Pomodoro finished!'", .{});
}

const Option = enum {
    start,
    @"break",

    pub fn from_str(str: []const u8) ?Option {
        return std.meta.stringToEnum(Option, str);
    }
};
