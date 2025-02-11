{
  description = "miniRT";

  inputs = {
    systems.url = "github:nix-systems/x86_64-linux";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    systems,
  }@inputs:
    let
      supportedSystems = import systems;
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f (import nixpkgs { inherit system; }));
    in
    {
      devShell = forAllSystems (pkgs: 
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
            ];
          }
        );
    };
}
# vim: ts=2 sw=2 et

