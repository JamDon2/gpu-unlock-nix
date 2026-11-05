{
  description = "NixOS packaging for gpu-unlock (full-rate tensor cores on GeForce RTX 20/30/40)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gpu-unlock-src = {
      url = "github:Zagitta/gpu-unlock";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      gpu-unlock-src,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      version = nixpkgs.lib.fileContents "${gpu-unlock-src}/VERSION";
    in
    {
      packages.${system} = {
        firmware = pkgs.callPackage ./firmware.nix {
          src = gpu-unlock-src;
          inherit version;
        };
        module = pkgs.linuxPackages_latest.callPackage ./module.nix {
          src = gpu-unlock-src;
          inherit version;
        };
        default = self.packages.${system}.module;
      };

      nixosModules.default = import ./nixos.nix {
        src = gpu-unlock-src;
        inherit version;
      };
    };
}
