{ src, version }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.gpu-unlock;
in
{
  options.hardware.gpu-unlock = {
    enable = lib.mkEnableOption "gpu-unlock, which lifts the GeForce half-rate tensor core cap at boot";

    targets = lib.mkOption {
      type = lib.types.either (lib.types.enum [ "all" ]) (lib.types.listOf lib.types.str);
      default = "all";
      example = [ "0000:01:00.0" ];
      description = ''
        Cards to unlock: "all", or a list of full PCI addresses as `lspci -D` prints them.
      '';
    };

    loadIn = lib.mkOption {
      type = lib.types.enum [
        "root"
        "initrd"
      ];
      default = "root";
      description = ''
        Where gpu_unlock is loaded. "root" keeps the firmware out of /boot but
        requires nvidia to not be in the initrd. Use "initrd" if it is (e.g. for
        early KMS); the firmware is then copied into every generation's initrd.
      '';
    };

    resume = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Unlock the cards again after suspend to RAM.";
    };

    families = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "turing"
          "ampere"
          "ada"
          "ga100"
        ]
      );
      default = [
        "turing"
        "ampere"
        "ada"
        "ga100"
      ];
      example = [ "ampere" ];
      description = ''
        GPU families to include firmware for: turing (RTX 20), ampere (RTX 30),
        ada (RTX 40), ga100 (A100). Cards of other families are not unlocked.
        Worth trimming with `loadIn = "initrd"`: Ampere/Ada adds ~68 MB to each
        initrd, Turing ~14 MB.
      '';
    };

    firmwarePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./firmware.nix {
        inherit src version;
        inherit (cfg) families;
      };
      defaultText = lib.literalMD "firmware for `families`, extracted from the pinned NVIDIA 610.43.03 driver";
    };

    modulePackage = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.callPackage ./module.nix { inherit src version; };
      defaultText = lib.literalMD "gpu_unlock built for `config.boot.kernelPackages`";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        boot.extraModulePackages = [ cfg.modulePackage ];
        hardware.firmware = [ cfg.firmwarePackage ];

        boot.kernelParams = [
          "gpu_unlock.targets=${if cfg.targets == "all" then "all" else lib.concatStringsSep "," cfg.targets}"
        ]
        ++ lib.optional (!cfg.resume) "gpu_unlock.resume=0";
      }

      (lib.mkIf (cfg.loadIn == "initrd") {
        # MODULE_FIRMWARE pulls the firmware into the initrd along with it.
        boot.initrd.kernelModules = [ "gpu_unlock" ];
      })

      (lib.mkIf (cfg.loadIn == "root") {
        # Both systemd-modules-load and udev coldplug can load nvidia, so run first.
        # modprobe returns once every card is unlocked.
        systemd.services.gpu-unlock = {
          description = "Unlock GeForce tensor cores before nvidia binds";
          wantedBy = [ "sysinit.target" ];
          before = [
            "sysinit.target"
            "systemd-modules-load.service"
            "systemd-udev-trigger.service"
          ];
          restartIfChanged = false;
          unitConfig = {
            DefaultDependencies = false;
            ConditionPathExists = "!/sys/module/nvidia";
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.kmod}/bin/modprobe gpu_unlock";
          };
        };

        assertions =
          let
            inInitrd = lib.filter (lib.hasPrefix "nvidia") (
              config.boot.initrd.kernelModules ++ config.boot.initrd.availableKernelModules
            );
          in
          [
            {
              assertion = inInitrd == [ ];
              message = ''
                hardware.gpu-unlock: ${lib.concatStringsSep ", " inInitrd} in the initrd would bind
                the card before gpu_unlock runs from the root filesystem. Remove it from
                boot.initrd.{kernelModules,availableKernelModules}, or set
                hardware.gpu-unlock.loadIn = "initrd".
              '';
            }
          ];
      })
    ]
  );
}
