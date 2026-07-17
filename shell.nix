{ 
  pkgs ? import <nixpkgs> {},
}:

let
  stdenv = pkgs.stdenvAdapters.useMoldLinker pkgs.llvmPackages_22.stdenv;
in
(pkgs.mkShell.override { inherit stdenv; }) {
  nativeBuildInputs = with pkgs; [
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
