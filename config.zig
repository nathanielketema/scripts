//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const assert = std.debug.assert;

const stdx = @import("include/stdx.zig");
const Shell = stdx.Shell;

const Io = std.Io;

const Error = error{ InvalidArguments, InvalidCommand };

const usage =
    \\Usage: config <command>
    \\
    \\Available commands:
    \\    init - init full system
    \\    brew - keep all packages and casks up to date using Brewfile
    \\    stow - symlink $DOTFILES
    \\    help - show help docs
;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    const shell: Shell = .init(io, arena);

    const input: Input = Input.parse(argv) catch {
        std.debug.print("{s}\n", .{usage});
        return;
    };
    switch (input.command) {
        .init => @panic("TODO"),
        .brew => try brew(shell),
        .stow => try stow(shell, init.environ_map),
        .help => std.debug.print("{s}\n", .{usage}),
    }
}

pub fn brew(shell: Shell) !void {
    try shell.spawn("brew update", .{});
    try shell.spawn("brew bundle install --global", .{});
    try shell.spawn("brew upgrade", .{});
    try shell.spawn("brew bundle cleanup --global --force --zap", .{});
    try shell.spawn("brew cleanup --prune=all", .{});
}

pub fn stow(shell: Shell, env: *std.process.Environ.Map) !void {
    const result = try std.process.run(
        shell.arena,
        shell.io,
        .{ .argv = &.{ "stow", "--version" } },
    );
    if(result.term.exited != 0) return error.StowNotInstalled;

    const dot_files_path = env.get("DOTFILES") orelse return error.Env_DOTFILES_NotFound;
    const dir = try Io.Dir.openDir(.cwd(), shell.io, dot_files_path, .{ .iterate = true });
    try Io.Threaded.chdir(dot_files_path);

    var dot_files = dir.iterate();
    while (try dot_files.next(shell.io)) |entry| {
        assert(entry.name.len > 0);
        if (std.mem.eql(u8, entry.name, ".git")) continue;
        try shell.spawn("stow {s}", .{entry.name});
    }
}

const Input = struct {
    command: Command,

    const Command = enum {
        init,
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

