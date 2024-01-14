const ModuleSpec = @import("../module.zig").ModuleSpec;

pub const Module = ModuleSpec{
    .name = "Global Descriptor Table",
    .init = init,
    .deinit = null,
};

pub var GDTR = GDTR_s{
    .size = GDT.len * @sizeOf(SegmentDescriptor) - 1,
    .offset = undefined,
};

pub var GDT: [3]SegmentDescriptor = undefined;

const code_descriptor = SegmentDescriptor{
    .flags = Flags{
        .granularity = .Page,
        .long_mode = true,
    },
    .access_byte = AccessByte{
        .present = true,
        .segment_type = .Code,
        .direction_bit = 0,
        .rw_access = .Allowed,
    },
};

const data_descriptor = SegmentDescriptor{
    .flags = Flags{
        .granularity = .Page,
        .long_mode = true,
    },
    .access_byte = AccessByte{
        .present = true,
        .segment_type = .Data,
        .direction_bit = 0,
        .rw_access = .Allowed,
    },
};

pub fn init() void {
    GDTR.offset = @intCast(@intFromPtr(&GDT));

    const null_ptr: *u64 = @ptrCast(&GDT);
    null_ptr.* = 0;

    GDT[1] = code_descriptor;
    GDT[2] = data_descriptor;

    asm volatile ("lgdt %[p]"
        :
        : [p] "*p" (&GDTR),
    );

    asm volatile (
        \\ push %[code_selector]
        \\ lea 1f(%rip), %%rax
        \\ push %%rax
        \\ lretq                    
        \\ 1:
        \\  mov %[data_selector], %%ds
        \\  mov %[data_selector], %%fs
        \\  mov %[data_selector], %%gs
        \\  mov %[data_selector], %%es
        \\  mov %[data_selector], %%ss
        :
        : [code_selector] "i" (@as(u16, 0x08)),
          [data_selector] "rm" (@as(u16, 0x10)),
    );
}

const GDTR_s = packed struct {
    size: u16,
    offset: u64,
};

const SegmentDescriptor = packed struct(u64) {
    /// Least significant part (little-endian)
    limit_2: u16 = 0,
    /// Least significant part (little-endian)
    base_lsp: u24 = 0,
    access_byte: AccessByte,
    limit: u4 = 0,
    flags: Flags,
    base: u8 = 0,
};

pub const Flags = packed struct(u4) {
    _: bool = false,
    long_mode: bool, // the size bit should always be clear if this flag is set
    size: enum(u1) { // the long_mode bit should always be clear if this flag is used (cleared or not)
        L16 = 0, // 16 bit segment
        L32 = 1, // 32 bit segment
    } = .L16,
    granularity: enum(u1) {
        Byte = 0,
        Page = 1,
    },
};

pub const AccessByte = packed struct(u8) {
    accessed: bool = false,
    rw_access: enum(u1) {
        Forbidden = 0,
        Allowed = 1,
    },
    direction_bit: u1 = 0,
    segment_type: enum(u1) { Data = 0, Code = 1 },
    descriptor_type: enum(u1) { TSS = 0, DataOrCode = 1 } = .DataOrCode,
    dpl: u2 = 0,
    present: bool,
};
