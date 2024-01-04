const ModuleSpec = @import("module.zig").ModuleSpec;
const Procedures = @import("procedures.zig");

const Limine = @import("limine");
const std = @import("std");

pub export var MemoryMapRequest: Limine.MemoryMapRequest = .{};
pub export var HHDMRequest: Limine.HhdmRequest = .{};

pub const Module = ModuleSpec{
    .name = "Physical Allocation",
    .init = init,
    .deinit = null,
};

pub const PageSize: u64 = 4096;
pub var offset: u64 = undefined;

const PAGE_SIZES = ps: {
    comptime var current_shift = 12; // log2 of PageSize
    comptime var sizes: []const usize = &[0]usize{};

    while (current_shift < 24) : (current_shift += 1) {
        sizes = sizes ++ [1]usize{1 << current_shift};
    }

    break :ps sizes;
};

pub var free_roots_per_order = [_]u64{0} ** PAGE_SIZES.len;

pub var initialized = false;

pub fn init() void {
    if (HHDMRequest.response) |res| offset = res.offset;
    if (MemoryMapRequest.response) |memory_map| {
        var biggest_entry: ?*Limine.MemoryMapEntry = null;

        for (0..memory_map.entry_count) |i| {
            const entry = memory_map.entries_ptr[i];

            if (entry.kind == Limine.MemoryMapEntryType.usable and (biggest_entry == null or entry.length > biggest_entry.?.length)) {
                biggest_entry = entry;
            }
        }

        if (biggest_entry == null) {
            Procedures.write_fmt("Couldn't find any usable piece of memory\n", .{}) catch {};
            return;
        }

        add_entry(biggest_entry.?.base + offset, std.mem.alignBackward(u64, biggest_entry.?.length, PageSize));

        initialized = true;
    }
}

/// Allocates for a set size corresponding to
/// an index in the PAGE_SIZE list
pub fn alloc(index: usize) !u64 {
    if (free_roots_per_order[index] == 0) {
        if (index + 1 >= PAGE_SIZES.len)
            return error.OutOfMemory;

        var next_alloc = try alloc(index + 1);
        var next_size = PAGE_SIZES[index + 1];
        const desired_size = PAGE_SIZES[index];

        while (next_size > desired_size) {
            free(next_alloc, index);
            next_alloc += desired_size;
            next_size -= desired_size;
        }

        return next_alloc;
    }

    const addr = free_roots_per_order[index];
    const ptr_new_root: *u64 = @ptrFromInt(addr);
    const new_root = ptr_new_root.*;

    free_roots_per_order[index] = new_root;
    return addr;
}

/// Frees data by PAGE_SIZE index and address
pub fn free(addr: u64, index: usize) void {
    const last_freed = free_roots_per_order[index];
    free_roots_per_order[index] = addr;
    const new_entry: *u64 = @ptrFromInt(addr);
    new_entry.* = last_freed;
}

/// Takes a memory map entry and adds it
/// to the free roots
pub fn add_entry(addr: u64, length: u64) void {
    var current_addr = addr;
    var current_length = length;

    while (current_length > 0) {
        for (0..PAGE_SIZES.len) |i| {
            const size = PAGE_SIZES[PAGE_SIZES.len - i - 1];

            if (current_length >= size) {
                free(current_addr, i);
                current_length -= size;
                current_addr += size;
            }
        }
    }
}

/// Same as for alloc but takes a size
/// instead of an index
pub fn allocate_by_size(size: usize) !u64 {
    for (PAGE_SIZES, 0..) |page_size, i| {
        if (page_size >= size) {
            return try alloc(i);
        }
    }

    return error.SizeTooSmall;
}

/// Gives the actual size that would allocated
/// for an arbitrary size
pub fn page_size_for_alloc(size: usize) usize {
    for (PAGE_SIZES) |page_size| {
        if (page_size >= size) {
            return page_size;
        }
    }
    unreachable;
}

/// Frees data by size instead of PAGE_SIZE index
pub fn free_by_size(addr: u64, size: usize) void {
    for (PAGE_SIZES, 0..) |page_size, i| {
        if (page_size >= size) {
            return free(addr, i);
        }
    }

    unreachable;
}

pub const Allocator = struct {
    fn alloc_(_: *anyopaque, len: usize, ptr_align: u8, _: usize) ?[*]u8 {
        const alloc_len = page_size_for_alloc(@max(len, std.math.shl(usize, 1, ptr_align)));

        return @ptrFromInt(allocate_by_size(alloc_len) catch {
            return null;
        });
    }

    fn resize(_: *anyopaque, old_buf: []u8, buf_align: u8, new_len: usize, _: usize) bool {
        const old_alloc_len = page_size_for_alloc(@max(old_buf.len, std.math.shl(usize, 1, buf_align)));
        const new_alloc_len = page_size_for_alloc(@max(new_len, std.math.shl(usize, 1, buf_align)));
        const addr = @intFromPtr(old_buf.ptr);

        if (new_alloc_len > old_alloc_len)
            return false;
        var curr_alloc_len = old_alloc_len;

        while (curr_alloc_len > new_alloc_len) {
            free_by_size(addr, curr_alloc_len / 2);
            curr_alloc_len /= 2;
        }
        return true;
    }

    fn free_(_: *anyopaque, buf: []u8, buf_align: u8, _: usize) void {
        free_by_size(@intFromPtr(buf.ptr), page_size_for_alloc(@max(buf.len, buf_align)));
    }
};

pub const AllocatorVTable: std.mem.Allocator.VTable = .{ .alloc = Allocator.alloc_, .resize = Allocator.resize, .free = Allocator.free_ };

pub fn allocator() std.mem.Allocator {
    return .{ .ptr = undefined, .vtable = &AllocatorVTable };
}
