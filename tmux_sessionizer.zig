const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const process = std.process;

const Shell = @import("include/stdx.zig").Shell;

const Context = struct {
    io: Io,
    arena: Allocator,
    shell: Shell,
    env: *std.process.Environ.Map,
    home_path: []const u8,
};

// Won't work for file names with spaces!
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var args = init.minimal.args.iterate();
    _ = args.skip(); // Skip program

    const ctx: Context = .{
        .io = io,
        .arena = arena,
        .shell = .init(io, arena),
        .env = init.environ_map,
        .home_path = init.environ_map.get("HOME") orelse
            fatal("error: couldn't find home path\n", .{}),
    };

    const selected_path = try select_path(ctx, args.next());
    try sessionize(ctx, selected_path);
}

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt, args);
    std.process.exit(1);
}

fn select_path(ctx: Context, arg: ?[]const u8) ![]const u8 {
    // Path is provided as a command line argument.
    if (arg) |cmd| return std.mem.trim(u8, cmd, "\n\r");

    // Path is picked from the displayed option.
    const selected_path_raw = select_directory(ctx);
    var it = std.mem.tokenizeScalar(u8, selected_path_raw, '\n');
    const query = it.next().?;

    var selected_path: []const u8 = undefined;
    if (it.next()) |selected| {
        selected_path = std.mem.trim(u8, selected, "\n\r");
    } else { // Path has to be created.
        selected_path = try create_new_directory_and_return_selected(ctx, query);
    }
    return selected_path;
}

fn sessionize(ctx: Context, selected_path: []const u8) !void {
    const tmux_running = try ctx.shell.run("pgrep tmux", .{});
    if (tmux_running.term.exited != 0) fatal("{s}\n", .{tmux_running.stderr});

    const session_name = try std.mem.replaceOwned(
        u8,
        ctx.arena,
        Io.Dir.path.basename(selected_path),
        ".",
        "_",
    );

    if (ctx.env.get("TMUX") == null or tmux_running.stdout.len == 0) {
        const result = try ctx.shell.run(
            "tmux new-session -s {s} -c {s}",
            .{ session_name, selected_path },
        );
        if (result.term.exited != 0) fatal("{s}\n", .{result.stderr});
        return;
    }

    const session_check = try ctx.shell.run("tmux has-session -t={s}", .{session_name});
    if (session_check.term.exited != 0) {
        const result = try ctx.shell.run(
            "tmux new-session -ds {s} -c {s}",
            .{ session_name, selected_path },
        );
        if (result.term.exited != 0) fatal("{s}\n", .{result.stderr});
    }

    const client_switch = try ctx.shell.run("tmux switch-client -t {s}", .{session_name});
    if (client_switch.term.exited != 0) fatal("{s}\n", .{client_switch.stderr});
}

fn home(ctx: Context, path: []const u8) []const u8 {
    return Io.Dir.path.join(ctx.arena, &.{ ctx.home_path, path }) catch process.exit(1);
}

fn select_directory(ctx: Context) []const u8 {
    return ctx.shell.pipeline(&.{
        "find",
        home(ctx, "/"),
        home(ctx, "personal/"),
        home(ctx, "school/"),
        home(ctx, "school/dsu/4-fall-2026/"),
        home(ctx, "work/"),
        home(ctx, "misc/"),
        home(ctx, "personal/notes/"),
        home(ctx, "cloned/"),
        "-mindepth",
        "1",
        "-maxdepth",
        "1",
        "-type",
        "d",
    }).pipe(&.{ "fzf", "--print-query" }).text();
}

fn select_destination(ctx: Context) []const u8 {
    const dirs_search =
        \\personal
        \\school
        \\misc
        \\work
        \\cloned
        \\
    ;
    return ctx.shell.pipeline(&.{
        "echo",
        dirs_search,
    }).pipe(&.{ "fzf", "--prompt=Select destination: " }).text();
}

fn create_new_directory_and_return_selected(ctx: Context, query: []const u8) ![]const u8 {
    const path_destination = std.mem.trim(u8, select_destination(ctx), "\n\r");
    const query_trimmed = std.mem.trim(u8, query, "\n\r");

    if (std.mem.startsWith(u8, query_trimmed, "https://github.com/") or
        std.mem.startsWith(u8, query_trimmed, "git@github.com:") or
        std.mem.startsWith(u8, query_trimmed, "https://codeberg.org/") or
        std.mem.startsWith(u8, query_trimmed, "ssh://git@codeberg.org/"))
    {
        const repo_name = Io.Dir.path.stem(query_trimmed);

        const path_target = try Io.Dir.path.join(ctx.arena, &.{
            home(ctx, path_destination),
            repo_name,
        });

        _ = try ctx.shell.run("git clone {s} {s}", .{ query_trimmed, path_target });
        return path_target;
    }

    const path_new = try Io.Dir.path.join(ctx.arena, &.{
        home(ctx, path_destination),
        query_trimmed,
    });

    try Io.Dir.createDirPath(.cwd(), ctx.io, path_new);
    return path_new;
}
