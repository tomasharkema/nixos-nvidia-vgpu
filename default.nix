{ pkgs, lib, config, buildPythonPackage, ... }:

let
  
  # UNCOMMENT this to pin the version of pkgs if this stops working
  #pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz") {
  #    # config.allowUnfree = true;
  #};

  cfg = config.hardware.nvidia.vgpu;

  mdevctl = pkgs.callPackage ./mdevctl {};
  #pythonPackages = pkgs.python38Packages;
  #frida = pythonPackages.callPackage ./frida {};
  #frida-nix = (builtins.getFlake "github:itstarsun/frida-nix"); # nix develop 'github:itstarsun/frida-nix#frida-tools'
  # frida-nix = (builtins.getFlake "github:itstarsun/frida-nix").devShells.x86_64-linux.default;
  frida = (builtins.getFlake "github:itstarsun/frida-nix").packages.x86_64-linux.frida-tools;
  #frida-py = (builtins.getFlake "github:itstarsun/frida-nix").packages.x86_64-linux.frida-python;

  python-with-my-packages = pkgs.python3.withPackages (p: with p; [
    frida
    # pandas
    # beautifulsoup4
    # requests
    # lxml
    # pillow
    # other python packages you want
  ]);

  #python-env = frida-nix.outputs.frida-tools

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

  /*
  mach-nix = import (builtins.fetchGit {
    url = "https://github.com/DavHau/mach-nix";
    ref = "refs/tags/3.5.0";
  }) {};
  fastapi-dls = mach-nix.buildPythonPackage {

    pname = "fastapi-dls";
    version = "1.3.5";

#    src = "https://git.collinwebdesigns.de/oscar.krause/fastapi-dls/-/archive/1.3.5/fastapi-dls-1.3.5.tar.gz";
    src = builtins.fetchGit {
      url = "https://git.collinwebdesigns.de/oscar.krause/fastapi-dls";
      ref = "refs/tags/1.3.5";
    };

  }; */
/*
  fastapi-dls = pkgs.python38Packages.buildPythonApplication {
    pname = "fastapi-dls";
    src = pkgs.fetchFromGitHub {
      owner = "oscar-krause";
      repo = "fastapi-dls";
      rev = "14cf6a953fc46f9cafbd9818214201f6248c58b8";
      sha256 = "";
    };
    buildInputs = with pkgs; [
      git
      python3
      python3Packages.virtualenv
      python3Packages.pip
      openssl
    ];
    installPhase = ''
      cd app/cert
      openssl genrsa -out instance.private.pem 2048 
      openssl rsa -in instance.private.pem -outform PEM -pubout -out instance.public.pem
      openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout  webserver.key -out webserver.crt
      cd ../..
      python3 -m venv venv
      source venv/bin/activate
      pip install -r requirements.txt
      deactivate
      mkdir -p $out/bin
      cp -r ./* $out/bin/
      chmod +x $out/bin/main.py
    '';
    meta = with pkgs.meta; {
      description = "FastAPI-DLS - A Dynamic Lease Service with a REST API";
      homepage = "https://git.collinwebdesigns.de/oscar.krause/fastapi-dls";
      license = licenses.mit;
      maintainers = [ maintainers.krausos ];
    };
  };
*/
/*
  mach-nix = import (builtins.fetchGit {
    url = "https://github.com/DavHau/mach-nix";
    ref = "refs/tags/3.5.0";
  }) {};

  mypythondls = mach-nix.mkPython {  # replace with mkPythonShell if shell is wanted
        requirements = ''
fastapi
uvicorn[standard]
python-jose==3.3.0
pycryptodome
python-dateutil==2.8.2
sqlalchemy
markdown
python-dotenv
        '';
      }  ;

  fastapi-dls = pkgs.python38Packages.buildPythonPackage {
    pname = "fastapi-dls";
    version = "1.3.5";

    src = pkgs.fetchFromGitLab {
      domain = "git.collinwebdesigns.de";
      #group = "pleroma";
      owner = "oscar.krause";
      repo = "fastapi-dls";
      rev = "14cf6a953fc46f9cafbd9818214201f6248c58b8";
      sha256 = "sha256-nxpljlOfdhYDpbgOfNTMUf9MtiaZgiOoofqEu1Cv7co=";
    };

    #src = fetchgit {
    #  url = "git@github.com:XXXX/${pname}.git";
    #  rev  = "XXXX";
    #  sha256 = "XXXX";
    #};


   # src = pkgs.fetchurl {
   #           name = "fastapi-dla-repo"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
   #           url = "https://git.collinwebdesigns.de/oscar.krause/fastapi-dls/-/archive/1.3.5/fastapi-dls-1.3.5.tar.gz";
   #           sha256 = "sha256-Ijk1er28mQjGI+IwTErJ4khV26C11cOdU5qDZ1+jdAM=";
   #         };

    buildInputs = [ mypythondls ];

    shellHook = ''
      echo ${frida}
    '';
  };
  */

  vgpu_unlock = pkgs.python3Packages.buildPythonPackage {
    pname = "nvidia-vgpu-unlock";
    version = "unstable-2021-04-22";
    src = /mnt/DataDisk/Downloads/my_vgpu_unlock;
    
    propagatedBuildInputs = [ frida ];
    
    doCheck = false; # Disable running checks during the build
    
    installPhase = ''
      mkdir -p $out/bin
      cp vgpu_unlock $out/bin/
      substituteInPlace $out/bin/vgpu_unlock \
              --replace /bin/bash ${pkgs.bash}/bin/bash
    '';

    #installFlags = [ "--install-scripts=$out/bin" ];
    #installTargets = [ "vgpu_unlock" ];

    #postInstall = ''
    #  substituteInPlace $out/bin/vgpu_unlock \
    #    --replace /bin/bash ${pkgs.bash}/bin/bash
    #'';
  };

