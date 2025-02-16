{ pkgs, unstable-zig-flake }:

let
  zig-unstable = pkgs.zig;# unstable-zig-flake.packages.${pkgs.system}.default;
  stdenv = pkgs.llvmPackages_19.stdenv;
in
(pkgs.mkShell.override { inherit stdenv; }) {
  nativeBuildInputs = with pkgs; [
    qemu
    gdb
    flex
    bison
    valgrind
    cpio
    libarchive
    elfutils
    openssl
    pkg-config
    gcc
    zig-unstable
  ];
# vim: ts=2 sw=2 et
}
