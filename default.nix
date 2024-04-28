inputs: { pkgs, lib, config, ... }:

let
  driver-version = "535.129.03";
  #driver-version = "525.105.14";
  # grid driver and wdys driver aren't actually used, but their versions are needed to find some filenames
  vgpu-driver-version = "535.129.03";
  #vgpu-driver-version = "525.105.14";
  grid-driver-version = "535.129.03";
  wdys-driver-version = "537.70";
  grid-version = "16.2";
  kernel-at-least-6 = if lib.strings.versionAtLeast config.boot.kernelPackages.kernel.version "6.0" then "true" else "false";
in
let
  # Using the pinned packages because these two problems arrose in the latest packages:
  # version `GLIBC_2.38' not found when trying to run the VM in nvidia-vgpu-mgr.service, maybe related to https://github.com/NixOS/nixpkgs/issues/287764
  # boot.kernelPackages = patched_pkgs.linuxPackages_5_15 gave this error: https://discourse.nixos.org/t/cant-update-nvidia-driver-on-stable-branch/39246

  inherit (pkgs.stdenv.hostPlatform) system;
  patchedPkgs = import (fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/468a37e6ba01c45c91460580f345d48ecdb5a4db.tar.gz";
        # url = "https://github.com/NixOS/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz";
        sha256 = "sha256:11ri51840scvy9531rbz32241l7l81sa830s90wpzvv86v276aqs";
    }) {
    inherit system;
    config.allowUnfree = true;
  };
  cfg = config.hardware.nvidia.vgpu;
  mdevctl = patchedPkgs.callPackage ./mdevctl {};
  #frida = (builtins.getFlake "github:Yeshey/frida-nix").packages.${system}.frida-tools; # if not using a flake, you can use this with --impure
  frida = inputs.frida.packages.${system}.frida-tools;
    
  compiled-driver = pkgs.stdenv.mkDerivation rec {
    name = "driver-compile";
      nativeBuildInputs = [ pkgs.p7zip pkgs.unzip pkgs.coreutils pkgs.bash pkgs.zstd];
        system = "x86_64-linux";
        src = pkgs.fetchFromGitHub {
          owner = "letmeiiiin";
          repo = "vGPU-Unlock-patcher";
          # 535.129
          rev = "9a8100c71c4bf97f4e0658d2824d18def0ac846d";
          hash = "sha256-rYb1+inH9NmFoBGJQQJQQRjPujrjC3owaSRCOOC/t3U=";
          fetchSubmodules = true;
          deepClone = true;
        };
        original_driver_src = pkgs.fetchurl {
          url = "https://download.nvidia.com/XFree86/Linux-x86_64/${driver-version}/NVIDIA-Linux-x86_64-${driver-version}.run";
          sha256 = "e6dca5626a2608c6bb2a046cfcb7c1af338b9e961a7dd90ac09bb8a126ff002e";
        };
        vgpu_driver_src = pkgs.fetchurl {
          url = "https://github.com/justin-himself/NVIDIA-VGPU-Driver-Archive/releases/download/${grid-version}/NVIDIA-GRID-Linux-KVM-${driver-version}-${wdys-driver-version}.zip";
          sha256 = "b458037fb652219464bc898efbd62096b2e298624c67f7f3db9823513d137c3a";
        };
        buildPhase = ''
          mkdir -p $out
          cd $TMPDIR
          #ln -s $original_driver_src NVIDIA-Linux-x86_64-${driver-version}.run
          ln -s $vgpu_driver_src NVIDIA-GRID-Linux-KVM-${driver-version}-${wdys-driver-version}.zip
          
          ${pkgs.unzip}/bin/unzip -j NVIDIA-GRID-Linux-KVM-${driver-version}-${wdys-driver-version}.zip Host_Drivers/NVIDIA-Linux-x86_64-${driver-version}-vgpu-kvm.run
          cp -a $src/* .
          cp -a $original_driver_src NVIDIA-Linux-x86_64-${driver-version}.run
          
          bash ./patch.sh --repack --lk6-patches general-merge 
          cp -a NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched.run $out
        '';
  };

  vgpu_unlock = patchedPkgs.python310Packages.buildPythonPackage {
    pname = "nvidia-vgpu-unlock";
    version = "unstable-2021-04-22";

    src = patchedPkgs.fetchFromGitHub {
      owner = "Yeshey";
      repo = "vgpu_unlock";
      rev = "7db331d4a2289ff6c1fb4da50cf445d9b4227421";
      sha256 = "sha256-K7e/9q7DmXrrIFu4gsTv667bEOxRn6nTJYozP1+RGHs=";
    };

    propagatedBuildInputs = [ frida ];
    
    doCheck = false; # Disable running checks during the build
    
    installPhase = ''
      mkdir -p $out/bin
      cp vgpu_unlock $out/bin/
      substituteInPlace $out/bin/vgpu_unlock \
              --replace /bin/bash ${patchedPkgs.bash}/bin/bash
    '';
  };
in
{
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";

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
              default = "/opt/docker";
              example = "/dockers";
              type = lib.types.str;
            };
            local_ipv4 = lib.mkOption {
              description = "Your ipv4 or local hostname, needed for the fastapi-dls server. Leave blank to autodetect using hostname";
              default = "";
              example = "192.168.1.81";
              type = lib.types.str;
            };
            timezone = lib.mkOption {
              description = "Your timezone according to this list: https://docs.diladele.com/docker/timezones.html, needs to be the same as in the VM. Leave blank to autodetect";
              default = "";
              example = "Europe/Lisbon";
              type = lib.types.str;
            };
          };
        };
        default = {};
      };
      
    };
  };

  config = lib.mkMerge [

 ( let
 
    patched_pkgs = import (fetchTarball {
        url = "github:nixos/nixpkgs/468a37e6ba01c45c91460580f345d48ecdb5a4db";
        sha256 = "sha256:11ri51840scvy9531rbz32241l7l81sa830s90wpzvv86v276aqs";
    }) {
    config.allowUnfree = true;
  };

 in lib.mkIf cfg.enable {

    boot.kernelPackages = patchedPkgs.linuxPackages_5_15; # needed for this linuxPackages_5_19
  
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs ( # CHANGE stable to legacy_470 to pin the version of the driver if it stops working
      { patches ? [], postUnpack ? "", postPatch ? "", preFixup ? "", ... }@attrs: {
      # Overriding https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/os-specific/linux/nvidia-x11
      # that gets called from the option hardware.nvidia.package from here: https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/hardware/video/nvidia.nix
      name = "NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched-${config.boot.kernelPackages.kernel.version}";
      version = "${driver-version}";

      # the new driver (getting from my Google drive)
      # the new driver (compiled in a derivation above)
      src = "${compiled-driver}/NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched.run";
      # src = patchedPkgs.fetchurl {
      #         name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
      #         url = "https://drive.usercontent.google.com/download?id=17NN0zZcoj-uY2BELxY2YqGvf6KtZNXhG&export=download&authuser=0&confirm=t&uuid=b70e0e36-34df-4fde-a86b-4d41d21ce483&at=APZUnTUfGnSmFiqhIsCNKQjPLEk3%3A1714043345939";
      #         sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
      #       };

      postPatch = if postPatch != null then postPatch + ''
        # Move path for vgpuConfig.xml into /etc
        sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

        substituteInPlace sriov-manage \
          --replace lspci ${patchedPkgs.pciutils}/bin/lspci \
          --replace setpci ${patchedPkgs.pciutils}/bin/setpci
      '' else ''
        # Move path for vgpuConfig.xml into /etc
        sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

        substituteInPlace sriov-manage \
          --replace lspci ${patchedPkgs.pciutils}/bin/lspci \
          --replace setpci ${patchedPkgs.pciutils}/bin/setpci
      '';

      /*
      postPatch = postPatch + ''
        # Move path for vgpuConfig.xml into /etc
        sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

        substituteInPlace sriov-manage \
          --replace lspci ${pkgs.pciutils}/bin/lspci \
          --replace setpci ${pkgs.pciutils}/bin/setpci
      ''; */

      # HACK: Using preFixup instead of postInstall since nvidia-x11 builder.sh doesn't support hooks
      preFixup = preFixup + ''
        for i in libnvidia-vgpu.so.${vgpu-driver-version} libnvidia-vgxcfg.so.${vgpu-driver-version}; do
          install -Dm755 "$i" "$out/lib/$i"
        done
        patchelf --set-rpath ${patchedPkgs.stdenv.cc.cc.lib}/lib $out/lib/libnvidia-vgpu.so.${vgpu-driver-version}
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
        ExecStart = "${vgpu_unlock}/bin/vgpu_unlock ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
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
        ExecStart = "${vgpu_unlock}/bin/vgpu_unlock ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
        Environment = [ "__RM_NO_VERSION_CHECK=1"];
      };
    };
    
    boot.extraModprobeConfig = 
      ''
      options nvidia vup_sunlock=1 vup_swrlwar=1 vup_qmode=1
      ''; # (for driver 535) bypasses `error: vmiop_log: NVOS status 0x1` in nvidia-vgpu-mgr.service when starting VM

    environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

    boot.kernelModules = [ "nvidia-vgpu-vfio" ];

    environment.systemPackages = [ mdevctl];
    services.udev.packages = [ mdevctl ];

  })

    (lib.mkIf cfg.fastapi-dls.enable {
    
      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls";
          imageFile = patchedPkgs.dockerTools.pullImage {
            imageName = "collinwebdesigns/fastapi-dls";
            imageDigest = "sha256:6fa90ce552c4e9ecff9502604a4fd42b3e67f52215eb6d8de03a5c3d20cd03d1";
            sha256 = "1y642miaqaxxz3z8zkknk0xlvzxcbi7q7ylilnxhxfcfr7x7kfqa";
          };
          volumes = [
            "${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert:/app/cert:rw"
            "dls-db:/app/database"
          ];
          # Set environment variables
          environment = {
            TZ = if cfg.fastapi-dls.timezone == "" then config.time.timeZone else "${cfg.fastapi-dls.timezone}";
            DLS_URL = if cfg.fastapi-dls.local_ipv4 == "" then config.networking.hostName else "${cfg.fastapi-dls.local_ipv4}";
            DLS_PORT = "443";
            LEASE_EXPIRE_DAYS="90";
            DATABASE = "sqlite:////app/database/db.sqlite";
            DEBUG = "true";
          };
          extraOptions = [
          ];
          # Publish the container's port to the host
          ports = [ "443:443" ];
          # Do not automatically start the container, it will be managed
          autoStart = false;
        };
      };

      systemd.timers.fastapi-dls-mgr = {
        wantedBy = [ "multi-user.target" ];
        timerConfig = {
          OnActiveSec = "1s";
          OnUnitActiveSec = "1h";
          AccuracySec = "1s";
          Unit = "fastapi-dls-mgr.service";
        };
      };

      systemd.services.fastapi-dls-mgr = {
        path = [ patchedPkgs.openssl ];
        script = ''
        WORKING_DIR=${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert
        CERT_CHANGED=false
        recreate_private () {
          rm -f $WORKING_DIR/instance.private.pem
          openssl genrsa -out $WORKING_DIR/instance.private.pem 2048
        }
        recreate_public () {
          rm -f $WORKING_DIR/instance.public.pem
          openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
        }
        recreate_certs () {
          rm -f $WORKING_DIR/webserver.key
          rm -f $WORKING_DIR/webserver.crt 
          openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
        }
        check_recreate() {
          if [ ! -e $WORKING_DIR/instance.private.pem ]; then
            recreate_private
            recreate_public
            recreate_certs
            CERT_CHANGED=true
          fi
          if [ ! -e $WORKING_DIR/instance.public.pem ]; then
            recreate_public
            recreate_certs
            CERT_CHANGED=true
          fi 
          if [ ! -e $WORKING_DIR/webserver.key ] || [ ! -e $WORKING_DIR/webserver.crt ]; then
            recreate_certs
            CERT_CHANGED=true
          fi
          if ( ! openssl x509 -checkend 864000 -noout -in $WORKING_DIR/webserver.crt); then
            recreate_certs
            CERT_CHANGED=true
          fi
        }
        if [ ! -d $WORKING_DIR ]; then
          mkdir -p $WORKING_DIR
        fi
        check_recreate
        if ( ! systemctl is-active --quiet docker-fastapi-dls.service ); then
          systemctl start podman-fastapi-dls.service
        elif $CERT_CHANGED; then
          systemctl stop podman-fastapi-dls.service
          systemctl start podman-fastapi-dls.service
        fi
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    })
  ];
}