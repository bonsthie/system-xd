const std = @import("std");
const linux = std.os.linux;

pub const MessageHeader = linux.nlmsghdr;
pub const MessageType = linux.NetlinkMessageType;

pub const FileDescriptor = linux.fd_t;
pub const SocketAddress = linux.sockaddr;
pub const NetlinkAddress = linux.sockaddr.nl;

pub const LinkAttribute = linux.IFLA;
pub const AddressAttribute = linux.IFA;
pub const RouteAttribute = enum(c_ushort) {
    UNSPEC,
    DST,
    SRC,
    IIF,
    OIF,
    GATEWAY,
    PRIORITY,
    PREFSRC,
    METRICS,
    MULTIPATH,
    PROTOINFO,
    FLOW,
    CACHEINFO,
    SESSION,
    MP_ALGO,
    TABLE,
    MARK,
    MFC_STATS,
    VIA,
    NEWDST,
    PREF,
    ENCAP_TYPE,
    ENCAP,
    EXPIRES,
    PAD,
    UID,
    TTL_PROPAGATE,
    IP_PROTO,
    SPORT,
    DPORT,
    NH_ID,

    _,
};

pub const LinkHeader = linux.ifinfomsg;
pub const AddressHeader = extern struct {
    family: u8,
    prefix_length: u8,
    flags: u8,
    scope: u8,
    index: u32,
};
pub const RouteHeader = extern struct {
    family: u8,
    destination_length: u8,
    source_length: u8,
    tos: u8,
    table: u8,
    protocol: u8,
    scope: u8,
    type: u8,
    flags: u32,
};
pub const Attribute = extern struct {
    len: c_ushort,
    type: extern union {
        link: LinkAttribute,
        addr: AddressAttribute,
        route: RouteAttribute,
    },
};
pub const ErrorMessage = extern struct {
    code: i32,
    message: MessageHeader,
};

pub const REQUEST = linux.NLM_F_REQUEST;
pub const ACK = linux.NLM_F_ACK;
pub const DUMP = linux.NLM_F_DUMP;
pub const EXCLUSIVE = linux.NLM_F_EXCL;
pub const CREATE = linux.NLM_F_CREATE;

pub const ALIGNMENT = linux.rtattr.ALIGNTO;
pub const INTERFACE_NAME_SIZE = linux.IFNAMESIZE;

pub const UNSPEC = linux.AF.UNSPEC;
pub const INET = linux.AF.INET;
pub const NETLINK = linux.AF.NETLINK;
pub const RAW = linux.SOCK.RAW;
pub const CLOEXEC = linux.SOCK.CLOEXEC;
pub const ROUTE = linux.NETLINK.ROUTE;

pub const MAIN_TABLE = 254;
pub const BOOT_PROTOCOL = 3;
pub const UNIVERSE_SCOPE = 0;
pub const UNICAST_ROUTE = 1;
