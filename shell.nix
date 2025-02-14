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

  shellHook = ''
    echo "Zig (from GitHub flake) is available: $(zig version)"
  '';
}
