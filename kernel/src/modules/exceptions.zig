const ModuleSpec = @import("module.zig").ModuleSpec;
const Interrupts = @import("interrupts.zig");
const Procedures = @import("procedures.zig");

const std = @import("std");

pub const Module = ModuleSpec{
    .init = init,
    .deinit = null,
};

pub fn init() void {
    for (0..0xF) |i| {
        Interrupts.add_interrupt(@intCast(i), default_handler);
    }

    Interrupts.load();
}

/// Only to be used on known interrupts
pub fn default_handler(frame: *Interrupts.Frame) void {
    Procedures.write_fmt("Interrupt: {} invoked\n", .{frame.idx}) catch {};
    Procedures.write_fmt("Interrupt: {s} invoked\n", .{Interrupts.name(frame.idx)}) catch {};
    while (true) {
        asm volatile ("hlt");
    }
}
