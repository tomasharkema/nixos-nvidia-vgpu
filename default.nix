{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.hardware.nvidia.vgpu;

  mdevctl = pkgs.callPackage ./mdevctl {};
  pythonPackages = pkgs.python311Packages;
  # frida = pythonPackages.callPackage ./frida {};

  versions = {
    "v16.5" = {
      vgpuVersion = "535.161.05";
      gridVersion = "535.161.08";
      guestVersion = "538.46";

      vgpuSha = "1cq8bsmxkla56r0vqr0c5a7b2r1da5df2qvdzqnnm15agqj3w28v";
      gridSha = "085lybyd3pdnd3gh2p6m0sndw1smc4ds9g6l36liwswf5ycn3bg4";
    };

    "v17.1" = {
      vgpuVersion = "550.54.16";
      gridVersion = "550.54.15";
      guestVersion = "551.78";

      vgpuSha = "18ss9r6pqd5fvayxyvz94sgiszg54y4mv62b4mrmdfk5sxfmpgw3";
      gridSha = "0nm17q9qx3x2w5jjga93pzraplmykbmix365a5gpi96jig98x6g1";
    };
  };

  driver = versions."${cfg.version}";

  gpuPatches = pkgs.fetchFromGitLab {
    owner = "polloloco";
    repo = "vgpu-proxmox";
    rev = "eeca1f0990c917ae10ca0a3b0c71a7c94841e29a";
    hash = "sha256-qbZ+A3Q0TS9dyfSjdkNn7yu7kJRYAaQwmOvpJrxVvj0=";
  };

  combinedZipName = "NVIDIA-GRID-Linux-KVM-${driver.vgpuVersion}-${driver.gridVersion}-${driver.guestVersion}.zip";
  requireFile = {name, ...} @ args:
    pkgs.requireFile (rec {
        inherit name;
        url = "https://www.nvidia.com/object/vGPU-software-driver.html";
        message = ''
          Unfortunately, we cannot download file ${name} automatically.
          This file can be extracted from ${combinedZipName}.
          Please go to ${url} to download it yourself, and add it to the Nix store
          using either
            nix-store --add-fixed sha256 ${name}
          or
            nix-prefetch-url --type sha256 file:///path/to/${name}
        '';
      }
      // args);

  nvidia-vgpu-kvm-src =
    pkgs.runCommand "nvidia-${driver.vgpuVersion}-vgpu-kvm-src" {
      src = requireFile {
        name = "NVIDIA-Linux-x86_64-${driver.vgpuVersion}-vgpu-kvm.run";
        sha256 = driver.vgpuSha;
      };
    } ''
      mkdir $out
      cd $out

      # From unpackManually() in builder.sh of nvidia-x11 from nixpkgs
      skip=$(sed 's/^skip=//; t; d' $src)
      tail -n +$skip $src | ${pkgs.libarchive}/bin/bsdtar xvf -
    '';

  vgpu_unlock-rs = pkgs.callPackage ./vgpu_unlock-rs {};

  vgpu_unlock = pkgs.stdenv.mkDerivation {
    name = "nvidia-vgpu-unlock";
    version = "unstable-2024-04-19";

    src = pkgs.fetchFromGitHub {
      owner = "DualCoder";
      repo = "vgpu_unlock";
      rev = "f432ffc8b7ed245df8858e9b38000d3b8f0352f4";
      sha256 = "sha256-o+8j82Ts8/tEREqpNbA5W329JXnwxfPNJoneNE8qcsU=";
    };

    buildInputs = [(pythonPackages.python.withPackages (p: [p.frida-python]))];

    postPatch = ''
      substituteInPlace vgpu_unlock \
        --replace-fail /bin/bash ${pkgs.bash}/bin/bash
    '';

    installPhase = "install -Dm755 vgpu_unlock $out/bin/vgpu_unlock";
  };
in {
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";

      unlock.enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Unlock vGPU functionality for consumer grade GPUs";
      };

      version = mkOption {
        type = types.str;
        default = "v17.1";
        description = "version";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
      {
        patches ? [],
        postUnpack ? "",
        postPatch ? "",
        preFixup ? "",
        ...
      } @ attrs: {
        name = "nvidia-x11-${driver.vgpuVersion}-${driver.gridVersion}-${config.boot.kernelPackages.kernel.version}";
        version = "${driver.vgpuVersion}";

        src = requireFile {
          name = "NVIDIA-Linux-x86_64-${driver.gridVersion}-grid.run";
          sha256 = driver.gridSha;
        };

        NV_KVM_MIGRATION_UAPI = 1;

        patches =
          patches ++ ["${gpuPatches}/${driver.vgpuVersion}.patch"];
        # ++ [
        #   ./nvidia-vgpu-merge.patch
        # ]
        # ++ lib.optional cfg.unlock.enable
        # (pkgs.substituteAll {
        #   src = ./nvidia-vgpu-unlock.patch;
        #   vgpu_unlock = vgpu_unlock.src;
        # });

        postUnpack = ''
          ${postUnpack}


          # More merging, besides patch above

          echo "${nvidia-vgpu-kvm-src}"

          cp -r ${nvidia-vgpu-kvm-src}/init-scripts $sourceRoot

          mkdir -p $sourceRoot/kernel/common/inc
          mkdir -p $sourceRoot/kernel/nvidia

          cp ${nvidia-vgpu-kvm-src}/kernel/common/inc/nv-vgpu-vfio-interface.h $sourceRoot/kernel/common/inc/nv-vgpu-vfio-interface.h
          cp ${nvidia-vgpu-kvm-src}/kernel/nvidia/nv-vgpu-vfio-interface.c $sourceRoot/kernel/nvidia/nv-vgpu-vfio-interface.c
          echo "NVIDIA_SOURCES += nvidia/nv-vgpu-vfio-interface.c" >> $sourceRoot/kernel/nvidia/nvidia-sources.Kbuild
          cp -r ${nvidia-vgpu-kvm-src}/kernel/nvidia-vgpu-vfio $sourceRoot/kernel/nvidia-vgpu-vfio

          cp ${nvidia-vgpu-kvm-src}/libnvidia-vgpu.so.${driver.vgpuVersion} $sourceRoot
          cp ${nvidia-vgpu-kvm-src}/libnvidia-vgxcfg.so.${driver.vgpuVersion} $sourceRoot
          cp ${nvidia-vgpu-kvm-src}/nvidia-vgpu-mgr $sourceRoot
          cp ${nvidia-vgpu-kvm-src}/nvidia-vgpud $sourceRoot
          cp ${nvidia-vgpu-kvm-src}/vgpuConfig.xml $sourceRoot
          cp ${nvidia-vgpu-kvm-src}/sriov-manage $sourceRoot

          echo 'ldflags-y += -T ${vgpu_unlock.src}/kern.ld' >> $sourceRoot/kernel/nvidia/nvidia.Kbuild
          substituteInPlace $sourceRoot/kernel/nvidia/os-interface.c \
            --replace-fail "#include \"nv-time.h\"" $'#include "nv-time.h"\n#include "${vgpu_unlock.src}/vgpu_unlock_hooks.c"'

          chmod -R u+rw .
        '';

        postPatch = ''
          ${lib.optionalString (postPatch ? "") postPatch}

          # Move path for vgpuConfig.xml into /etc
          sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' ./nvidia-vgpud

          substituteInPlace ./sriov-manage \
            --replace-fail lspci ${pkgs.pciutils}/bin/lspci \
            --replace-fail setpci ${pkgs.pciutils}/bin/setpci
        '';

        # HACK: Using preFixup instead of postInstall since nvidia-x11 builder.sh doesn't support hooks
        preFixup = ''
          ${preFixup}
          for i in libnvidia-vgpu.so.${driver.vgpuVersion} libnvidia-vgxcfg.so.${driver.vgpuVersion}; do
            install -Dm755 "$i" "$out/lib/$i"
          done
          patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib $out/lib/libnvidia-vgpu.so.${driver.vgpuVersion}
          install -Dm644 vgpuConfig.xml $out/vgpuConfig.xml

          for i in nvidia-vgpud nvidia-vgpu-mgr; do
            install -Dm755 "$i" "$bin/bin/$i"
            # stdenv.cc.cc.lib is for libstdc++.so needed by nvidia-vgpud
            patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath $out/lib "$bin/bin/$i"
          done
          install -Dm755 sriov-manage $bin/bin/sriov-manage
        '';
      }
    );

    systemd.services.nvidia-vgpud = {
      description = "NVIDIA vGPU Daemon";
      wants = ["syslog.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${lib.optionalString cfg.unlock.enable "${vgpu_unlock}/bin/vgpu_unlock "}${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpud";
        Environment = ["__RM_NO_VERSION_CHECK=1"]; # Avoids issue with API version incompatibility when merging host/client drivers
      };
    };

    systemd.services.nvidia-vgpu-mgr = {
      description = "NVIDIA vGPU Manager Daemon";
      wants = ["syslog.target"];
      wantedBy = ["multi-user.target"];

      environment.LD_PRELOAD = "${vgpu_unlock-rs}/lib/libvgpu_unlock_rs.so";

      serviceConfig = {
        Type = "forking";
        KillMode = "process";
        ExecStart = "${lib.optionalString cfg.unlock.enable "${vgpu_unlock}/bin/vgpu_unlock "}${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
        Environment = ["__RM_NO_VERSION_CHECK=1"];
      };
    };

    environment.etc = {
      "nvidia-vgpu-xxxxx/vgpuConfig.xml".source = "${config.hardware.nvidia.package}/vgpuConfig.xml";
      "vgpu_unlock/profile_override.toml".text = ''
        unlock_migration = true

        [profile.nvidia-55]
        num_displays = 1
        display_width = 1920
        display_height = 1080
        max_pixels = 2073600
        cuda_enabled = 1
        frl_enabled = 0
      '';
    };
    boot = {
      kernelModules = [
        "nvidia-vgpu-vfio"

        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
        "vfio_virqfd"
      ];

      kernelParams = [
        "intel_iommu=on"
        "iommu=pt"
      ];

      blacklistedKernelModules = mkDefault ["nouveau"];
    };

    environment.systemPackages = [mdevctl];
    services.udev.packages = [mdevctl];
  };
}
