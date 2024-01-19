const Procedures = @import("procedures.zig");
const Interrupts = @import("interrupts/idt.zig");
const PhysAlloc = @import("phys_alloc.zig");

pub var current_task: *Task = undefined;

pub fn schedule_task(name: []const u8, function: *const fn () void) !void {
    asm volatile ("cli");

    _ = name;
    const task_slice = try PhysAlloc.allocator().alloc(Task, 1);
    const task: *Task = @constCast(&task_slice.ptr[0]);

    task.started = false;
    task.function = function;
    current_task.next_task = task;
    task.next_task = current_task;

    const stack = try PhysAlloc.allocator().alloc(u8, 1000);
    task.frame.rsp = @intFromPtr(stack.ptr) + stack.len;
    task.frame.rbp = @intFromPtr(stack.ptr) + stack.len;

    asm volatile ("sti");
}

pub inline fn schedule(frame: *Interrupts.Frame) void {
    const new_task_ = current_task.next_task.?;
    current_task.frame = frame.*;
    current_task = new_task_;

    if (!current_task.started) {
        // Inherit context from last task (SHOULD BE CHANGED!)
        current_task.frame.cs = frame.cs;
        current_task.frame.eflags = frame.eflags;
        current_task.frame.ss = frame.ss;
        current_task.frame.rip = @intFromPtr(current_task.function.?);
        current_task.started = true;
    }

    frame.* = current_task.frame;
}

pub const Task = struct {
    name: []const u8,
    next_task: ?*Task = undefined,
    frame: Interrupts.Frame = undefined,
    started: bool = false,
    function: ?*const fn () void = null,
};
