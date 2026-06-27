const std = @import("std");
const Io = std.Io;

pub fn build(b: *std.Build) !void {
    const cwd = try Io.Dir.openDir(.cwd(), b.graph.io, ".", .{ .iterate = true });
    var it = cwd.iterate();
    while (try it.next(b.graph.io)) |entry| {
        const script = entry.name;
        if (entry.kind == .file and
            std.mem.endsWith(u8, script, ".zig") and
            !std.mem.eql(u8, script, "build.zig"))
        {
            const name = script[0 .. script.len - ".zig".len];

            const exe = b.addExecutable(.{
                .name = name,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(script),
                    .target = b.graph.host,
                    .optimize = .ReleaseSmall,
                }),
            });
            b.installArtifact(exe);
        }
    }
}
