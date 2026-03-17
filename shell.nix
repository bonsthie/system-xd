{ 
  pkgs ? import <nixpkgs> {}
}:

let
  stdenv = pkgs.stdenvAdapters.useMoldLinker pkgs.llvmPackages_22.stdenv;
in
(pkgs.mkShell.override { inherit stdenv; }) {
  nativeBuildInputs = with pkgs; [
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
    gcc
    gettext
    libtool
    automake
    autoconf
    zig
  ];
# vim: ts=2 sw=2 et
}
