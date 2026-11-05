{
  lib,
  stdenvNoCC,
  fetchurl,
  python3,
  zstd,
  src,
  version,
  families ? null,
}:
let
  nv = "610.43.03";
  # Firmware each family requests (kernel/gpu_unlock/recipes.c).
  files = {
    turing = [
      "gsp_tu10x.bin"
      "gsp_boot_tu102.bin"
      "gsp_boot_desc_tu102.bin"
      "booter_load_tu102.bin"
      "sec2_bl_tu102.bin"
    ];
    ga100 = [
      "gsp_tu10x.bin"
      "gsp_boot_ga100.bin"
      "gsp_boot_desc_ga100.bin"
      "booter_load_ga100.bin"
      "falcon_loader.bin"
    ];
    ampere = [
      "gsp_ga10x.bin"
      "gsp_boot_ga102.bin"
      "gsp_boot_desc_ga102.bin"
      "booter_load_ga102.bin"
    ];
    ada = [
      "gsp_ga10x.bin"
      "gsp_boot_ad102.bin"
      "gsp_boot_desc_ad102.bin"
      "booter_load_ad102.bin"
    ];
  };
  selected = lib.unique (
    lib.concatMap (f: files.${f}) (if families == null then builtins.attrNames files else families)
  );
  kernelSource = fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
    sha256 = "7e118923c7a23edc36114d63273a46e3e04e9af98695a42203e7ac2dfe9fc1dc";
  };
  installer = fetchurl {
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${nv}/NVIDIA-Linux-x86_64-${nv}-no-compat32.run";
    sha256 = "e084451db730a6df29d3d74f655749c4d236e3c945f7d94b5205e84318fe2f90";
  };
in
stdenvNoCC.mkDerivation {
  pname = "gpu-unlock-firmware";
  inherit version src;

  nativeBuildInputs = [
    python3
    zstd
  ];

  dontConfigure = true;
  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    mkdir nv-src
    tar -xf ${kernelSource} -C nv-src
    python3 firmware/extract_gsp.py ${installer} assets
    python3 firmware/extract_boot_assets.py nv-src/NVIDIA-kernel-module-source-${nv} assets
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make install-firmware DESTDIR=$out ASSETS=$PWD/assets FWDIR=/lib/firmware/gpu-unlock/${nv} LICENSEDIR=/share/licenses
    cd $out/lib/firmware/gpu-unlock/${nv}
    for f in *; do
      case " ${toString selected} " in
        *" $f "*) ;;
        *) rm "$f" ;;
      esac
    done
    runHook postInstall
  '';

  passthru.families = builtins.attrNames files;

  meta = {
    description = "NVIDIA ${nv} firmware assets extracted for gpu-unlock";
    homepage = "https://github.com/Zagitta/gpu-unlock";
    license = lib.licenses.unfreeRedistributableFirmware;
    sourceProvenance = [ lib.sourceTypes.binaryFirmware ];
    platforms = [ "x86_64-linux" ];
  };
}
