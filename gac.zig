const std = @import("std");
const Shell = @import("include/stdx.zig").Shell;

pub fn main(init: std.process.Init) !void {
    const shell: Shell = .init(init.io, init.arena.allocator());

    _ = try shell.run("git add .", .{});
    _ = try shell.run("git commit -m .", .{});
}
