const Procedures = @import("procedures.zig");
const Interrupts = @import("interrupts/idt.zig");

pub var current_task: *Task = undefined;
pub var new_task: *Task = undefined;
pub export var function: *const fn () void = undefined;

pub inline fn switch_tasks() void {
    Procedures.write_fmt("Trying to switch to: {}\n", .{new_task}) catch {};
    @import("../main.zig").debug_stack();
    const frame = asm volatile (
        \\cli
        \\pushq $0
        \\push %%rsp
        \\push %%rax
        \\push %%rbx
        \\push %%rcx
        \\push %%rdx
        \\push %%rbp
        \\push %%rsi
        \\push %%rdi
        \\push %%r8
        \\push %%r9
        \\push %%r10
        \\push %%r11
        \\push %%r12
        \\push %%r13
        \\push %%r14
        \\push %%r15
        \\mov %%rsp, %%rax
        : [ret] "={rax}" (-> *Interrupts.Frame),
    );

    current_task.*.frame = frame.*;
    current_task = new_task;

    asm volatile ("add $128, %%rsp");

    asm volatile (
        \\mov %[frame], %%rax
        \\mov (%rax), %%r15
        \\mov 8(%rax), %%r14
        \\mov 16(%rax), %%r13
        \\mov 24(%rax), %%r12
        \\mov 32(%rax), %%r11
        \\mov 40(%rax), %%r10
        \\mov 48(%rax), %%r9
        \\mov 56(%rax), %%r8
        \\mov 64(%rax), %%rdi
        \\mov 72(%rax), %%rsi
        \\mov 80(%rax), %%rbp
        \\mov 88(%rax), %%rdx
        \\mov 96(%rax), %%rcx
        \\mov 104(%rax), %%rbx
        \\mov 120(%rax), %%rsp
        \\mov 112(%%rax), %%rax
        :
        : [frame] "mr" (new_task.frame),
    );

    // Procedures.write_message("T3\n");
    // Procedures.write_fmt("{s} {s}\n", .{ new_task.name, current_task.name }) catch {};

    // asm volatile ("sti");

    @import("../main.zig").debug_stack();
    asm volatile ("sti");
    function();
    @import("../main.zig").debug_stack();

    while (true) {
        asm volatile ("hlt");
    }
}

pub inline fn schedule(frame: *Interrupts.Frame) void {
    Procedures.write_fmt("Schedule: {?}\n", .{current_task}) catch {};
    // switch_task(frame, current_task.?.next_task.?);
    const new_task_ = current_task.next_task.?;
    Procedures.write_fmt("Schedule {s}!\n", .{new_task_.name}) catch {};
    current_task.frame = frame.*;
    current_task = new_task_;
    Procedures.write_fmt("Schedule {s}!\n", .{current_task.name}) catch {};

    frame.* = current_task.frame;
    Procedures.write_message("Successfully set regs\n");
    // asm volatile (
    //     \\add $128, %%rax
    //     \\mov %[frame], %%rax
    //     \\mov (%%rax), %%r15
    //     \\mov 8(%%rax), %%r14
    //     \\mov 16(%%rax), %%r13
    //     \\mov 24(%%rax), %%r12
    //     \\mov 32(%%rax), %%r11
    //     \\mov 40(%%rax), %%r10
    //     \\mov 48(%%rax), %%r9
    //     \\mov 56(%%rax), %%r8
    //     \\mov 64(%%rax), %%rdi
    //     \\mov 72(%%rax), %%rsi
    //     \\mov 80(%%rax), %%rbp
    //     \\mov 88(%%rax), %%rdx
    //     \\mov 96(%%rax), %%rcx
    //     \\mov 104(%%rax), %%rbx
    //     \\mov 120(%%rax), %%rsp
    //     \\mov 112(%%rax), %%rax
    //     :
    //     : [frame] "mr" (current_task.frame),
    // );
    // @import("../main.zig").debug_stack();

    // Procedures.write_fmt("Test: {x} {*}\n", .{ r15, frame }) catch {};
    // Procedures.write_fmt("Next: {?}\n", .{next_task}) catch {};
}

pub const Task = struct {
    name: []const u8,
    next_task: ?*Task = undefined,
    frame: Interrupts.Frame = undefined,
};

pub export fn switcha_task() callconv(.C) void {
    const next_thread = current_task;
    _ = next_thread;

    asm volatile (
        \\pop %%r15
        \\pop %%r14
        \\pop %%r13
        \\pop %%r12
        \\pop %%r11
        \\pop %%r10
        \\pop %%r9
        \\pop %%r8
        \\pop %%rdi
        \\pop %%rsi
        \\pop %%rbp
        \\pop %%rdx
        \\pop %%rcx
        \\pop %%rbx
        \\pop %%rax
        \\add $32, %%rsp
        \\push %%rax
        \\iretq
    );
    // current_task = next_thread.?.next_task;
    // : [rbp] "rax" (current_task.?.base_pointer),
    //   [rsp] "rbx" (current_task.?.stack_pointer),
    // : "memory"
}
