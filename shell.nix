{
  pkgs ? import <nixpkgs> {}
}:

let
  stdenv = pkgs.llvmPackages_19.stdenv;
in
  pkgs.mkShell.override { inherit stdenv; } {
    nativeBuildInputs = with pkgs; [
      qemu
      gdb
      flex
      bison
      valgrind
      zig
      cpio
      elfutils
      openssl
      pkg-config
      gcc
    ];
  }
# vim: ts=2 sw=2 et

