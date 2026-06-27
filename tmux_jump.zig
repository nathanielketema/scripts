const std = @import("std");
const Shell = @import("include/stdx.zig").Shell;

pub fn main(init: std.process.Init) !void {
    const shell: Shell = .init(init.io, init.arena.allocator());

    const sessions = blk: {
        const result = try shell.run("tmux list-sessions -F #{{session_name}}", .{});
        break :blk std.mem.trim(u8, result.stdout, "\n\r");
    };

    if (sessions.len == 0) {
        std.debug.print("No tmux sessions available.\n", .{});
        return;
    }

    const session_name = blk: {
        const selected_session = shell.pipeline(&.{
            "echo",
            sessions,
        }).pipe(&.{
            "fzf",
            "--header=[Enter] switch [Ctrl+D] kill session",
            "--bind=ctrl-d:execute-silent(tmux kill-session -t {})+reload(tmux list-sessions -F '#{session_name}')",
        }).text();

        if (selected_session.len == 0) return;
        break :blk std.mem.trim(u8, selected_session, "\n\r");
    };


    const session_check = try shell.run(
        "tmux has-session -t={s}",
        .{session_name},
    );

    if (session_check.term.exited == 0) {
        _ = try shell.run("tmux switch-client -t={s}", .{session_name});
    }
}
