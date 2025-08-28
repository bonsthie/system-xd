# system-xd @ [userspace-digressions](https://projects.intra.42.fr/42cursus-userspace_digressions/babonnet)

> Also known as learning Zig while re-writing systemd (kinda).

## Usage

`TODO`

## How to compile

### Developer Environment
This project provides its required dependencies in a development environment via [Nix](https://nixos.org).  
You can use it in different ways:

#### nix-shell command

Simply run `nix-shell` in the directory with a recent `nixpkgs` channel, and it will spawn you a shell with the proper environment.

#### nix develop

The modern `nix`-command flake-y equivalent to `nix-shell`, simply run `nix develop` and the shell will appear. 

#### direnv

A `.envrc` file is provided for convenience, that will automatically update your shell environment using the [nix flake](./flake.nix).

### Compiling

Simply run `zig build` and it'll compile and statically link both the `init` and `xd` executables in `./zig-out/bin`.

## Development links

- https://man.freebsd.org/cgi/man.cgi?query=init&sektion=8&apropos=0&manpath=FreeBSD+14.2-RELEASE+and+Ports
- https://man.freebsd.org/cgi/man.cgi?query=getty&sektion=8
- https://github.com/torvalds/linux/blob/42dc814987c1feb6410904e58cfd4c36c4146150/tools/testing/selftests/wireguard/qemu/init.c
- https://git.busybox.net/busybox/tree/util-linux/switch_root.c?h=1_37_stable
- https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in?ref_type=heads

## License

This project is licensed under the [ISC License](./LICENSE).