/*
  vgpu_unlock = pkgs.stdenv.mkDerivation { # pkgs.python3Packages.buildPythonPackage
    name = "nvidia-vgpu-unlock";
    version = "unstable-2021-04-22";

    src = /mnt/DataDisk/Downloads/my_vgpu_unlock;


    buildInputs = [ frida ];

    shellHook = ''
      echo ${frida}
    '';

    postPatch = ''
      echo ${frida}
      ${pkgs.python3}/bin/python --version
      ${pkgs.unixtools.util-linux}/bin/whereis python

      env | grep PYTHON
      ${pkgs.python3}/bin/python --version
      ${pkgs.python3}/bin/python -c "import frida" && echo "frida is installed" || echo "frida is not installed"
            
      substituteInPlace vgpu_unlock \
        --replace /bin/bash ${pkgs.bash}/bin/bash
    '';

    installPhase = "install -Dm755 vgpu_unlock $out/bin/vgpu_unlock";
  };
*/

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
            local_ipv4 = lib.mkOption {
              description = "your ipv4, needed for the fastapi-dls server";
              example = "192.168.1.81";
              type = lib.types.str;
            };
            timezone = lib.mkOption {
              description = "your timezone according to this list: https://docs.diladele.com/docker/timezones.html, needs to be the same as in the VM, needed for the fastapi-dls server";
              example = "Europe/Lisbon";
              type = lib.types.str;
            };
          };
        };
      };
      
    };
  };

  config = lib.mkMerge [

 (lib.mkIf cfg.enable {
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs ( # CHANGE stable to legacy_470 to pin the version of the driver if it stops working
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

    environment.systemPackages = [ mdevctl];
    services.udev.packages = [ mdevctl ];

  })

    # fastapi-dls docker service
    /*
    WORKING_DIR=/opt/docker/fastapi-dls/cert

    sudo mkdir -p /opt/docker/fastapi-dls/cert
    mkdir -p $WORKING_DIR
    cd $WORKING_DIR
    # create instance private and public key for singing JWT's
    openssl genrsa -out $WORKING_DIR/instance.private.pem 2048 
    openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
    # create ssl certificate for integrated webserver (uvicorn) - because clients rely on ssl
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout  $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt
    */
    (lib.mkIf cfg.fastapi-dls.enable {

/*
      systemd.services.fastapi-dls = {
        description = "fastapi-dls server";
        wants = [ "syslog.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          User = "www-data";
          Group = "www-data";
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          WorkingDirectory = "${fastapi-dls}/app";
          EnvironmentFile = "${fastapi-dls}/env";
          ExecStart = "${fastapi-dls}/venv/bin/uvicorn main:app \\\n  --env-file /etc/fastapi-dls/env \\\n  --host \$DLS_URL --port \$DLS_PORT \\\n  --app-dir ${fastapi-dls}/app \\\n  --ssl-keyfile ${fastapi-dls}/app/cert/webserver.key \\\n  --ssl-certfile ${fastapi-dls}/app/cert/webserver.crt \\\n  --proxy-headers";
          Restart = "always";
          KillSignal = "SIGQUIT";
          Type = "simple";
          NotifyAccess = "all";
        };
      };
      */


      # environment.systemPackages = [ fastapi-dls ];

/*
      lib.shellHook = ''
        WORKING_DIR=${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert  # default: /opt/docker/fastapi-dls/cert

        çasojdkasop

        sudo mkdir -p $WORKING_DIR
        mkdir -p $WORKING_DIR
        cd $WORKING_DIR
        # create instance private and public key for singing JWT's
        ${pkgs.openssl.bin}/bin/openssl genrsa -out $WORKING_DIR/instance.private.pem 2048 
        ${pkgs.openssl.bin}/bin/openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
        # create ssl certificate for integrated webserver (uvicorn) - because clients rely on ssl
        ${pkgs.openssl.bin}/bin/openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout  $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt
      '';
 */

      /*
      systemd.services."certificates-for-fastapi-dls" = {
        description = "certificates-for-fastapi-dls";
        wants = [ "syslog.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "forking";
          ExecStart = ''
            WORKING_DIR=${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert  # default: /opt/docker/fastapi-dls/cert

            mkdir -p $WORKING_DIR
            cd $WORKING_DIR
            # create instance private and public key for singing JWT's
            ${pkgs.openssl.bin}/bin/openssl genrsa -out $WORKING_DIR/instance.private.pem 2048 
            ${pkgs.openssl.bin}/bin/openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
            # create ssl certificate for integrated webserver (uvicorn) - because clients rely on ssl
            ${pkgs.openssl.bin}/bin/openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout  $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt
          '';
        };
      }; */

      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls:latest";
          volumes = [
            "${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert:/app/cert:rw"
            "dls-db:/app/database"
          ];
          # Set environment variables
          environment = {
            TZ = "${cfg.fastapi-dls.timezone}";
            DLS_URL = "${cfg.fastapi-dls.local_ipv4}"; # this should grab your hostname, not your IP!...
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
