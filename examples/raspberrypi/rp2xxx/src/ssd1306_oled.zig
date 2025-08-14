const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const i2c = rp2xxx.i2c;
const font8x8 = @import("font8x8");

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO8 = .{
        .name = "SDA",
        .function = .I2C0_SDA,
        .schmitt_trigger = .enabled,
        .slew_rate = .slow,
        .pull = .up,
        .direction = .out,
    },
    .GPIO9 = .{
        .name = "SCL",
        .function = .I2C0_SCL,
        .schmitt_trigger = .enabled,
        .slew_rate = .slow,
        .pull = .up,
        .direction = .out,
    },
};

const i2c0 = i2c.instance.num(0);
const lcd_address = rp2xxx.i2c.Address.new(0x3C);
const empty_row: []const u8 = "                ";

pub fn main() void {
    var backinf_buffer: [200 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&backinf_buffer);
    pin_config.apply();
    rp2xxx.i2c.I2C.apply(i2c0, .{ .baud_rate = 400_000, .clock_config = rp2xxx.clock_config });

    const I2C_DEVICE = rp2xxx.drivers.I2C_Device.init(i2c0, lcd_address, null);
    const lcd = microzig.drivers.display.ssd1306.init(.i2c, I2C_DEVICE, null) catch unreachable;
    lcd.clear_screen(false) catch unreachable;
    const print_val = empty_row ++ empty_row ++ empty_row ++ empty_row ++ "    WELCOME!";
    var buff: [print_val.len * 8]u8 = undefined;
    lcd.write_gdram(font8x8.Fonts.draw(&buff, print_val)) catch unreachable;

    var counter = 0;
    while (true) : (time.sleep_ms(1000)) {
        var allocator = fba.allocator();
        var counter_buf: [80]u8 = undefined;
        const text_centered = center(&counter_buf, counter);
        const text = font8x8.Fonts.drawAlloc(allocator, text_centered) catch continue;
        defer allocator.free(text);
        lcd.write_gdram(text) catch continue;
        counter += 1;
        time.sleep_ms(1000);
    }
}

fn center(buf: []u8, value: anytype) []u8 {
    var temp_buf: [32]u8 = undefined;
    const str = std.fmt.bufPrint(&temp_buf, "{}", .{value}) catch unreachable;

    const space = " ";
    const to_be_added = @divTrunc(16 - str.len, 2);
    const four_rows = empty_row ++ empty_row ++ empty_row ++ empty_row;
    @memcpy(buf[0..64], four_rows);
    for (0..to_be_added) |i| {
        @memcpy(buf[64 + i], space);
    }
    @memcpy(buf[(64 + to_be_added)..(64 + to_be_added + str.len)], str);
    return buf;
}
