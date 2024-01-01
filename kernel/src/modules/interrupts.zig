const handlers_amount = 256;
pub var idt = [1]InterruptDescriptor{undefined} ** handlers_amount;

const Trampoline = fn () callconv(.Naked) void;
const Handler = fn (*Frame) void;

fn generate_trampolines() [handlers_amount]*const Trampoline {
    var result: [handlers_amount]*const Trampoline = undefined;

    inline for (0..256) |interruptIdx| {
        result[interruptIdx] = comptime make_trampoline(interruptIdx);
    }

    return result;
}

var trampolines: [handlers_amount]*const Trampoline = generate_trampolines();
var handlers: [handlers_amount]*const Handler = undefined;

pub fn make_trampoline(comptime interruptIdx: u8) *const Trampoline {
    return struct {
        fn trampoline() callconv(.Naked) void {
            asm volatile ("push %[int]\njmp catcher\n"
                :
                : [int] "i" (@as(u8, interruptIdx)),
            );
        }
    }.trampoline;
}

export fn catcher() callconv(.Naked) void {
    asm volatile (
        \\mov %%rsp, %%rdi
        \\call handler_fn
        \\pop %%rax
        \\iretq
    );
}

pub const Frame = extern struct {
    idx: u64,
    ec: u64,
};

export fn handler_fn(frame: *Frame) void {
    handlers[frame.idx](frame);
}

pub fn load() void {
    const idtr = IDTR{
        .base = @intFromPtr(&idt),
        .limit = @sizeOf(@TypeOf(idt)) - 1,
    };

    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idtr),
    );
}

pub fn add_interrupt(idx: u8, handler: *const Handler) void {
    const pointer = @intFromPtr(trampolines[idx]);
    handlers[idx] = handler;

    const cs = asm ("mov %%cs, %[ret]"
        : [ret] "=r" (-> u16),
    );

    var entry = InterruptDescriptor{};

    entry.selector = cs;
    entry.options.gate_type = 0xE;

    entry.offset_low = @as(u16, @truncate(pointer));
    entry.offset_mid = @as(u16, @truncate(pointer >> 16));
    entry.offset_high = @as(u32, @truncate(pointer >> 32));

    entry.options.present = true;

    idt[idx] = entry;
}

const EntryOptions = packed struct(u16) {
    ist: u3 = 0,
    // Reserved do not use
    reserved1: u5 = 0,
    // default: interrupt gate (0b1110)
    gate_type: u4 = 0x0,
    // Reserved do not use
    reserved2: u1 = 0,
    privledge_level: u2 = 0,
    present: bool = false,
};

const InterruptDescriptor = extern struct {
    offset_low: u16 = 0,
    selector: u16 = 0,
    options: EntryOptions = .{},
    offset_mid: u16 = 0,
    offset_high: u32 = 0,
    reserved: u32 = 0,
};

pub const IDTR = packed struct {
    limit: u16,
    base: u64,
};

pub fn name(intnum: u64) []const u8 {
    return switch (intnum) {
        0x00 => "Divide by zero",
        0x01 => "Debug",
        0x02 => "Non-maskable interrupt",
        0x03 => "Breakpoint",
        0x04 => "Overflow",
        0x05 => "Bound range exceeded",
        0x06 => "Invalid opcode",
        0x07 => "Device not available",
        0x08 => "Double fault",
        0x09 => "Coprocessor Segment Overrun",
        0x0A => "Invalid TSS",
        0x0B => "Segment Not Present",
        0x0C => "Stack-Segment Fault",
        0x0D => "General Protection Fault",
        0x0E => "Page Fault",
        0x0F => unreachable,
        0x10 => "x87 Floating-Point Exception",
        0x11 => "Alignment Check",
        0x12 => "Machine Check",
        0x13 => "SIMD Floating-Point Exception",
        0x14 => "Virtualization Exception",
        0x15...0x1D => unreachable,
        0x1E => "Security Exception",

        else => unreachable,
    };
}
