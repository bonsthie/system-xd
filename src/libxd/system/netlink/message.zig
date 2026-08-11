const std = @import("std");
const abi = @import("abi.zig");
const syscall = @import("../syscall.zig");

pub const AttributeConfig = struct {
    type: type,
    count: usize = 1,
};

pub const View = struct {
    header: abi.MessageHeader,
    bytes: []const u8,

    pub fn payload(self: View, comptime Payload: type) !Payload {
        const payload_offset = @sizeOf(abi.MessageHeader);
        if (self.bytes.len < payload_offset + @sizeOf(Payload)) {
            return error.MalformedMessage;
        }

        return std.mem.bytesToValue(
            Payload,
            self.bytes[payload_offset..][0..@sizeOf(Payload)],
        );
    }

    pub fn checkError(self: View) !void {
        if (self.header.type != .ERROR) return error.UnexpectedMessage;

        const error_message = try self.payload(abi.ErrorMessage);
        if (error_message.code == 0) return;
        _ = try syscall.errno.wrap(error_message.code);
    }
};

pub const Reader = struct {
    bytes: []const u8,
    cursor: usize = 0,

    pub fn init(bytes: []const u8) Reader {
        return .{ .bytes = bytes };
    }

    pub fn next(self: *Reader) !?View {
        if (self.cursor == self.bytes.len) return null;

        const remaining = self.bytes[self.cursor..];
        const header = try readHeader(remaining);
        const message_length = try readMessageLength(header, remaining.len);
        self.cursor += try readMessageSize(message_length, remaining.len);

        return .{
            .header = header,
            .bytes = remaining[0..message_length],
        };
    }
};

fn readHeader(bytes: []const u8) !abi.MessageHeader {
    if (bytes.len < @sizeOf(abi.MessageHeader)) return error.MalformedMessage;

    return std.mem.bytesToValue(
        abi.MessageHeader,
        bytes[0..@sizeOf(abi.MessageHeader)],
    );
}

fn readMessageLength(header: abi.MessageHeader, available: usize) !usize {
    const length: usize = header.len;
    if (length < @sizeOf(abi.MessageHeader) or length > available) {
        return error.MalformedMessage;
    }
    return length;
}

fn readMessageSize(length: usize, available: usize) !usize {
    const aligned = std.mem.alignForward(usize, length, abi.ALIGNMENT);
    if (aligned <= available) return aligned;
    if (length == available) return length;
    return error.MalformedMessage;
}

pub fn WireWithAttributes(
    comptime Payload: type,
    comptime Attribute: type,
    comptime count: usize,
) type {
    return extern struct {
        header: abi.MessageHeader,
        payload: Payload,
        attributes: [count]Attribute,
    };
}

/// Builds an allocation-free netlink message with a fixed wire layout.
///
/// Attribute values shorter than their declared storage are zero-padded, and
/// the complete fixed-size attribute is included in both attribute and message
/// lengths.
pub fn FixedBuilder(
    comptime Payload: type,
    comptime attribute_config: AttributeConfig,
) type {
    const Attribute = attribute_config.type;
    const count = attribute_config.count;
    const Message = WireWithAttributes(Payload, Attribute, count);
    const AttributeHeader = @TypeOf(@as(Attribute, undefined).header);
    const AttributeStorage = @TypeOf(@as(Attribute, undefined).value);
    const AttributeType = @TypeOf(@as(Attribute, undefined).header.type);

    // small sanity check
    comptime {
        if (@offsetOf(Message, "payload") != @sizeOf(abi.MessageHeader)) {
            @compileError("fixed netlink payload must immediately follow the message header");
        }

        const expected_attributes_offset = std.mem.alignForward(
            usize,
            @sizeOf(abi.MessageHeader) + @sizeOf(Payload),
            abi.ALIGNMENT,
        );
        if (@offsetOf(Message, "attributes") != expected_attributes_offset) {
            @compileError("fixed netlink attributes must start at an aligned offset");
        }
        if (@offsetOf(Attribute, "header") != 0) {
            @compileError("fixed netlink attribute header must be the first field");
        }
        if (@sizeOf(AttributeHeader) != @sizeOf(abi.Attribute)) {
            @compileError("fixed netlink attribute header has an invalid wire size");
        }
        if (@offsetOf(Attribute, "value") != @sizeOf(AttributeHeader)) {
            @compileError("fixed netlink attribute value must immediately follow its header");
        }
        if (@sizeOf(Attribute) != @sizeOf(AttributeHeader) + @sizeOf(AttributeStorage)) {
            @compileError("fixed netlink attribute must not contain trailing struct padding");
        }
        if (@sizeOf(Attribute) % abi.ALIGNMENT != 0) {
            @compileError("fixed netlink attribute size must satisfy netlink alignment");
        }
        if (@sizeOf(Message) % abi.ALIGNMENT != 0) {
            @compileError("fixed netlink message size must satisfy netlink alignment");
        }
    }

    return struct {
        const Self = @This();

        pub const AttributeValue = struct {
            type: AttributeType,
            value: []const u8,
        };

        message: Message,

        pub fn init(message_type: abi.MessageType, flags: u16, sequence: u32) Self {
            var self = std.mem.zeroes(Self);
            self.message.header = .{
                .len = @sizeOf(Message),
                .type = message_type,
                .flags = flags,
                .seq = sequence,
                .pid = 0,
            };
            return self;
        }

        pub fn withPayload(self: Self, payload: Payload) Self {
            var result = self;
            result.message.payload = payload;
            return result;
        }

        pub fn withAttributes(self: Self, configs: [count]AttributeValue) !Self {
            var result = self;
            result.message.attributes = std.mem.zeroes([count]Attribute);

            for (configs, 0..) |config, index| {
                const attribute = &result.message.attributes[index];
                attribute.header = .{
                    .len = @sizeOf(Attribute),
                    .type = config.type,
                };

                if (config.value.len > attribute.value.len) {
                    return error.AttributeValueTooLong;
                }
                std.mem.copyForwards(
                    u8,
                    attribute.value[0..config.value.len],
                    config.value,
                );
            }
            return result;
        }

        pub fn send(self: *const Self, fd: abi.FileDescriptor) !void {
            var kernel_address: abi.NetlinkAddress = .{
                .pid = 0,
                .groups = 0,
            };
            const bytes = std.mem.asBytes(&self.message);
            const sent = try syscall.sendto(
                fd,
                bytes,
                0,
                @ptrCast(&kernel_address),
                @intCast(@sizeOf(abi.NetlinkAddress)),
            );
            if (sent != bytes.len) return error.ShortWrite;
        }
    };
}
