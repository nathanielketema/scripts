//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const assert = std.debug.assert;

const stdx = @import("include/stdx.zig");
const Shell = stdx.Shell;

const Error = error{ InvalidArguments, InvalidCommand };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    const shell: Shell = .init(io, arena);

    const input: Input = Input.parse(argv) catch {
        std.debug.print("{s}\n", .{help});
        return;
    };
    switch (input.command) {
        .setup => @panic("TODO"),
        .brew => try brew(shell),
        .stow => @panic("TODO"),
        .help => std.debug.print("{s}\n", .{help}),
    }
}

pub fn brew(shell: Shell) !void {
    try shell.run("brew update", .{});
    try shell.run("brew bundle install --global", .{});
    try shell.run("brew upgrade", .{});
    try shell.run("brew bundle cleanup --global --force --zap", .{});
    try shell.run("brew cleanup --prune=all", .{});
}

const Input = struct {
    command: Command,

    const Command = enum {
        setup,
        brew,
        stow,
        help,

        pub fn from_string(command: []const u8) ?Command {
            return std.meta.stringToEnum(Command, command);
        }
    };

    pub fn parse(input: []const [:0]const u8) !Input {
        if (input.len != 2) return Error.InvalidArguments;
        const command = Command.from_string(input[1]) orelse return Error.InvalidCommand;

        return .{
            .command = command,
        };
    }
};

const help =
    \\Usage: config <command>
    \\
    \\Available commands:
    \\    setup - setup full system
    \\    brew  - keeps all packages and casks up to date with the Brewfile
    \\    stow  - runs stow for each top level directory inside ~/.dotfiles
    \\    help  - show help docs
;
