const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const validate_closeout = b.option(bool, "closeout", "Require explicit second real-repo smoke evidence") orelse false;
    const validate_smoke_repo = b.option([]const u8, "smoke-repo", "Local sibling repo for close-out smoke validation");
    const validate_smoke_label = b.option([]const u8, "smoke-label", "Privacy-safe label for the sibling smoke repo");
    const validate_smoke_skip_reason = b.option([]const u8, "smoke-skip-reason", "Privacy-safe reason for skipping sibling smoke validation");

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

    const validate = b.addSystemCommand(&.{ "sh", "tools/validate.sh" });
    validate.addArtifactArg(exe);
    if (validate_closeout) validate.addArg("--closeout");
    if (validate_smoke_repo) |repo| {
        validate.addArg("--smoke-repo");
        validate.addArg(repo);
    }
    if (validate_smoke_label) |label| {
        validate.addArg("--smoke-label");
        validate.addArg(label);
    }
    if (validate_smoke_skip_reason) |reason| {
        validate.addArg("--smoke-skip-reason");
        validate.addArg(reason);
    }
    validate.step.dependOn(&setup_fixtures.step);

    const validate_step = b.step("validate", "Run full local validation workflow");
    validate_step.dependOn(&validate.step);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run git-hotspots");
    run_step.dependOn(&run_cmd.step);
}
