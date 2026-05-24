const std = @import("std");

fn addTreeSitterZig(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-core/v0.26.9/lib/include"));
    module.addIncludePath(b.path("third_party/tree-sitter-zig/v1.1.2/src"));
    module.addCSourceFiles(.{
        .files = &.{
            "third_party/tree-sitter-core/v0.26.9/lib/src/lib.c",
            "third_party/tree-sitter-zig/v1.1.2/src/parser.c",
        },
        .flags = &.{},
    });
    module.link_libc = true;
}

fn addTreeSitterGo(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-core/v0.26.9/lib/include"));
    module.addIncludePath(b.path("third_party/tree-sitter-go/v0.25.0/src"));
    module.addCSourceFiles(.{
        .files = &.{
            "third_party/tree-sitter-core/v0.26.9/lib/src/lib.c",
            "third_party/tree-sitter-go/v0.25.0/src/parser.c",
        },
        .flags = &.{},
    });
    module.link_libc = true;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const validate_closeout = b.option(bool, "closeout", "Require explicit second real-repo smoke evidence") orelse false;
    const validate_smoke_repo = b.option([]const u8, "smoke-repo", "Local sibling repo for close-out smoke validation");
    const validate_smoke_label = b.option([]const u8, "smoke-label", "Privacy-safe label for the sibling smoke repo");
    const validate_smoke_skip_reason = b.option([]const u8, "smoke-skip-reason", "Privacy-safe reason for skipping sibling smoke validation");

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterZig(b, exe_module);
    const exe = b.addExecutable(.{
        .name = "git-hotspots",
        .root_module = exe_module,
    });
    const setup_fixtures = b.addSystemCommand(&.{ "sh", "tools/setup-fixtures.sh" });
    b.getInstallStep().dependOn(&setup_fixtures.step);

    b.installArtifact(exe);

    const unit_test_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterZig(b, unit_test_module);
    const unit_tests = b.addTest(.{
        .root_module = unit_test_module,
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

    const tree_sitter_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterZig(b, tree_sitter_build_proof_module);

    const tree_sitter_build_proof = b.addExecutable(.{
        .name = "tree-sitter-build-proof",
        .root_module = tree_sitter_build_proof_module,
    });

    const run_tree_sitter_build_proof = b.addRunArtifact(tree_sitter_build_proof);
    const tree_sitter_build_proof_step = b.step("tree-sitter-build-proof", "Compile vendored Tree-sitter sources and run a tiny non-product Zig parse smoke");
    tree_sitter_build_proof_step.dependOn(&run_tree_sitter_build_proof.step);

    const tree_sitter_symbol_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_symbol_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_symbol_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterZig(b, tree_sitter_symbol_proof_module);

    const tree_sitter_symbol_proof = b.addTest(.{
        .root_module = tree_sitter_symbol_proof_module,
    });

    const run_tree_sitter_symbol_proof = b.addRunArtifact(tree_sitter_symbol_proof);
    const tree_sitter_symbol_proof_step = b.step("tree-sitter-symbol-proof", "Run test-only Zig current-symbol extraction proof with vendored Tree-sitter sources");
    tree_sitter_symbol_proof_step.dependOn(&run_tree_sitter_symbol_proof.step);

    const tree_sitter_go_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_go_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterGo(b, tree_sitter_go_build_proof_module);

    const tree_sitter_go_build_proof = b.addExecutable(.{
        .name = "tree-sitter-go-build-proof",
        .root_module = tree_sitter_go_build_proof_module,
    });

    const run_tree_sitter_go_build_proof = b.addRunArtifact(tree_sitter_go_build_proof);
    const tree_sitter_go_build_proof_step = b.step("tree-sitter-go-build-proof", "Compile vendored Tree-sitter Go sources and run a tiny non-product Go parse smoke");
    tree_sitter_go_build_proof_step.dependOn(&run_tree_sitter_go_build_proof.step);

    const tree_sitter_go_symbol_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_go_symbol_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_go_symbol_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterGo(b, tree_sitter_go_symbol_proof_module);

    const tree_sitter_go_symbol_proof = b.addTest(.{
        .root_module = tree_sitter_go_symbol_proof_module,
    });

    const run_tree_sitter_go_symbol_proof = b.addRunArtifact(tree_sitter_go_symbol_proof);
    const tree_sitter_go_symbol_proof_step = b.step("tree-sitter-go-symbol-proof", "Run test-only Go current-symbol extraction proof with vendored Tree-sitter sources");
    tree_sitter_go_symbol_proof_step.dependOn(&run_tree_sitter_go_symbol_proof.step);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run git-hotspots");
    run_step.dependOn(&run_cmd.step);
}
