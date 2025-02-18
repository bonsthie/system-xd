{ 
  pkgs ? import <nixpkgs> {},
  unstable-zig-flake ? import (
    builtins.fetchTarball "https://github.com/bonsthie/unstable-zig-flake/archive/dc0d53fa3fc9b24459fa875ead1fcf4ddf1dbad8.tar.gz"
  ) {}
}:

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
    zig-unstable
  ];
# vim: ts=2 sw=2 et
}
