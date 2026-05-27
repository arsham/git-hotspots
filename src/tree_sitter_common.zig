const std = @import("std");
const provider = @import("provider.zig");

pub const default_max_file_bytes: u64 = 1024 * 1024;

pub const Extraction = struct {
    provider: provider.ProviderEvidence,
    symbols: []provider.CurrentSymbolEvidence,

    pub fn deinit(self: *Extraction, allocator: std.mem.Allocator) void {
        allocator.free(self.provider.input.identity);
        freeSymbols(allocator, self.symbols);
        self.* = undefined;
    }
};

pub fn makeExtraction(
    allocator: std.mem.Allocator,
    provider_name: []const u8,
    provider_version: []const u8,
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
    symbols: []provider.CurrentSymbolEvidence,
) !Extraction {
    return makeExtractionWithConfig(allocator, provider_name, provider_version, null, repo_relative_path, failure, freshness, confidence, caveats, symbols);
}

pub fn makeExtractionWithConfig(
    allocator: std.mem.Allocator,
    provider_name: []const u8,
    provider_version: []const u8,
    config_fingerprint: ?[]const u8,
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
    symbols: []provider.CurrentSymbolEvidence,
) !Extraction {
    errdefer freeSymbols(allocator, symbols);
    const identity = try std.fmt.allocPrint(allocator, "working-tree:{s}", .{repo_relative_path});
    return .{
        .provider = .{
            .name = provider_name,
            .kind = .symbol,
            .version = provider_version,
            .config_fingerprint = config_fingerprint,
            .input = .{ .identity = identity },
            .freshness = freshness,
            .failure = failure,
            .confidence = confidence,
            .caveats = caveats,
            .provenance = .{ .provider_name = provider_name, .input_identity = identity },
        },
        .symbols = symbols,
    };
}

pub fn retargetHistoricalInput(
    allocator: std.mem.Allocator,
    extraction: *Extraction,
    input: provider.HistoricalProviderInput,
) !void {
    const identity = try provider.historicalIdentity(allocator, input);
    allocator.free(extraction.provider.input.identity);
    extraction.provider.input.identity = identity;
    extraction.provider.provenance.input_identity = identity;
}

pub fn freeCandidateSymbols(allocator: std.mem.Allocator, candidates: anytype) void {
    for (candidates) |candidate| freeSymbol(allocator, candidate.symbol);
}

pub fn freeSymbols(allocator: std.mem.Allocator, symbols: []provider.CurrentSymbolEvidence) void {
    for (symbols) |symbol| freeSymbol(allocator, symbol);
    allocator.free(symbols);
}

pub fn freeSymbol(allocator: std.mem.Allocator, symbol: provider.CurrentSymbolEvidence) void {
    allocator.free(symbol.path);
    allocator.free(symbol.name);
    if (symbol.current_line_history) |line_history| {
        for (line_history.sample_commits) |commit| allocator.free(commit);
        allocator.free(line_history.sample_commits);
        for (line_history.caveats) |caveat| allocator.free(caveat);
        allocator.free(line_history.caveats);
    }
}

pub fn readBoundedFile(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8, max_file_bytes: u64) !?[]u8 {
    const full_path = try std.fs.path.join(allocator, &.{ repo_root, repo_relative_path });
    defer allocator.free(full_path);

    const link_stat = std.Io.Dir.statFile(.cwd(), io, full_path, .{ .follow_symlinks = false }) catch return null;
    if (link_stat.kind != .file) return null;

    const file = std.Io.Dir.openFileAbsolute(io, full_path, .{}) catch return null;
    defer file.close(io);

    const stat = file.stat(io) catch return null;
    if (stat.kind != .file or stat.size > max_file_bytes) return null;

    const source = allocator.alloc(u8, @intCast(stat.size)) catch return null;
    errdefer allocator.free(source);
    const bytes_read = file.readPositionalAll(io, source, 0) catch {
        allocator.free(source);
        return null;
    };
    if (bytes_read != source.len) {
        allocator.free(source);
        return null;
    }

    return source;
}
