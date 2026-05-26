const std = @import("std");

fn addTreeSitterCore(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-core/v0.26.9/lib/include"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-core/v0.26.9/lib/src/lib.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterZigGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-zig/v1.1.2/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-zig/v1.1.2/src/parser.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterGoGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-go/v0.25.0/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-go/v0.25.0/src/parser.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterPythonGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-python/v0.25.0/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-python/v0.25.0/src/parser.c"), .flags = &.{} });
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-python/v0.25.0/src/scanner.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterJavaScriptGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-javascript/v0.25.0/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-javascript/v0.25.0/src/parser.c"), .flags = &.{} });
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-javascript/v0.25.0/src/scanner.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterLuaGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-lua/v0.5.0/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-lua/v0.5.0/src/parser.c"), .flags = &.{} });
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-lua/v0.5.0/src/scanner.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterTypeScriptGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-typescript/v0.23.2/typescript/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c"), .flags = &.{} });
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-typescript/v0.23.2/typescript/src/scanner.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterTsxGrammar(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-typescript/v0.23.2/tsx/src"));
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c"), .flags = &.{} });
    module.addCSourceFile(.{ .file = b.path("third_party/tree-sitter-typescript/v0.23.2/tsx/src/scanner.c"), .flags = &.{} });
    module.link_libc = true;
}

fn addTreeSitterPythonHeaders(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("third_party/tree-sitter-core/v0.26.9/lib/include"));
    module.addIncludePath(b.path("third_party/tree-sitter-python/v0.25.0/src"));
    module.link_libc = true;
}

fn addTreeSitterZig(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterZigGrammar(b, module);
}

fn addTreeSitterGo(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterGoGrammar(b, module);
}

fn addTreeSitterPython(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterPythonGrammar(b, module);
}

fn addTreeSitterJavaScript(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterJavaScriptGrammar(b, module);
}

fn addTreeSitterLua(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterLuaGrammar(b, module);
}

fn addTreeSitterTypeScript(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterTypeScriptGrammar(b, module);
}

fn addTreeSitterTsx(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterTsxGrammar(b, module);
}

