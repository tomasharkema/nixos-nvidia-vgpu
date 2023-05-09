{ pkgs, lib, config, ... }:

let
  
  cfg = config.hardware.nvidia.vgpu;

  nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
    inherit pkgs;
  };

  mdevctl = pkgs.callPackage ./mdevctl {};
  pythonPackages = pkgs.python38Packages;
  #frida = pythonPackages.callPackage ./frida {};

  #frida-nix = (builtins.getFlake "github:itstarsun/frida-nix"); # nix develop 'github:itstarsun/frida-nix#frida-tools'
  # frida-nix = (builtins.getFlake "github:itstarsun/frida-nix").devShells.x86_64-linux.default;
  frida = (builtins.getFlake "github:itstarsun/frida-nix").packages.x86_64-linux.frida-tools;
  #python-env = frida-nix.outputs.frida-tools
  my-python = (pythonPackages.python.withPackages (p: [ frida ]));

  #frida = nur.repos.genesis.frida-tools;

  # ============================================= #

  default-metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
  default-overlay = mkOverlay { };

/*
  tools-version = metadata.latest-tools;
  metadata = default-metadata;
  version = metadata.latest-release;

  frida = pythonPackages.callPackage ./frida-python {
    inherit version;
    src = pkgs.fetchurl metadata.releases.${version}.frida-python;
  };

  frida-tools = pythonPackages.callPackage ./frida-tools {
    version = tools-version;
    src = pkgs.fetchurl metadata.tools.${tools-version};
    inherit frida;
  }; */

  frida-lib = import ./frida-nix/.;

  flakeModule = ./flake-module.nix;

  templates.default = {
    path = ./templates/flake-parts;
    description = ''
      A template with flake-parts and frida-nix.
    '';
  };  

  overlays.default = frida-lib.default-overlay;

  frida-shit-pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { };

  pkgs-frida = frida-shit-pkgs.extend overlays.default;
  frida-tools = pkgs.python3Packages.frida-tools;


  mkOverlay =
    { metadata ? default-metadata
    , version ? metadata.latest-release
    , tools-version ? metadata.latest-tools
    }: (final: prev:
    let
      inherit (final) fetchurl;

      mkFridaDevkit = pname:
        final.callPackage ./frida-devkit {
          inherit pname version;
          src = fetchurl metadata.releases.${version}.per-system.${final.system}.${pname};
        };
    in
    {
      frida-core = mkFridaDevkit "frida-core";
      frida-gum = mkFridaDevkit "frida-gum";
      frida-gumjs = mkFridaDevkit "frida-gumjs";

      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (python-final: python-prev: {
          frida = python-final.callPackage ./frida-python {
            inherit version;
            src = fetchurl metadata.releases.${version}.frida-python;
          };

          frida-tools = python-final.callPackage ./frida-tools {
            version = tools-version;
            src = fetchurl metadata.tools.${tools-version};
          };
        })
      ];

    });


  # ============================================= #

  vgpuVersion = "460.32.04";
  gridVersion = "460.32.03";
  guestVersion = "461.33";

  myVgpuVersion = "525.105.14";

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

  nvidia-vgpu-kvm-src = pkgs.runCommand "nvidia-${vgpuVersion}-vgpu-kvm-src" {
    src = requireFile {
      name = "NVIDIA-Linux-x86_64-${vgpuVersion}-vgpu-kvm.run";
      sha256 = "00ay1f434dbls6p0kaawzc6ziwlp9dnkg114ipg9xx8xi4360zzl";
    };
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

    buildInputs = [ frida /*pkgs.python2 my-python*/ ];

    shellHook = ''
      echo ${frida}
    '';

    postPatch = ''
      echo ${frida}
      python --version
      ${pkgs.unixtools.util-linux}/bin/whereis python

      env | grep PYTHON
      python --version
      python -c "import frida" && echo "frida is installed" || echo "frida is not installed"
      
      
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

      # submodule
      fastapi-dls = lib.mkOption {
        description = "Set up fastapi-dls host server";
        type = with lib.types; submodule {
          options = {
            enable = lib.mkOption {
              default = false;
              type = lib.types.bool;
              description = "Set up fastapi-dls host server";
            };
            docker-directory = lib.mkOption {
              description = "Path to your folder with docker containers";
              default = /opt/docker;
              example = /dockers;
              type = lib.types.path;
            };
          };
        };
      };
      
    };
  };

  config = lib.mkMerge [

 (lib.mkIf cfg.enable {
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
      { patches ? [], postUnpack ? "", postPatch ? "", preFixup ? "", ... }@attrs: {
      # Overriding https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/os-specific/linux/nvidia-x11
      # that gets called from the option hardware.nvidia.package from here: https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/hardware/video/nvidia.nix
      name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched-${config.boot.kernelPackages.kernel.version}";
      version = "${vgpuVersion}";

      # the new driver
      src = pkgs.fetchurl {
              name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
              url = "https://drive.google.com/u/1/uc?id=17NN0zZcoj-uY2BELxY2YqGvf6KtZNXhG&export=download&confirm=t&uuid=e2729c36-3bb7-4be6-95b0-08e06eac55ce&at=AKKF8vzPeXmt0W_pxHE9rMqewfXY:1683158182055";
              sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
            };

      postPatch = postPatch + ''
        # Move path for vgpuConfig.xml into /etc
        sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

        substituteInPlace sriov-manage \
          --replace lspci ${pkgs.pciutils}/bin/lspci \
          --replace setpci ${pkgs.pciutils}/bin/setpci
      '';

      # HACK: Using preFixup instead of postInstall since nvidia-x11 builder.sh doesn't support hooks
      preFixup = preFixup + ''
        for i in libnvidia-vgpu.so.${myVgpuVersion} libnvidia-vgxcfg.so.${myVgpuVersion}; do
          install -Dm755 "$i" "$out/lib/$i"
        done
        patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib $out/lib/libnvidia-vgpu.so.${myVgpuVersion}
        install -Dm644 vgpuConfig.xml $out/vgpuConfig.xml

        for i in nvidia-vgpud nvidia-vgpu-mgr; do
          install -Dm755 "$i" "$bin/bin/$i"
          # stdenv.cc.cc.lib is for libstdc++.so needed by nvidia-vgpud
          patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath $out/lib "$bin/bin/$i"
        done
        install -Dm755 sriov-manage $bin/bin/sriov-manage
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
        Environment = [ "__RM_NO_VERSION_CHECK=1" "_PYTHON_HOST_PLATFORM=linux-x86_64" "PYTHONNOUSERSITE=1" "PYTHONHASHSEED=0" "_PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_x86_64-linux-gnu" "PYTHONPATH=/nix/store/sb4a338qh7wld75zbcgrylrpqmjnfh27-python3.10-frida-tools-12.1.1/lib/python3.10/site-packages:/nix/store/ndr7x7qhkssarrgjpqqnv8i9py4vyc9c-python3.10-colorama-0.4.6/lib/python3.10/site-packages:/nix/store/fdqpyj613dr0v1l1lrzqhzay7sk4xg87-python3-3.10.10/lib/python3.10/site-packages:/nix/store/lz6vq2kp7rww3jj6f7zgf4n50c3qvc83-python3.10-frida-16.0.18/lib/python3.10/site-packages:/nix/store/k7xyj5b5dw0cna25b91ygqskkwv8na4s-python3.10-typing-extensions-4.5.0/lib/python3.10/site-packages:/nix/store/pf9j3spzhbz7gvmbyk6a5kwcmi7zvpmy-python3.10-prompt-toolkit-3.0.38/lib/python3.10/site-packages:/nix/store/hix271phwzb157a2sj9fn5zfmkpz8zpd-python3.10-six-1.16.0/lib/python3.10/site-packages:/nix/store/khqw9ph04dvjy86rlzxzhyk21c2binhi-python3.10-wcwidth-0.2.6/lib/python3.10/site-packages:/nix/store/fpcah4a88pjj7jmwhrcvfb9kg6qj58vc-python3.10-setuptools-67.4.0/lib/python3.10/site-packages:/nix/store/asf94iynbzxraqzmbi2w69vj3khaphan-python3.10-pygments-2.14.0/lib/python3.10/site-packages:/nix/store/d8ghysrcn5nsyh9w3gvwg5kk1iyy510r-python3.10-docutils-0.19/lib/python3.10/site-packages" ]; # Avoids issue with API version incompatibility when merging host/client drivers
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
        Environment = [ "__RM_NO_VERSION_CHECK=1" "_PYTHON_HOST_PLATFORM=linux-x86_64" "PYTHONNOUSERSITE=1" "PYTHONHASHSEED=0" "_PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_x86_64-linux-gnu" "PYTHONPATH=/nix/store/sb4a338qh7wld75zbcgrylrpqmjnfh27-python3.10-frida-tools-12.1.1/lib/python3.10/site-packages:/nix/store/ndr7x7qhkssarrgjpqqnv8i9py4vyc9c-python3.10-colorama-0.4.6/lib/python3.10/site-packages:/nix/store/fdqpyj613dr0v1l1lrzqhzay7sk4xg87-python3-3.10.10/lib/python3.10/site-packages:/nix/store/lz6vq2kp7rww3jj6f7zgf4n50c3qvc83-python3.10-frida-16.0.18/lib/python3.10/site-packages:/nix/store/k7xyj5b5dw0cna25b91ygqskkwv8na4s-python3.10-typing-extensions-4.5.0/lib/python3.10/site-packages:/nix/store/pf9j3spzhbz7gvmbyk6a5kwcmi7zvpmy-python3.10-prompt-toolkit-3.0.38/lib/python3.10/site-packages:/nix/store/hix271phwzb157a2sj9fn5zfmkpz8zpd-python3.10-six-1.16.0/lib/python3.10/site-packages:/nix/store/khqw9ph04dvjy86rlzxzhyk21c2binhi-python3.10-wcwidth-0.2.6/lib/python3.10/site-packages:/nix/store/fpcah4a88pjj7jmwhrcvfb9kg6qj58vc-python3.10-setuptools-67.4.0/lib/python3.10/site-packages:/nix/store/asf94iynbzxraqzmbi2w69vj3khaphan-python3.10-pygments-2.14.0/lib/python3.10/site-packages:/nix/store/d8ghysrcn5nsyh9w3gvwg5kk1iyy510r-python3.10-docutils-0.19/lib/python3.10/site-packages"];
      };
    };

    environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

    boot.kernelModules = [ "nvidia-vgpu-vfio" ];

    environment.systemPackages = [ mdevctl];
    services.udev.packages = [ mdevctl ];

  })

    # fastapi-dls docker service
    /*
    sudo mkdir -p /opt/docker/fastapi-dls/cert

    WORKING_DIR=/opt/docker/fastapi-dls/cert
    mkdir -p $WORKING_DIR
    cd $WORKING_DIR
    # create instance private and public key for singing JWT's
    openssl genrsa -out $WORKING_DIR/instance.private.pem 2048 
    openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
    # create ssl certificate for integrated webserver (uvicorn) - because clients rely on ssl
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout  $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt
    */
    (lib.mkIf cfg.fastapi-dls.enable {
      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls:latest";
          volumes = [
            "${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert:/app/cert:rw"
            "dls-db:/app/database"
          ];
          # Set environment variables
          environment = {
            TZ = "Europe/Lisbon";
            DLS_URL = "192.168.1.81"; # this should grab your hostname, not your IP!
            DLS_PORT = "443";
            LEASE_EXPIRE_DAYS="90";
            DATABASE = "sqlite:////app/database/db.sqlite";
            DEBUG = "true";
          };
          extraOptions = [
          ];
          # Publish the container's port to the host
          ports = [ "443:443" ];
          # Automatically start the container
          autoStart = true;
        };
      };
    })

  ];
}
