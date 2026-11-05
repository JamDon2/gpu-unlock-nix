{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
  src,
  version,
}:
let
  kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
stdenv.mkDerivation {
  pname = "gpu-unlock";
  version = "${version}-${kernel.version}";
  inherit src;
  sourceRoot = "source/kernel/gpu_unlock";

  __structuredAttrs = true;
  strictDeps = true;
  enableParallelBuilding = true;

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [ "pic" ];

  makeFlags = kernelModuleMakeFlags ++ [ "KERNELRELEASE=${kernel.modDirVersion}" ];

  buildPhase = ''
    runHook preBuild
    make -C ${kdir} M=$(pwd) "''${makeFlags[@]}" modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C ${kdir} M=$(pwd) "''${makeFlags[@]}" modules_install \
      DEPMOD=true INSTALL_MOD_PATH=$out
    runHook postInstall
  '';

  meta = {
    description = "Pre-driver unlock of full-rate FP16/BF16/TF32 tensor cores on GeForce RTX 20/30/40";
    homepage = "https://github.com/Zagitta/gpu-unlock";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
