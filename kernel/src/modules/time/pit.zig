const Ports = @import("../ports.zig");

pub fn initPIT() void {
    // const pit_counter = Ports.Port(u8).new(0x40);
    const pit_cmd = Ports.Port(u8).new(0x43);

    const binary_mode = 0x0;
    const channel_select = 0;
    const access_mode_low_high = 0x30;
    const mode_square_wave = 0x06;

    pit_cmd.write(channel_select | access_mode_low_high | mode_square_wave | binary_mode);
}
