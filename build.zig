const std = @import("std");
const Io = std.Io;

pub fn build(b: *std.Build) !void {
    const cwd = try Io.Dir.openDir(.cwd(), b.graph.io, ".", .{ .iterate = true });
    var it = cwd.iterate();
    while (try it.next(b.graph.io)) |entry| {
        const file_basename = entry.name;
        const file_extension = Io.Dir.path.extension(file_basename);
        if (entry.kind == .file and
            std.mem.eql(u8, file_extension, ".zig") and
            !std.mem.eql(u8, file_basename, "build.zig"))
        {
            const file_stem = Io.Dir.path.stem(file_basename);

            const exe = b.addExecutable(.{
                .name = file_stem,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(file_basename),
                    .target = b.graph.host,
                    .optimize = .ReleaseSmall,
                }),
            });
            b.installArtifact(exe);
        }
    }
}
