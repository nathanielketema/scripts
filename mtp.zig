//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const assert = std.debug.assert;

const stdx = @import("include/stdx.zig");
const Shell = stdx.Shell;

const Allocator = std.mem.Allocator;

pub fn main(init: std.process.Init) !void {
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    const pandoc: Pandoc = try .init(init.arena.allocator(), argv);

    const shell: Shell = .init(init.io, init.arena.allocator());
    try shell.run("pandoc '{s}' '{s}' --pdf-engine='{s}'", .{
        pandoc.input,
        pandoc.output,
        @tagName(pandoc.engine),
    });
}

pub const Pandoc = struct {
    input: []const u8,
    output: []const u8,
    engine: Engine,

    pub const Engine = enum { pdflatex, xelatex };

    pub fn init(arena: Allocator, argv: []const [:0]const u8) !Pandoc {
        if (argv.len != 2) return error.InvalidArgument;
        const input = argv[1];
        if (!std.mem.endsWith(u8, input, ".md")) return error.InvalidFile;
        const intermediate = std.mem.trimEnd(u8, input, ".md");
        const output = try std.mem.concat(arena, u8, &.{ intermediate, ".pdf" });

        return .{
            .input = input,
            .output = output,
            .engine = Engine.xelatex,
        };
    }
};

test Pandoc {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();

    const text = &.{ "mtp.zig", "foo_bar.md" };
    const pandoc: Pandoc = try .init(arena.allocator(), text);

    try testing.expectEqualSlices(u8, "foo_bar.md", pandoc.input);
    try testing.expectEqualSlices(u8, "foo_bar.pdf", pandoc.output);
}
