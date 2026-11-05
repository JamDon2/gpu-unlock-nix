# gpu-unlock-nix

A NixOS module for [gpu-unlock](https://github.com/Zagitta/gpu-unlock), which lifts the
half-rate FP16/BF16/TF32 tensor core cap on GeForce RTX 20/30/40 cards. It runs at boot,
before the `nvidia` driver takes the card.

## Usage

```nix
# flake.nix
inputs.gpu-unlock.url = "github:JamDon2/gpu-unlock-nix";

# configuration.nix
imports = [ inputs.gpu-unlock.nixosModules.default ];

hardware.gpu-unlock = {
  enable = true;
  families = [ "ampere" ];          # turing, ampere, ada, ga100 (default: all)
  # targets = [ "0000:01:00.0" ];   # PCI addresses from `lspci -D` (default: "all")
  # resume = false;                 # skip re-unlocking after suspend
  # loadIn = "initrd";              # see below
};
```

The firmware comes from NVIDIA's 610.43.03 driver, so it's unfree and needs
`nixpkgs.config.allowUnfree = true`.

After rebooting, check that it worked with `journalctl -k -b | grep gpu_unlock`.

## Root or initrd

By default (`loadIn = "root"`) a small systemd unit loads the module early in stage 2,
before anything there can load `nvidia`. The firmware stays in the Nix store, so it
doesn't take up space in `/boot`.

If you load `nvidia` in the initrd (e.g. for early KMS), the build fails with an
assertion. Set `loadIn = "initrd"` in that case. The firmware then goes into every
generation's initrd, which adds up quickly: about 68 MB for Ampere/Ada and 14 MB for Turing,
even compressed. Setting `families` to only the cards you have keeps this down.

## Packages

- `packages.x86_64-linux.module`: the kernel module, built for `linuxPackages_latest`
- `packages.x86_64-linux.firmware`: the extracted firmware

## Updating

CI updates `flake.lock` daily and only commits if everything still builds. When upstream
moves to a new NVIDIA driver, the version and hashes in `firmware.nix` need updating by hand
(copy them from upstream's `packaging/arch/PKGBUILD`).
