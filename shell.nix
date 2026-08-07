{ 
  pkgs ? import <nixpkgs> {},
}:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    python3
    zig
    e2tools
    qemu
    gdb
    flex
    bison
    valgrind
    mount
    cpio
    libarchive
    elfutils
    fd
    openssl
    pkg-config
    gettext
    libtool
    automake
    autoconf
  ];
  shellHook = ''
    unset ZIG_GLOBAL_CACHE_DIR
  '';
# vim: ts=2 sw=2 et
}
