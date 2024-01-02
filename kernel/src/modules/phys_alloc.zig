const ModuleSpec = @import("module.zig").ModuleSpec;
const Procedures = @import("procedures.zig");

const Limine = @import("limine");
const std = @import("std");

pub export var MemoryMapRequest: Limine.MemoryMapRequest = .{};
pub export var HHDMRequest: Limine.HhdmRequest = .{};

pub const Module = ModuleSpec{
    .init = init,
    .deinit = null,
};

pub const PageSize: u64 = 4096;

const PageAllocator = packed struct {
    page_amount: u64,
    bitmap: [*]u8,
    frames: *anyopaque,
};

pub var initialized = false;
pub var Allocator: PageAllocator = undefined;

var Bitmap: []u32 = undefined;

pub fn init() void {
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

        // Equation for the amount of pages available (n) for a set amount of memory (t) and page size (p):
        // t = n/8 + pn
        // n/8 corresponds to the size of the bitmap as one byte can store information about 8 pages
        // you can then find the amount of pages:
        // n = 8t/(1+8p)
        const t: f64 = @floatFromInt(biggest_entry.?.length);
        const n: f64 = 8 * t / @as(f64, @floatCast(1.0 + 8.0 * @as(f64, @floatFromInt(PageSize))));
        const amount_of_pages: u64 = @intFromFloat(@floor(n));

        const bitmap_base = std.mem.alignForward(u64, biggest_entry.?.base, PageSize);
        const frames_base = std.mem.alignForward(u64, bitmap_base + amount_of_pages, PageSize);
        const end = std.mem.alignBackward(u64, biggest_entry.?.base + biggest_entry.?.length, PageSize);
        const new_page_amount: u64 = (end - frames_base) / 4096;

        Allocator.page_amount = new_page_amount;
        Allocator.bitmap = @ptrFromInt(biggest_entry.?.base + HHDMRequest.response.?.offset);
        Allocator.frames = @ptrFromInt(frames_base + HHDMRequest.response.?.offset);

        var addr = bitmap_base;
        while (addr < frames_base) : (addr += 16) {
            const ptr: *u128 = @ptrFromInt(addr + HHDMRequest.response.?.offset);
            ptr.* = 0;
        }

        initialized = true;
    }
}

/// Allocates a physical frame and returns the physical address.
///
/// The allocated frames aren't clean by default meaning
/// they aren't zeroed out
pub fn allocate_frame() ?*anyopaque {
    if (initialized == false) return null;

    for (0..Allocator.page_amount) |i| {
        const entry = Allocator.bitmap[i];
        if (entry == 0b11111111) continue;
        var j: u3 = 0;
        while (j < 8) : (j += 1) {
            const t = (entry << j) & 0b10000000;
            if (t == 0) {
                Allocator.bitmap[i] += @as(u8, @intCast(1)) << (7 - j);
                const frames_base = @intFromPtr(Allocator.frames);
                return @ptrFromInt(frames_base + PageSize * i * 8 + PageSize * j);
            }
        }
    }

    return null;
}
