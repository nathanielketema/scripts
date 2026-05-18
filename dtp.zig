//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);

    if (argv.len == 1) {
        usage();
        std.process.exit(1);
    }

    const files = try collect(arena, init.io, argv[1..]);
    if (files.len == 0) {
        std.debug.print("Error: No supported document files found.\n", .{});
        std.process.exit(1);
    }

    defer quitPages(init.io) catch {};

    for (files) |file| {
        try convert(arena, init.io, file);
    }

    std.debug.print("Done! Processed {d} file(s).\n", .{files.len});
}

fn usage() void {
    std.debug.print(
        \\Usage: dtp [directory | file1.docx file2.pages ...]
        \\
        \\Examples:
        \\  dtp .             # Convert all docs in current folder
        \\  dtp report.docx   # Convert specific file
        \\  dtp *.docx        # Convert all docx using wildcard
        \\
    , .{});
}

fn collect(arena: Allocator, io: Io, args: []const [:0]const u8) ![]const []const u8 {
    const first = args[0];
    if (std.mem.eql(u8, first, ".") or isDir(io, first)) {
        return collectDir(arena, io, first);
    }

    var files: std.ArrayList([]const u8) = .empty;
    for (args) |arg| {
        if (isDoc(arg)) {
            try files.append(arena, try std.fs.path.resolve(arena, &.{arg}));
        } else {
            std.debug.print("Skipping {s} (not a supported document format)\n", .{arg});
        }
    }
    return files.items;
}

fn collectDir(arena: Allocator, io: Io, path: []const u8) ![]const []const u8 {
    const abs = try std.fs.path.resolve(arena, &.{path});
    const dir = try Io.Dir.openDir(.cwd(), io, abs, .{ .iterate = true });

    var files: std.ArrayList([]const u8) = .empty;
    var entries = dir.iterate();
    while (try entries.next(io)) |entry| {
        if (!isDoc(entry.name)) continue;
        try files.append(arena, try std.fs.path.join(arena, &.{ abs, entry.name }));
    }
    return files.items;
}

fn isDir(io: Io, path: []const u8) bool {
    _ = Io.Dir.openDir(.cwd(), io, path, .{ .iterate = true }) catch return false;
    return true;
}

fn isDoc(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    inline for (.{ ".doc", ".docx", ".pages" }) |want| {
        if (std.ascii.eqlIgnoreCase(ext, want)) return true;
    }
    return false;
}

fn pdfPath(arena: Allocator, input: []const u8) ![]const u8 {
    const pdf = try std.mem.concat(arena, u8, &.{ std.fs.path.stem(input), ".pdf" });
    const dir = std.fs.path.dirname(input) orelse return pdf;
    return std.fs.path.join(arena, &.{ dir, pdf });
}

fn convert(arena: Allocator, io: Io, input: []const u8) !void {
    const output = try pdfPath(arena, input);

    std.debug.print("Converting: {s} -> {s}\n", .{ input, std.fs.path.basename(output) });
    try run(io, &.{ "osascript", "-e", convert_script, input, output });
}

fn quitPages(io: Io) !void {
    try run(io, &.{ "osascript", "-e", quit_script });
}

fn run(io: Io, argv: []const []const u8) !void {
    var child = try std.process.spawn(io, .{ .argv = argv });
    const term = try child.wait(io);
    if (term.exited != 0) return error.CommandFailed;
}

const convert_script =
    \\on run argv
    \\    set input_path to item 1 of argv
    \\    set output_path to item 2 of argv
    \\    tell application "Pages"
    \\        activate
    \\        set the_document to open POSIX file input_path
    \\        delay 0.5
    \\        export the_document to file (POSIX file output_path) as PDF
    \\        close the_document saving no
    \\    end tell
    \\end run
;

const quit_script =
    \\if application "Pages" is running then
    \\    tell application "Pages" to quit
    \\end if
;

test isDoc {
    try std.testing.expect(isDoc("a.doc"));
    try std.testing.expect(isDoc("a.DOCX"));
    try std.testing.expect(isDoc("a.pages"));
    try std.testing.expect(!isDoc("a.pdf"));
}

test pdfPath {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    const got = try pdfPath(arena.allocator(), "/tmp/report.docx");
    try std.testing.expectEqualSlices(u8, "/tmp/report.pdf", got);
}
