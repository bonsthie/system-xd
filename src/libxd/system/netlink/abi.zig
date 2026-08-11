const std = @import("std");
const linux = std.os.linux;

pub const MessageHeader = linux.nlmsghdr;
pub const MessageType = linux.NetlinkMessageType;

pub const FileDescriptor = linux.fd_t;
pub const SocketAddress = linux.sockaddr;
pub const NetlinkAddress = linux.sockaddr.nl;

pub const LinkHeader = linux.ifinfomsg;
pub const Attribute = linux.rtattr;
pub const ErrorMessage = extern struct {
    code: i32,
    message: MessageHeader,
};

pub const LinkAttribute = linux.IFLA;
pub const AddressAttribute = linux.IFA;

pub const REQUEST = linux.NLM_F_REQUEST;
pub const ACK = linux.NLM_F_ACK;
pub const DUMP = linux.NLM_F_DUMP;

pub const ALIGNMENT = linux.rtattr.ALIGNTO;
pub const INTERFACE_NAME_SIZE = linux.IFNAMESIZE;

pub const UNSPEC = linux.AF.UNSPEC;
pub const NETLINK = linux.AF.NETLINK;
pub const RAW = linux.SOCK.RAW;
pub const CLOEXEC = linux.SOCK.CLOEXEC;
pub const ROUTE = linux.NETLINK.ROUTE;
