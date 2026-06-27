const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    const pdf_name = argv[1];

    _ = try std.process.run(arena, init.io, .{
        .argv = &.{
            "tmux",
            "new-window",
            try std.fmt.allocPrint(arena, "sioyek '{s}' --new-window", .{
                pdf_name,
            }),
        },
    });
    _ = try std.process.run(arena, init.io, .{ .argv = &.{ "tmux", "last-window" } });
}
