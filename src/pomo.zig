//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Shell = @import("./stdx.zig").Shell;

const usage =
    \\Usage: pomo [start | break] [total_minutes]
    \\
    \\Defaults:
    \\    start: 60 mins
    \\    break: 10 mins
;

const Option = enum {
    start,
    @"break",

    pub fn from_str(str: []const u8) ?Option {
        return std.meta.stringToEnum(Option, str);
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const shell: Shell = .init(io, arena);
    const argv = try init.minimal.args.toSlice(arena);

    if (argv.len < 2 or argv.len > 3) {
        std.log.err("{t}\n{s}", .{ error.InvalidArg, usage });
        return error.InvalidArg;
    }

    const option = Option.from_str(argv[1]) orelse {
        std.log.err("{}\n{s}", .{ error.InvalidOption, usage });
        return error.InvalidOption;
    };

    var total: i64 = switch (option) {
        .start => 60,
        .@"break" => 10,
    };

    if (argv.len == 3) {
        total = try std.fmt.parseInt(i64, argv[2], 10);

        if (total <= 0) {
            std.log.err("Duration must be positive", .{});
            return error.InvalidDuration;
        }
    }

    const interval: i64 = switch (option) {
        .start => 5,
        .@"break" => 1,
    };

    std.debug.print("Timer started for {} minutes...\n", .{total});
    {
        var elapsed: i64 = 0;
        while (elapsed < total) {
            const remaining = total - elapsed;
            const sleep_minutes = @min(interval, remaining);

            try io.sleep(.fromSeconds(sleep_minutes * 60), .real);
            elapsed += sleep_minutes;

            std.log.info(
                "[{}/{}] minutes elapsed ({}min remaining)",
                .{ elapsed, total, total - elapsed },
            );
        }
    }
    std.debug.print("Pomodoro finished!\n", .{});
    _ = try shell.run("say 'Congrats!! Pomodoro finished!'", .{});
}