fn addTreeSitterProviders(b: *std.Build, module: *std.Build.Module) void {
    addTreeSitterCore(b, module);
    addTreeSitterZigGrammar(b, module);
    addTreeSitterGoGrammar(b, module);
    addTreeSitterPythonGrammar(b, module);
    addTreeSitterJavaScriptGrammar(b, module);
    addTreeSitterTypeScriptGrammar(b, module);
    addTreeSitterTsxGrammar(b, module);
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
    addTreeSitterProviders(b, exe_module);
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
    addTreeSitterProviders(b, unit_test_module);
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

    const tree_sitter_python_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_python_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterPython(b, tree_sitter_python_build_proof_module);

    const tree_sitter_python_build_proof = b.addExecutable(.{
        .name = "tree-sitter-python-build-proof",
        .root_module = tree_sitter_python_build_proof_module,
    });

    const run_tree_sitter_python_build_proof = b.addRunArtifact(tree_sitter_python_build_proof);
    const tree_sitter_python_build_proof_step = b.step("tree-sitter-python-build-proof", "Compile vendored Tree-sitter Python sources and run a tiny non-product Python parse smoke");
    tree_sitter_python_build_proof_step.dependOn(&run_tree_sitter_python_build_proof.step);

    const tree_sitter_javascript_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_javascript_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterJavaScript(b, tree_sitter_javascript_build_proof_module);

    const tree_sitter_javascript_build_proof = b.addExecutable(.{
        .name = "tree-sitter-javascript-build-proof",
        .root_module = tree_sitter_javascript_build_proof_module,
    });

    const run_tree_sitter_javascript_build_proof = b.addRunArtifact(tree_sitter_javascript_build_proof);
    const tree_sitter_javascript_build_proof_step = b.step("tree-sitter-javascript-build-proof", "Compile vendored Tree-sitter JavaScript sources and run tiny non-product JavaScript and JSX parse smokes");
    tree_sitter_javascript_build_proof_step.dependOn(&run_tree_sitter_javascript_build_proof.step);

    const tree_sitter_lua_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_lua_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterLua(b, tree_sitter_lua_build_proof_module);

    const tree_sitter_lua_build_proof = b.addExecutable(.{
        .name = "tree-sitter-lua-build-proof",
        .root_module = tree_sitter_lua_build_proof_module,
    });

    const run_tree_sitter_lua_build_proof = b.addRunArtifact(tree_sitter_lua_build_proof);
    const tree_sitter_lua_build_proof_step = b.step("tree-sitter-lua-build-proof", "Compile vendored Tree-sitter Lua parser/scanner sources and run tiny non-product Lua parse smokes");
    tree_sitter_lua_build_proof_step.dependOn(&run_tree_sitter_lua_build_proof.step);

    const tree_sitter_typescript_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_typescript_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterTypeScript(b, tree_sitter_typescript_build_proof_module);

    const tree_sitter_typescript_build_proof = b.addExecutable(.{
        .name = "tree-sitter-typescript-build-proof",
        .root_module = tree_sitter_typescript_build_proof_module,
    });

    const run_tree_sitter_typescript_build_proof = b.addRunArtifact(tree_sitter_typescript_build_proof);
    const tree_sitter_typescript_build_proof_step = b.step("tree-sitter-typescript-build-proof", "Compile vendored Tree-sitter TypeScript parser/scanner sources and run a tiny non-product TypeScript parse smoke");
    tree_sitter_typescript_build_proof_step.dependOn(&run_tree_sitter_typescript_build_proof.step);

    const tree_sitter_tsx_build_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_tsx_build_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterTsx(b, tree_sitter_tsx_build_proof_module);

    const tree_sitter_tsx_build_proof = b.addExecutable(.{
        .name = "tree-sitter-tsx-build-proof",
        .root_module = tree_sitter_tsx_build_proof_module,
    });

    const run_tree_sitter_tsx_build_proof = b.addRunArtifact(tree_sitter_tsx_build_proof);
    const tree_sitter_tsx_build_proof_step = b.step("tree-sitter-tsx-build-proof", "Compile vendored Tree-sitter TSX parser/scanner sources and run a tiny non-product TSX parse smoke");
    tree_sitter_tsx_build_proof_step.dependOn(&run_tree_sitter_tsx_build_proof.step);

    const tree_sitter_typescript_query_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_typescript_query_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_typescript_query_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterTypeScript(b, tree_sitter_typescript_query_proof_module);

    const tree_sitter_typescript_query_proof = b.addTest(.{
        .root_module = tree_sitter_typescript_query_proof_module,
    });

    const run_tree_sitter_typescript_query_proof = b.addRunArtifact(tree_sitter_typescript_query_proof);
    const tree_sitter_typescript_query_proof_step = b.step("tree-sitter-typescript-query-proof", "Run test-only TypeScript symbol query contract proof with vendored Tree-sitter sources");
    tree_sitter_typescript_query_proof_step.dependOn(&run_tree_sitter_typescript_query_proof.step);

    const tree_sitter_tsx_query_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_tsx_query_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_tsx_query_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterTsx(b, tree_sitter_tsx_query_proof_module);

    const tree_sitter_tsx_query_proof = b.addTest(.{
        .root_module = tree_sitter_tsx_query_proof_module,
    });

    const run_tree_sitter_tsx_query_proof = b.addRunArtifact(tree_sitter_tsx_query_proof);
    const tree_sitter_tsx_query_proof_step = b.step("tree-sitter-tsx-query-proof", "Run test-only TSX symbol query contract proof with vendored Tree-sitter sources");
    tree_sitter_tsx_query_proof_step.dependOn(&run_tree_sitter_tsx_query_proof.step);

    const tree_sitter_typescript_symbol_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_typescript_symbol_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_typescript_symbol_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterTypeScript(b, tree_sitter_typescript_symbol_proof_module);

    const tree_sitter_typescript_symbol_proof = b.addTest(.{
        .root_module = tree_sitter_typescript_symbol_proof_module,
    });

    const run_tree_sitter_typescript_symbol_proof = b.addRunArtifact(tree_sitter_typescript_symbol_proof);
    const tree_sitter_typescript_symbol_proof_step = b.step("tree-sitter-typescript-symbol-proof", "Run internal TypeScript current-symbol extraction proof with vendored Tree-sitter sources");
    tree_sitter_typescript_symbol_proof_step.dependOn(&run_tree_sitter_typescript_symbol_proof.step);

    const tree_sitter_tsx_symbol_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_tsx_symbol_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_tsx_symbol_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterTsx(b, tree_sitter_tsx_symbol_proof_module);

    const tree_sitter_tsx_symbol_proof = b.addTest(.{
        .root_module = tree_sitter_tsx_symbol_proof_module,
    });

    const run_tree_sitter_tsx_symbol_proof = b.addRunArtifact(tree_sitter_tsx_symbol_proof);
    const tree_sitter_tsx_symbol_proof_step = b.step("tree-sitter-tsx-symbol-proof", "Run internal TSX current-symbol extraction proof with vendored Tree-sitter sources");
    tree_sitter_tsx_symbol_proof_step.dependOn(&run_tree_sitter_tsx_symbol_proof.step);

    const tree_sitter_javascript_query_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_javascript_query_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_javascript_query_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterJavaScript(b, tree_sitter_javascript_query_proof_module);

    const tree_sitter_javascript_query_proof = b.addTest(.{
        .root_module = tree_sitter_javascript_query_proof_module,
    });

    const run_tree_sitter_javascript_query_proof = b.addRunArtifact(tree_sitter_javascript_query_proof);
    const tree_sitter_javascript_query_proof_step = b.step("tree-sitter-javascript-query-proof", "Run test-only JavaScript symbol query contract proof with vendored Tree-sitter sources");
    tree_sitter_javascript_query_proof_step.dependOn(&run_tree_sitter_javascript_query_proof.step);

    const tree_sitter_javascript_symbol_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_javascript_symbol_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tree_sitter_javascript_provider_module = b.createModule(.{
        .root_source_file = b.path("src/tree_sitter_javascript.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_javascript_provider_module.addIncludePath(b.path("third_party/tree-sitter-core/v0.26.9/lib/include"));
    tree_sitter_javascript_provider_module.addIncludePath(b.path("third_party/tree-sitter-javascript/v0.25.0/src"));
    tree_sitter_javascript_provider_module.link_libc = true;
    tree_sitter_javascript_symbol_proof_module.addImport("tree_sitter_javascript", tree_sitter_javascript_provider_module);
    addTreeSitterJavaScript(b, tree_sitter_javascript_symbol_proof_module);

    const tree_sitter_javascript_symbol_proof = b.addTest(.{
        .root_module = tree_sitter_javascript_symbol_proof_module,
    });

    const run_tree_sitter_javascript_symbol_proof = b.addRunArtifact(tree_sitter_javascript_symbol_proof);
    const tree_sitter_javascript_symbol_proof_step = b.step("tree-sitter-javascript-symbol-proof", "Run internal JavaScript current-symbol extraction proof with vendored Tree-sitter sources");
    tree_sitter_javascript_symbol_proof_step.dependOn(&run_tree_sitter_javascript_symbol_proof.step);

    const tree_sitter_python_query_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_python_query_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_python_query_proof_module.addImport("provider", b.createModule(.{
        .root_source_file = b.path("src/provider.zig"),
        .target = target,
        .optimize = optimize,
    }));
    addTreeSitterPython(b, tree_sitter_python_query_proof_module);

    const tree_sitter_python_query_proof = b.addTest(.{
        .root_module = tree_sitter_python_query_proof_module,
    });

    const run_tree_sitter_python_query_proof = b.addRunArtifact(tree_sitter_python_query_proof);
    const tree_sitter_python_query_proof_step = b.step("tree-sitter-python-query-proof", "Run test-only Python symbol query contract proof with vendored Tree-sitter sources");
    tree_sitter_python_query_proof_step.dependOn(&run_tree_sitter_python_query_proof.step);

    const tree_sitter_python_symbol_proof_module = b.createModule(.{
        .root_source_file = b.path("tests/tree_sitter_python_symbol_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tree_sitter_python_provider_module = b.createModule(.{
        .root_source_file = b.path("src/tree_sitter_python.zig"),
        .target = target,
        .optimize = optimize,
    });
    addTreeSitterPythonHeaders(b, tree_sitter_python_provider_module);
    tree_sitter_python_symbol_proof_module.addImport("tree_sitter_python", tree_sitter_python_provider_module);
    addTreeSitterPython(b, tree_sitter_python_symbol_proof_module);

    const tree_sitter_python_symbol_proof = b.addTest(.{
        .root_module = tree_sitter_python_symbol_proof_module,
    });

    const run_tree_sitter_python_symbol_proof = b.addRunArtifact(tree_sitter_python_symbol_proof);
    const tree_sitter_python_symbol_proof_step = b.step("tree-sitter-python-symbol-proof", "Run internal Python current-symbol extraction proof with vendored Tree-sitter sources");
    tree_sitter_python_symbol_proof_step.dependOn(&run_tree_sitter_python_symbol_proof.step);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run git-hotspots");
    run_step.dependOn(&run_cmd.step);
}
