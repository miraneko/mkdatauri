const flags = @import("flags");
const std = @import("std");

var args_buffer: [4096]u8 = undefined;
var input_buffer: [4095]u8 = undefined;
var output_buffer: [12285]u8 = undefined;

const Flags = struct {
    pub const description = "A simple tool to make data: URIs.";

    pub const descriptions = .{
        .type = "Set the content type",
        .charset = "Set the character set",
        .utf8 = "Set the character set to UTF-8",
        .base64 = "Use base64 instead of percent encoding",
        .no_newline = "Suppress newline",
    };

    pub const switches = .{
        .type = 't',
        .charset = 'c',
        .utf8 = 'u',
        .base64 = 'b',
        .no_newline = 'n',
    };

    type: ?[]const u8,
    charset: ?[]const u8,
    utf8: bool,
    base64: bool,
    no_newline: bool,
    positional: struct {
        file: ?[]const u8,

        pub const descriptions = .{
            .file = "File to encode into data: URI; if no FILE is given, read standard input",
        };
    },
};

fn isUnreserved(byte: u8) bool {
    return switch (byte) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

pub fn percentEncode(destination: []u8, source: []const u8) ![]u8 {
    var out_index: usize = 0;
    for (source) |byte| {
        if (isUnreserved(byte)) {
            if (out_index >= destination.len) return error.NoSpaceLeft;
            destination[out_index] = byte;
            out_index += 1;
        } else {
            if (out_index + 3 > destination.len) return error.NoSpaceLeft;
            destination[out_index] = '%';
            @memcpy(destination[out_index + 1 .. out_index + 3], &std.fmt.hex(byte));
            out_index += 3;
        }
    }
    return destination[0..out_index];
}

pub fn main() !void {
    var args_fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(&args_buffer);
    const args_allocator = args_fixed_buffer_allocator.allocator();

    const args = try std.process.argsAlloc(args_allocator);

    const cli = flags.parse(
        args,
        "mkdatauri",
        Flags,
        .{},
    );

    const stdout = std.io.getStdOut().writer();
    const input = if (cli.positional.file) |filename|
        (try std.fs.cwd().openFile(filename, .{})).reader()
    else
        std.io.getStdIn().reader();

    {
        @memcpy(output_buffer[0..5], "data:");
        var current_offset: usize = 5;

        if (cli.type) |content_type| {
            @memcpy(output_buffer[current_offset .. current_offset + content_type.len], content_type);
            current_offset = current_offset + content_type.len;
        }

        if (cli.charset) |charset| {
            @memcpy(output_buffer[current_offset .. current_offset + 9], ";charset=");
            current_offset = current_offset + 9;
            @memcpy(output_buffer[current_offset .. current_offset + charset.len], charset);
            current_offset = current_offset + charset.len;
        } else if (cli.utf8) {
            @memcpy(output_buffer[current_offset .. current_offset + 14], ";charset=UTF-8");
            current_offset = current_offset + 14;
        }

        if (cli.base64) {
            @memcpy(output_buffer[current_offset .. current_offset + 8], ";base64,");
            current_offset = current_offset + 8;
        } else {
            @memcpy(output_buffer[current_offset .. current_offset + 1], ",");
            current_offset = current_offset + 1;
        }

        try stdout.writeAll(output_buffer[0..current_offset]);
    }

    while (true) {
        const input_len = try input.readAll(&input_buffer);
        const output = if (cli.base64)
            std.base64.standard.Encoder.encode(&output_buffer, input_buffer[0..input_len])
        else
            percentEncode(&output_buffer, input_buffer[0..input_len]) catch unreachable;
        try stdout.writeAll(output);
        if (input_len < input_buffer.len) break;
    }

    if (!cli.no_newline) try stdout.writeAll("\n");
}
