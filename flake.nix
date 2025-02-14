{
  description = "system-xd";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/x86_64-linux";
    unstable-zig-flake.url = "github:bonsthie/unstable-zig-flake";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = (import inputs.systems);
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = (import ./shell.nix) {
            inherit pkgs;
            unstable-zig-flake = inputs.unstable-zig-flake;
          };
        }
      );
    };
}
