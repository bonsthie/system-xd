{ pkgs, unstable-zig-flake }:

let
  zig-unstable = unstable-zig-flake.packages.${pkgs.system}.default;
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    qemu
    gdb
    flex
    bison
    valgrind
    cpio
    elfutils
    openssl
    pkg-config
    gcc
    zig-unstable
  ];
# vim: ts=2 sw=2 et
}
