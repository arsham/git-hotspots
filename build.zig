const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "git-hotspots",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const setup_fixtures = b.addSystemCommand(&.{ "sh", "tools/setup-fixtures.sh" });
    b.getInstallStep().dependOn(&setup_fixtures.step);

    b.installArtifact(exe);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const integration_tests = b.addSystemCommand(&.{ "sh", "tests/integration.sh" });
    integration_tests.addArtifactArg(exe);
    integration_tests.step.dependOn(&setup_fixtures.step);

    const test_step = b.step("test", "Run unit and integration tests");
    run_unit_tests.step.dependOn(&setup_fixtures.step);
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&integration_tests.step);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run git-hotspots");
    run_step.dependOn(&run_cmd.step);
}
