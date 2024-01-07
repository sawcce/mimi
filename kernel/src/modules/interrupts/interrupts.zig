const ModuleSpec = @import("../module.zig").ModuleSpec;
const Interrupts = @import("idt.zig");
const Procedures = @import("../procedures.zig");
const APIC = @import("../apic/apic.zig");
const LAPIC = @import("../apic/local_apic.zig");
const PIT = @import("../time/pit.zig");

const std = @import("std");

pub const ExceptionsModule = ModuleSpec{
    .name = "Exceptions",
    .init = init_exceptions,
    .deinit = null,
};

pub fn init_exceptions() void {
    for (0..0xF) |i| {
        Interrupts.add_interrupt(@intCast(i), Interrupts.GateType.Interrupt, default_handler);
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

pub const InterruptsModule = ModuleSpec{
    .name = "Interrupts",
    .init = init_int,
    .deinit = null,
};

pub fn init_int() void {
    Interrupts.add_interrupt(0x20, Interrupts.GateType.Interrupt, pit_handler);
    PIT.initPIT();

    asm volatile ("sti");
}

pub fn pit_handler(f: *Interrupts.Frame) void {
    Procedures.write_fmt("Test {}!\n", .{f}) catch {};
    APIC.LAPIC_REF.?.writeRegister(LAPIC.REG.EOI, 0);
}
