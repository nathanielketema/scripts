//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const assert = std.debug.assert;
const log = std.log;
const mem = std.mem;
const testing = std.testing;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Shell = @import("include/stdx.zig").Shell;

const usage =
    \\ctp (Change To PDF)
    \\
    \\Usage: ctp.zig file_name ...
    \\
    \\Supported file extensions:
    \\    - ".doc"
    \\    - ".docx"
    \\    - ".pptx"
    \\    - ".pages"
    \\    - ".md"
    \\
    \\Convert to pdf with ease :)
;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const shell: Shell = .init(init.io, arena);

    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) {
        log.err("{}\n{s}", .{ error.InvalidArg, usage });
        return;
    }

    for (argv[1..]) |arg| {
        const tmp = mem.cutLast(u8, arg, ".") orelse {
            log.err("{}\n{s}", .{ error.InvalidFile, usage });
            return;
        };
        const file_name = tmp.@"0";
        const file_extension = FileExtension.from_str(tmp.@"1") orelse {
            log.err("{}\n{s}", .{ error.InvalidFileExtension, usage });
            return;
        };

        const current_path = try std.process.currentPathAlloc(init.io, arena);
        const absolute_input_path = try mem.concat(arena, u8, &.{
            current_path,
            "/",
            arg,
        });
        const absolute_output_path = try mem.concat(arena, u8, &.{
            current_path,
            "/",
            file_name,
            ".pdf",
        });

        const output_file = try mem.concat(arena, u8, &.{ file_name, ".pdf" });
        log.info("Converting: {s} -> {s}", .{ arg, output_file });

        switch (file_extension) {
            .doc, .docx, .pages => {
                const script = try std.fmt.allocPrint(arena,
                    \\tell application "Pages"
                    \\    activate
                    \\    set the_document to open POSIX file "{s}"
                    \\    delay 0.5
                    \\    export the_document to file (POSIX file "{s}") as PDF
                    \\    quit saving no
                    \\end tell
                , .{ absolute_input_path, absolute_output_path });

                const result = try shell.run_raw(&.{
                    "osascript",
                    "-e",
                    script,
                });
                if (result.term.exited != 0) fatal(arg, "{s}", .{result.stderr});
            },
            .pptx => {
                const script = try std.fmt.allocPrint(arena,
                    \\tell application "Keynote"
                    \\    activate
                    \\    set the_document to open POSIX file "{s}"
                    \\    delay 0.5
                    \\    export the_document to file (POSIX file "{s}") as PDF
                    \\    quit saving no
                    \\end tell
                , .{ absolute_input_path, absolute_output_path });

                const result = try shell.run_raw(&.{
                    "osascript",
                    "-e",
                    script,
                });
                if (result.term.exited != 0) fatal(arg, "{s}", .{result.stderr});
            },
            .md => {
                const result = try shell.run("pandoc {s} --output {s} --pdf-engine={s}", .{
                    absolute_input_path,
                    absolute_output_path,
                    @tagName(Engine.xelatex),
                });
                if (result.term.exited != 0) fatal(arg, "{s}", .{result.stderr});
            },
        }

        log.info("{s} converted successfully :)", .{arg});
    }
}

fn fatal(arg: []const u8, comptime fmt: []const u8, args: anytype) noreturn {
    log.err("unable to convert {s} :(", .{arg});
    std.debug.print(fmt, args);
    std.process.exit(1);
}

const FileExtension = enum {
    docx,
    doc,
    pages,
    pptx,
    md,

    fn from_str(str: []const u8) ?FileExtension {
        return std.meta.stringToEnum(FileExtension, str);
    }
};

pub const Engine = enum { pdflatex, xelatex };
