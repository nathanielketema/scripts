const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const process = std.process;

const Shell = @import("include/stdx.zig").Shell;

// Won't work for file names with spaces!
pub fn main(init: std.process.Init) !void {
    const shell: Shell = .init(init.io, init.arena.allocator());
    const ctx: Context = .init(init, shell);

    var cmd_it = init.minimal.args.iterate();
    _ = cmd_it.skip();
    const cmdline_arg = cmd_it.next();

    const selected_path = blk: {
        if (cmdline_arg) |cmdline| {
            break :blk std.mem.trim(u8, cmdline, "\n\r");
        }
        const selected_path_raw = ctx.select_directory();

        var it = std.mem.tokenizeScalar(u8, selected_path_raw, '\n');
        const query = it.next() orelse return;

        if (it.next()) |selected| {
            break :blk std.mem.trim(u8, selected, "\n\r");
        } else {
            break :blk try ctx.create_new_directory_and_return_selected(query);
        }
    };

    const session_name = try std.mem.replaceOwned(
        u8,
        init.arena.allocator(),
        Io.Dir.path.basename(selected_path),
        ".",
        "_",
    );

    const tmux_running = try shell.run("pgrep tmux", .{});
    if (tmux_running.term.exited != 0) {
        std.debug.print("{s}\n", .{tmux_running.stderr});
    }

    if (init.environ_map.get("TMUX") == null or tmux_running.stdout.len == 0) {
        const result = try shell.run(
            "tmux new-session -s {s} -c {s}",
            .{ session_name, selected_path },
        );

        if (result.term.exited != 0) {
            std.debug.print("{s}\n", .{result.stderr});
        }
        return;
    }

    const session_check = try shell.run("tmux has-session -t={s}", .{session_name});
    if (session_check.term.exited != 0) {
        const result = try shell.run(
            "tmux new-session -ds {s} -c {s}",
            .{ session_name, selected_path },
        );
        if (result.term.exited != 0) {
            std.debug.print("{s}\n", .{result.stderr});
        }
    }

    const result = try shell.run("tmux switch-client -t {s}", .{session_name});
    if (result.term.exited != 0) {
        std.debug.print("{s}\n", .{result.stderr});
    }
}

pub const Context = struct {
    io: Io,
    arena: Allocator,
    shell: Shell,
    home_path: []const u8,

    pub fn init(juicy: std.process.Init, shell: Shell) Context {
        return .{
            .io = juicy.io,
            .arena = juicy.arena.allocator(),
            .shell = shell,
            .home_path = juicy.environ_map.get("HOME").?,
        };
    }

    pub fn home(ctx: Context, path: []const u8) []const u8 {
        return Io.Dir.path.join(ctx.arena, &.{ ctx.home_path, path }) catch process.exit(1);
    }

    pub fn select_directory(ctx: Context) []const u8 {
        return ctx.shell.pipeline(&.{
            "find",
            ctx.home("/"),
            ctx.home("personal/"),
            ctx.home("school/"),
            ctx.home("work/"),
            ctx.home("misc/"),
            ctx.home("personal/notes/"),
            ctx.home("git-clone/"),
            "-mindepth",
            "1",
            "-maxdepth",
            "1",
            "-type",
            "d",
        }).pipe(&.{ "fzf", "--print-query" }).text();
    }

    pub fn select_destination(ctx: Context) []const u8 {
        const dirs_search = std.mem.join(ctx.arena, "\n", &.{
            "personal",
            "school",
            "misc",
            "work",
            "git-clone",
        }) catch std.process.exit(1);
        return ctx.shell.pipeline(&.{
            "echo",
            dirs_search,
        }).pipe(&.{ "fzf", "--prompt=Select destination: " }).text();
    }

    pub fn create_new_directory_and_return_selected(ctx: Context, query: []const u8) ![]const u8 {
        const path_destination = std.mem.trim(u8, ctx.select_destination(), "\n\r");
        const query_trimmed = std.mem.trim(u8, query, "\n\r");

        if (std.mem.startsWith(u8, query_trimmed, "https://github.com/") or
            std.mem.startsWith(u8, query_trimmed, "git@github.com:") or
            std.mem.startsWith(u8, query_trimmed, "https://codeberg.org/") or
            std.mem.startsWith(u8, query_trimmed, "ssh://git@codeberg.org/"))
        {
            const repo_name = Io.Dir.path.stem(query_trimmed);

            const path_target = try Io.Dir.path.join(ctx.arena, &.{
                ctx.home(path_destination),
                repo_name,
            });

            _ = try ctx.shell.run("git clone {s} {s}", .{ query_trimmed, path_target });
            return path_target;
        }

        const path_new = try Io.Dir.path.join(ctx.arena, &.{
            ctx.home(path_destination),
            query_trimmed,
        });

        try Io.Dir.createDirPath(.cwd(), ctx.io, path_new);
        return path_new;
    }
};
