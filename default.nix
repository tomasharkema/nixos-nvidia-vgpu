{ pkgs, lib, config, types, ... }:

let
  cfg = config.hardware.nvidia.vgpu;

  mdevctl = pkgs.callPackage ./mdevctl {};
  pythonPackages = pkgs.python38Packages;
  frida = pythonPackages.callPackage ./frida {};

  vgpuVersion = "460.73.01";
  gridVersion = "460.32.03";
  guestVersion = "461.33";

  combinedZipName = "NVIDIA-GRID-Linux-KVM-${vgpuVersion}-${gridVersion}-${guestVersion}.zip";
  
  requireFile = { name, ... }@args: pkgs.requireFile (rec {
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
  } // args);

  nvidia-vgpu-kvm-src = 
  pkgs.runCommand "nvidia-${vgpuVersion}-vgpu-kvm-src" {
    
    # https://github.com/NixOS/nix/issues/1528
    src = let
      srcPath = 
        if cfg.vgpuKvmDriver != null then
          cfg.vgpuKvmDriver
        else
          throw "No 'vgpuKvmDriver' option provided with path to driver";

      derivationName = baseNameOf srcPath;
      storePath = "/nix/store/zzy4bnrd0zzwha1lhbpvsgzqz43n5xic-${derivationName}"; # this should be ${storeHash}
    in
      if builtins.pathExists storePath then
              storePath 
            else
              srcPath;
              
  } ''
    mkdir $out
    cd $out

    # From unpackManually() in builder.sh of nvidia-x11 from nixpkgs
    skip=$(sed 's/^skip=//; t; d' $src)
    tail -n +$skip $src | ${pkgs.libarchive}/bin/bsdtar xvf -
    sourceRoot=.
  '';

  vgpu_unlock = pkgs.stdenv.mkDerivation {
    name = "nvidia-vgpu-unlock";
    version = "unstable-2021-04-22";

    src = pkgs.fetchFromGitHub {
      owner = "DualCoder";
      repo = "vgpu_unlock";
      rev = "1888236c75d8eac673695be8b000f0b065111c51";
      sha256 = "0s8bmscb8irj1sggfg1fhacqd1lh59l326bnrk4a2g4qngsbkix3";
    };

    buildInputs = [ (pythonPackages.python.withPackages (p: [ frida ])) ];

    postPatch = ''
      substituteInPlace vgpu_unlock \
        --replace /bin/bash ${pkgs.bash}/bin/bash
    '';

    installPhase = "install -Dm755 vgpu_unlock $out/bin/vgpu_unlock";
  };

in
{

  
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";

      unlock.enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Unlock vGPU functionality for consumer grade GPUs";
      };
      vgpuKvmDriver = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = lib.mdDoc "NVIDIA-Linux-x86_64-${vgpuVersion}-vgpu-kvm.run";
      };

      gridDriver = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = lib.mdDoc "NVIDIA-Linux-x86_64-${gridVersion}-grid.run";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
      { patches ? [], postUnpack ? "", postPatch ? "", preFixup ? "", ... }@attrs: {
        # Overriding https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/os-specific/linux/nvidia-x11
        # that gets called from the option hardware.nvidia.package from here: https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/hardware/video/nvidia.nix
      name = "nvidia-x11-${vgpuVersion}-${gridVersion}-${config.boot.kernelPackages.kernel.version}";
      version = "${vgpuVersion}";

      # https://github.com/NixOS/nix/issues/1528
      src = let 
        srcPath = 
          if cfg.vgpuKvmDriver != null then
            cfg.vgpuKvmDriver
          else
            throw "No 'gridDriver' option provided with path to driver";

        derivationName = baseNameOf srcPath;
        storePath = "/nix/store/zzy4bnrd0zzwsjalhbpvsgzqz43n5xic-${derivationName}"; # this should be ${storeHash}
      in
        if builtins.pathExists storePath then
                storePath 
              else
                srcPath;

      #src = pkgs.requireFile {
      #  name = "NVIDIA-Linux-x86_64-${gridVersion}-grid.run";
      #  path = "${config.gridDriver}";
        #sha256 = "0smvmxalxv7v12m0hvd5nx16jmcc7018s8kac3ycmxam8l0k9mw9";
      #};

      #patches = patches ++ [
      #  ./nvidia-vgpu-merge.patch
      #] ++ lib.optional cfg.unlock.enable
      #  (pkgs.substituteAll {
      #    src = ./nvidia-vgpu-unlock.patch;
      #    vgpu_unlock = vgpu_unlock.src;
      #  });

      postUnpack = postUnpack + ''
        # More merging, besides patch above

        #${pkgs.tree}/bin/tree "${nvidia-vgpu-kvm-src}/"
        #echo "${nvidia-vgpu-kvm-src}"

        #shopt -s dotglob
        #mv -f ./NVIDIA-Linux-x86_64-${vgpuVersion}-vgpu-kvm/* ./
        #rm -r ./NVIDIA-Linux-x86_64-${vgpuVersion}-vgpu-kvm

        #ls
        #cd ./NVIDIA-Linux-x86_64-${vgpuVersion}-vgpu-kvm/
        cd $(find . -maxdepth 1 -type d -iname "*NVIDIA*" -print -quit) # cd into directory with word NVIDIA in it

        cp -r ${nvidia-vgpu-kvm-src}/init-scripts .
        cp ${nvidia-vgpu-kvm-src}/kernel/common/inc/nv-vgpu-vfio-interface.h kernel/common/inc//nv-vgpu-vfio-interface.h
        cp ${nvidia-vgpu-kvm-src}/kernel/nvidia/nv-vgpu-vfio-interface.c kernel/nvidia/nv-vgpu-vfio-interface.c
        echo "NVIDIA_SOURCES += nvidia/nv-vgpu-vfio-interface.c" >> kernel/nvidia/nvidia-sources.Kbuild
        cp -r ${nvidia-vgpu-kvm-src}/kernel/nvidia-vgpu-vfio kernel/nvidia-vgpu-vfio

        echo 1

        for i in $(find . -maxdepth 1 \( -name "libnvidia-vgpu.so.*" -o -name "libnvidia-vgxcfg.so.*" -o -name "nvidia-vgpu-mgr" -o -name "nvidia-vgpud" -o -name "vgpuConfig.xml" -o -name "sriov-manage" \)); do

          #${pkgs.tree}/bin/tree
          echo $i
          pwd

          cp ${nvidia-vgpu-kvm-src}/$i $i
          echo 3
        done

        chmod -R u+rw .
        
        cd ..
      '';

      postPatch = postPatch + ''
        # Move path for vgpuConfig.xml into /etc
        sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

        substituteInPlace sriov-manage \
          --replace lspci ${pkgs.pciutils}/bin/lspci \
          --replace setpci ${pkgs.pciutils}/bin/setpci
      '';

      # HACK: Using preFixup instead of postInstall since nvidia-x11 builder.sh doesn't support hooks
      preFixup = preFixup + ''
        for i in $(find . -maxdepth 1 \( -name "libnvidia-vgpu.so.*" -o -name "libnvidia-vgxcfg.so.*"\)); do
          install -Dm755 "$i" "$out/lib/$i"
        done

        for file in $(find . -maxdepth 1 \( -name "libnvidia-vgpu.so.*" \)); do
          patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib $file
        done
        
        install -Dm644 vgpuConfig.xml $out/vgpuConfig.xml

        for i in nvidia-vgpud nvidia-vgpu-mgr; do
          install -Dm755 "$i" "$bin/bin/$i"
          # stdenv.cc.cc.lib is for libstdc++.so needed by nvidia-vgpud
          patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath $out/lib "$bin/bin/$i"
        done
        install -Dm755 sriov-manage $bin/bin/sriov-manage
      '';

    #firmware = null;

      installPhase = ''
    # Install libGL and friends.

    echo $SHELL

    bash
    echo $SHELL
    ${pkgs.tree}/bin/tree


    # since version 391, 32bit libraries are bundled in the 32/ sub-directory
    if [ "$i686bundled" = "1" ]; then
        echo 1
        mkdir -p "$lib32/lib"
        cp -prd 32/*.so.* "$lib32/lib/"
        if [ -d 32/tls ]; then
            cp -prd 32/tls "$lib32/lib/"
        fi
    fi

    echo 2
    mkdir -p "$out/lib"
    cp -prd *.so.* "$out/lib/"
    if [ -d tls ]; then
        cp -prd tls "$out/lib/"
    fi

    echo 3
    # Install systemd power management executables
    #if [ -e systemd/nvidia-sleep.sh ]; then
    #    mv systemd/nvidia-sleep.sh ./
    #fi
    #if [ -e nvidia-sleep.sh ]; then
    #    sed -E 's#(PATH=).*#\1"$PATH"#' nvidia-sleep.sh > nvidia-sleep.sh.fixed
    #    install -Dm755 nvidia-sleep.sh.fixed $out/bin/nvidia-sleep.sh
    #fi

    #if [ -e systemd/system-sleep/nvidia ]; then
    #    mv systemd/system-sleep/nvidia ./
    #fi
    #if [ -e nvidia ]; then
    #    sed -E "s#/usr(/bin/nvidia-sleep.sh)#$out\\1#" nvidia > nvidia.fixed
    #    install -Dm755 nvidia.fixed $out/lib/systemd/system-sleep/nvidia
    #fi

    for i in $lib32 $out; do
        rm -f $i/lib/lib{glx,nvidia-wfb}.so.* # handled separately
        rm -f $i/lib/libnvidia-gtk* # built from source
        if [ "$useGLVND" = "1" ]; then
            # Pre-built libglvnd
            rm $i/lib/lib{GL,GLX,EGL,GLESv1_CM,GLESv2,OpenGL,GLdispatch}.so.*
        fi
        # Use ocl-icd instead
        rm -f $i/lib/libOpenCL.so*
        # Move VDPAU libraries to their place
        mkdir $i/lib/vdpau
        mv $i/lib/libvdpau* $i/lib/vdpau

        # Install ICDs, make absolute paths.
        # Be careful not to modify any original files because this runs twice.

        echo 3

        # OpenCL
        sed -E "s#(libnvidia-opencl)#$i/lib/\\1#" nvidia.icd > nvidia.icd.fixed
        install -Dm644 nvidia.icd.fixed $i/etc/OpenCL/vendors/nvidia.icd

        echo 4

        # Vulkan
        if [ -e nvidia_icd.json.template ] || [ -e nvidia_icd.json ]; then
            if [ -e nvidia_icd.json.template ]; then
                # template patching for version < 435
                sed "s#__NV_VK_ICD__#$i/lib/libGLX_nvidia.so#" nvidia_icd.json.template > nvidia_icd.json.fixed
            else
                sed -E "s#(libGLX_nvidia)#$i/lib/\\1#" nvidia_icd.json > nvidia_icd.json.fixed
            fi

            echo 5

            # nvidia currently only supports x86_64 and i686
            if [ "$i" == "$lib32" ]; then
                install -Dm644 nvidia_icd.json.fixed $i/share/vulkan/icd.d/nvidia_icd.i686.json
            else
                install -Dm644 nvidia_icd.json.fixed $i/share/vulkan/icd.d/nvidia_icd.x86_64.json
            fi
        fi

        echo 6

        if [ -e nvidia_layers.json ]; then
            sed -E "s#(libGLX_nvidia)#$i/lib/\\1#" nvidia_layers.json > nvidia_layers.json.fixed
            install -Dm644 nvidia_layers.json.fixed $i/share/vulkan/implicit_layer.d/nvidia_layers.json
        fi

        # EGL
        if [ "$useGLVND" = "1" ]; then
            sed -E "s#(libEGL_nvidia)#$i/lib/\\1#" 10_nvidia.json > 10_nvidia.json.fixed
            sed -E "s#(libnvidia-egl-wayland)#$i/lib/\\1#" 10_nvidia_wayland.json > 10_nvidia_wayland.json.fixed

            echo 7

            install -Dm644 10_nvidia.json.fixed $i/share/glvnd/egl_vendor.d/10_nvidia.json
            install -Dm644 10_nvidia_wayland.json.fixed $i/share/egl/egl_external_platform.d/10_nvidia_wayland.json

            echo 8

            if [[ -f "15_nvidia_gbm.json" ]]; then
              sed -E "s#(libnvidia-egl-gbm)#$i/lib/\\1#" 15_nvidia_gbm.json > 15_nvidia_gbm.json.fixed
              install -Dm644 15_nvidia_gbm.json.fixed $i/share/egl/egl_external_platform.d/15_nvidia_gbm.json

              mkdir -p $i/lib/gbm
              ln -s $i/lib/libnvidia-allocator.so $i/lib/gbm/nvidia-drm_gbm.so
            fi
        fi

        echo 9

        # Install libraries needed by Proton to support DLSS
        if [ -e nvngx.dll ] && [ -e _nvngx.dll ]; then
            install -Dm644 -t $i/lib/nvidia/wine/ nvngx.dll _nvngx.dll
        fi
    done

    if [ -n "$bin" ]; then
        # Install the X drivers.
        mkdir -p $bin/lib/xorg/modules
        if [ -f libnvidia-wfb.so ]; then
            cp -p libnvidia-wfb.* $bin/lib/xorg/modules/
        fi
        mkdir -p $bin/lib/xorg/modules/drivers
        cp -p nvidia_drv.so $bin/lib/xorg/modules/drivers
        mkdir -p $bin/lib/xorg/modules/extensions
        cp -p libglx*.so* $bin/lib/xorg/modules/extensions

        echo 10

        # Install the kernel module.
        mkdir -p $bin/lib/modules/$kernelVersion/misc
        for i in $(find ./kernel -name '*.ko'); do
            nuke-refs $i
            cp $i $bin/lib/modules/$kernelVersion/misc/
        done

        # Install application profiles.
        if [ "$useProfiles" = "1" ]; then
            mkdir -p $bin/share/nvidia
            cp nvidia-application-profiles-*-rc $bin/share/nvidia/nvidia-application-profiles-rc
            cp nvidia-application-profiles-*-key-documentation $bin/share/nvidia/nvidia-application-profiles-key-documentation
        fi
    fi

    echo 11

    echo $firmware/lib/firmware/nvidia/
    echo $version
    #ls $firmware/lib/firmware/nvidia/

    #if [ -n "$firmware" ]; then
    #    # Install the GSP firmware
    #    install -Dm644 -t $firmware/lib/firmware/nvidia/$version firmware/gsp*.bin
    #fi

    # All libs except GUI-only are installed now, so fixup them.
    for libname in $(find "$out/lib/" $(test -n "$lib32" && echo "$lib32/lib/") $(test -n "$bin" && echo "$bin/lib/") -name '*.so.*')
    do
      # I'm lazy to differentiate needed libs per-library, as the closure is the same.
      # Unfortunately --shrink-rpath would strip too much.
      if [[ -n $lib32 && $libname == "$lib32/lib/"* ]]; then
        patchelf --set-rpath "$lib32/lib:$libPath32" "$libname"
      else
        patchelf --set-rpath "$out/lib:$libPath" "$libname"
      fi

      libname_short=`echo -n "$libname" | sed 's/so\..*/so/'`

      if [[ "$libname" != "$libname_short" ]]; then
        ln -srnf "$libname" "$libname_short"
      fi

      if [[ $libname_short =~ libEGL.so || $libname_short =~ libEGL_nvidia.so || $libname_short =~ libGLX.so || $libname_short =~ libGLX_nvidia.so ]]; then
          major=0
      else
          major=1
      fi

      if [[ "$libname" != "$libname_short.$major" ]]; then
        ln -srnf "$libname" "$libname_short.$major"
      fi
    done

    echo 12

    if [ -n "$bin" ]; then
        # Install /share files.
        mkdir -p $bin/share/man/man1
        cp -p *.1.gz $bin/share/man/man1
        rm -f $bin/share/man/man1/{nvidia-xconfig,nvidia-settings,nvidia-persistenced}.1.gz

        echo 13

        # Install the programs.
        for i in nvidia-cuda-mps-control nvidia-cuda-mps-server nvidia-smi nvidia-debugdump; do
            if [ -e "$i" ]; then
                install -Dm755 $i $bin/bin/$i
                # unmodified binary backup for mounting in containers
                install -Dm755 $i $bin/origBin/$i
                patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                    --set-rpath $out/lib:$libPath $bin/bin/$i
            fi
        done
        # FIXME: needs PATH and other fixes
        # install -Dm755 nvidia-bug-report.sh $bin/bin/nvidia-bug-report.sh
    fi  

    echo 14
'';

    });

    systemd.services.nvidia-vgpud = {
      description = "NVIDIA vGPU Daemon";
      wants = [ "syslog.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${lib.optionalString cfg.unlock.enable "${vgpu_unlock}/bin/vgpu_unlock "}${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpud";
        Environment = [ "__RM_NO_VERSION_CHECK=1" ]; # Avoids issue with API version incompatibility when merging host/client drivers
      };
    };

    systemd.services.nvidia-vgpu-mgr = {
      description = "NVIDIA vGPU Manager Daemon";
      wants = [ "syslog.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "forking";
        KillMode = "process";
        ExecStart = "${lib.optionalString cfg.unlock.enable "${vgpu_unlock}/bin/vgpu_unlock "}${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
        Environment = [ "__RM_NO_VERSION_CHECK=1" ];
      };
    };

    environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

    boot.kernelModules = [ "nvidia-vgpu-vfio" ];

    environment.systemPackages = [ mdevctl ];
    services.udev.packages = [ mdevctl ];
  };
}
