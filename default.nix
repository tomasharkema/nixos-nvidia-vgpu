{ lib, config, types, pkgs, ... }:

# My post: https://discourse.nixos.org/t/vgpu-unlock-for-nixos-22-11-pin-version-of-nixos-hardware/27012

# pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/5bba55eb6e1c627dc1821c9132c5854e0870e2f1.tar.gz"){}
#hardware-pinned ? import (fetchTarball "https://github.com/NixOS/nixos-hardware/archive/7da029f26849f8696ac49652312c9171bf9eb170.tar.gz"){}

let
/*
  my_config = {
    inherit config; 
    pkgs = import (builtins.fetchGit {
         # Descriptive name to make the store path easier to identify                
         name = "nix_pkgs2";                                                 
         url = "https://github.com/NixOS/nixpkgs/";                       
         ref = "refs/heads/nixpkgs-unstable";                     
         rev = "fadaef5aedb6b35681248f8c6096083b2efeb284";                                           
     }) { inherit config; };
  };*/

  #pkgs = import (builtins.fetchGit {
  #       # Descriptive name to make the store path easier to identify                
  #       name = "nix_pkgs_with_singularity";                                                 
  #       url = "https://github.com/NixOS/nixpkgs/";                       
  #       ref = "refs/heads/nixpkgs-unstable";                     
  #       rev = "fadaef5aedb6b35681248f8c6096083b2efeb284";                                           
  #   }) { /*inherit (config) system; inherit config;*/ };

  cfg = config.hardware.nvidia.vgpu;

  #mdevctl = pkgs.callPackage ./mdevctl {};
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
      /*
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
      */
    };
  };

  config = lib.mkIf cfg.enable {

    /*
    # https://discourse.nixos.org/t/how-to-install-a-specific-version-of-a-package-from-my-configuration-nix/18057/20
    hardware.overlays = [
      (self: super: {
        nvidia = super.nvidia.overrideAttrs (
          _: { src = builtins.fetchTarball {
            url = "https://discord.com/api/download?platform=linux&format=tar.gz"; 
            sha256 = "sha256:12yrhlbigpy44rl3icir3jj2p5fqq2ywgbp5v3m1hxxmbawsm6wi";
          };}
        );
      })

      (final: prev: {
        nvidia = let
          nvidiapkgs = final.fetchFromGitHub {
            owner = "nixos";
            repo = "nixos-hardware";
            rev = "7da029f26849f8696ac49652312c9171bf9eb170";
            sha256 = "";
          };
          libupnp = final.callPackage "${amulepkgs}/pkgs/development/libraries/pupnp/default.nix" {
            stdenv = final.stdenv // { inherit lib; };
          };
        in
        final.callPackage "${amulepkgs}/pkgs/tools/networking/p2p/amule/default.nix" {
          inherit libupnp;
          cryptopp = final.cryptopp.dev;
        };
      })
    ];
    */

    #hardware-pinned = import (builtins.fetchTarball {
    #    url = "https://github.com/NixOS/nixos-hardware/archive/7da029f26849f8696ac49652312c9171bf9eb170.tar.gz";
    #}) {};                                                                   

    #myHardware = hardware-pinned;

    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_390.overrideAttrs (
      { patches ? [], postUnpack ? "", postPatch ? "", preFixup ? "", ... }@attrs: {
        # Overriding https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/os-specific/linux/nvidia-x11
        # that gets called from the option hardware.nvidia.package from here: https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/hardware/video/nvidia.nix
      name = "nvidia-x11-${vgpuVersion}-${gridVersion}-${config.boot.kernelPackages.kernel.version}";
      version = "${vgpuVersion}";

      
      
      src = pkgs.fetchurl {
              name = "NVIDIA-Linux-x86_64-460.73.01-grid-vgpu-kvm-v5.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
              url = "https://drive.google.com/u/0/uc?id=1dCyUteA2MqJaemRKqqTu5oed5mINu9Bw&export=download&confirm=t";
              sha256 = "sha256-C8KM8TwaTYhFx/iYeXTgS9UnNDIbuNtSbGk4UwrRLHE=";
            };
      
      

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

    environment.systemPackages = [ 
      pkgs.mdevctl 
    ];
    services.udev.packages = [ 
      pkgs.mdevctl 
    ];
  };
}
