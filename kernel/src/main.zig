const limine = @import("limine");
const std = @import("std");
const Ports = @import("modules/ports.zig");
const Module = @import("modules/module.zig");

// Set the base revision to 1, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 1 };

inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

const GDT = @import("modules/gdt/gdt.zig");
const Procedures = @import("modules/procedures.zig");
const Interrupts = @import("modules/interrupts/interrupts.zig");
const PhysAlloc = @import("modules/phys_alloc.zig");
const ACPI = @import("modules/acpi/acpi.zig");
const PCI = @import("modules/pci/pci.zig");
const Display = @import("modules/display/display.zig");
const USB = @import("modules/usb/usb.zig");

const Modules = [_]Module.ModuleSpec{
    Procedures.Module,
    Interrupts.ExceptionsModule,
    ACPI.Module,
    Interrupts.InterruptsModule,
    PCI.Module,
    Display.Module,
    USB.Module,
};

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    main() catch |e| {
        Procedures.write_fmt("Error: {}", .{e}) catch {};
    };

    // We're done, just hang...
    done();
}

fn main() !void {
    if (GDT.Module.init) |init| init();
    if (PhysAlloc.Module.init) |init| init();

    const Task = @import("./modules/task.zig");

    var t: Task.Task = .{ .name = "boot" };

    t.next_task = &t;
    Task.current_task = &t;

    Module.init();
    try Module.loaded_modules.append(GDT.Module);
    try Module.loaded_modules.append(PhysAlloc.Module);

    try Module.init_modules(&Modules);
    Procedures.write_message("Modules successfully initialized!\n");

    var t2: Task.Task = .{ .name = "second" };
    t.next_task = &t2;
    t2.next_task = &t;
    const stack = try PhysAlloc.allocator().alloc(u8, 100000);
    t2.frame.rsp = @intFromPtr(stack.ptr) + stack.len;
    t2.frame.rbp = @intFromPtr(stack.ptr) + stack.len;
    Task.new_task = &t2;
    Task.function = &test_test;

    Task.switch_tasks();

    // Procedures.write_message("[ Hey ]!\n");
    // debug_stack();
    while (true) {
        Procedures.write_message("Test\n");
        asm volatile ("hlt");
    }
}

pub fn test_test() void {
    Procedures.write_fmt("========= Test ==========\n", .{}) catch {};
    debug_stack();
    Procedures.write_fmt("========= Test END ==========\n", .{}) catch {};

    while (true) {
        // Procedures.write_message("Hello! :3\n");
    }
}

pub inline fn debug_stack() void {
    const rbp = asm volatile (""
        : [ret] "={rbp}" (-> u64),
    );
    const rsp = asm volatile (""
        : [ret] "={rsp}" (-> u64),
    );
    Procedures.write_fmt("Rsp: 0x{x}, Rbp: 0x{x}\n", .{ rsp, rbp }) catch {};
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, e: ?usize) noreturn {
    @setCold(true);

    _ = error_return_trace;
    _ = e;

    try Procedures.write_fmt("[PANIC!] {s}\n", .{msg});

    done();
}
