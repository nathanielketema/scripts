//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const Shell = @import("./stdx.zig").Shell;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const shell: Shell = .init(init.io, arena);

    const argv = try init.minimal.args.toSlice(arena);
    const pdf_name = argv[1];

    const window_new = try shell.run_raw(&.{
        "tmux",
        "new-window",
        try arena.print("sioyek '{s}' --new-window", .{pdf_name}),
    });
    if (window_new.term.exited != 0) fatal("{s}", .{window_new.stderr});

    const window_last = try shell.run("tmux last-window", .{});
    if (window_last.term.exited != 0) fatal("{s}", .{window_last.stderr});
}

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt, args);
    std.process.exit(1);
}
