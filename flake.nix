{
  description = "system-xd";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: function nixpkgs.legacyPackages.${system}
        );
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt);
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            python3
            zig
            e2tools
            qemu
            mount
            cpio
            libarchive
            fd
            libguestfs-with-appliance
          ];
          shellHook = ''
            unset ZIG_GLOBAL_CACHE_DIR
          '';
        };
      });
    };
}
