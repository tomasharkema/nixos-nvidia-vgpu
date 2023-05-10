# NixOS NVIDIA vGPU Module

Example usage:
1. run these commands for docker to work (needed if you'll enable `fastapi-dls`):
   ```bash
    WORKING_DIR=/opt/docker/fastapi-dls/cert

    sudo mkdir -p /opt/docker/fastapi-dls/cert
    mkdir -p $WORKING_DIR
    cd $WORKING_DIR
    # create instance private and public key for singing JWT's
    openssl genrsa -out $WORKING_DIR/instance.private.pem 2048 
    openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
    # create ssl certificate for integrated webserver (uvicorn) - because clients rely on ssl
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout  $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt
   ```
2. Add this to your nixOS configuration:
    ```nix
    {
      # Optionally replace "master" with a particular revision to pin this dependency.
      # This repo also provides the module in a "Nix flake" under `nixosModules.nvidia-vgpu` output
      imports = [ (builtins.fetchTarball "https://github.com/Yeshey/nixos-nvidia-vgpu_nixOS22.11_WIP/archive/master.tar.gz") ];

      hardware.nvidia = {
        vgpu = {
          enable = true; # Install NVIDIA KVM vGPU + GRID merged driver for consumer cards with vgpu unlocked.
          unlock.enable = true; # Activates systemd services to enable vGPU functionality on using DualCoder/vgpu_unlock project.
          fastapi-dls = { # For the license server for unrestricted use of the vgpu driver in guests
            enable = true;
            local_ipv4 = "192.168.1.81"; # Your local IP
            timezone = "Europe/Lisbon"; # Your timezone (needs to be the same as the tz in the VM)
          };
        };
      };
    }
    ```
    This currently downlaods and installes a merged driver that I built.
3. As of now, you'll also have to change the hardcoded nix store paths. instead of the above solution, you'll have to clone the repo, if in a flake, import it with something like:
    ```nix
    inputs = {
      nixos-nvidia-vgpu = {
        type = "path";
        path = "/path/to/nixos-nvidia-vgpu_nixOS22.11/";
      };
      ...
    }
    ```
    add some gyberish to the vgpu_unlock variable so it fails like this:
    ```bash
      postPatch = ''
      echo ${frida}
      ${pkgs.python3}/bin/python --version
      ${pkgs.unixtools.util-linux}/bin/whereis python

      env | grep PYTHON
      ${pkgs.python3}/bin/python --version
      ${pkgs.python3}/bin/python -c "import frida" && echo "frida is installed" || echo "frida is not installed"

      asdasda # HERE

      substituteInPlace vgpu_unlock \
        --replace /bin/bash ${pkgs.bash}/bin/bash
    '';
    ```
    run `sudo nixos-rebuild switch --update-input nixos-nvidia-vgpu --impure`
    and check the error message:
    ```bash
    error: builder for '/nix/store/ykfj7qrm62a9dd08msynkb9chyiss6si-nvidia-vgpu-unlock.drv' failed with exit code 127;
          last 10 log lines:
          > python: /nix/store/fdqpyj613dr0v1l1lrzqhzay7sk4xg87-python3-3.10.10/bin/python
          > _PYTHON_HOST_PLATFORM=linux-x86_64
          > PYTHONNOUSERSITE=1
          > PYTHONHASHSEED=0
          > _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_x86_64-linux-gnu
          > PYTHONPATH=/nix/store/sb4a338qh7wld75zbcgrylrpqmjnfh27-python3.10-frida-tools-12.1.1/lib/python3.10/site-packages:/nix/store/ndr7x7qhkssarrgjpqqnv8i9py4vyc9c-python3.10-colorama-0.4.6/lib/python3.10/site-packages:/nix/store/fdqpyj613dr0v1l1lrzqhzay7sk4xg87-python3-3.10.10/lib/python3.10/site-packages:/nix/store/lz6vq2kp7rww3jj6f7zgf4n50c3qvc83-python3.10-frida-16.0.18/lib/python3.10/site-packages:/nix/store/k7xyj5b5dw0cna25b91ygqskkwv8na4s-python3.10-typing-extensions-4.5.0/lib/python3.10/site-packages:/nix/store/pf9j3spzhbz7gvmbyk6a5kwcmi7zvpmy-python3.10-prompt-toolkit-3.0.38/lib/python3.10/site-packages:/nix/store/hix271phwzb157a2sj9fn5zfmkpz8zpd-python3.10-six-1.16.0/lib/python3.10/site-packages:/nix/store/khqw9ph04dvjy86rlzxzhyk21c2binhi-python3.10-wcwidth-0.2.6/lib/python3.10/site-packages:/nix/store/fpcah4a88pjj7jmwhrcvfb9kg6qj58vc-python3.10-setuptools-67.4.0/lib/python3.10/site-packages:/nix/store/asf94iynbzxraqzmbi2w69vj3khaphan-python3.10-pygments-2.14.0/lib/python3.10/site-packages:/nix/store/d8ghysrcn5nsyh9w3gvwg5kk1iyy510r-python3.10-docutils-0.19/lib/python3.10/site-packages
          > env | grep PYTHON
          > Python 3.10.11
          > frida is installed
          > /nix/store/0jmdsgfnd6aakxdr0sl5l7zzfs59hdrw-stdenv-linux/setup: line 95: asdasda: command not found
          For full logs, run 'nix log /nix/store/ykfj7qrm62a9dd08msynkb9chyiss6si-nvidia-vgpu-unlock.drv'.
    ```
    and those are the environment variables you'll have to change in both systemd (`systemd.services.nvidia-vgpu-mgr` and `systemd.services.nvidia-vgpud`) services in the `Environment` section in the module.
    This is the step that I'm trying to solve in [this discourse thread](https://discourse.nixos.org/t/how-to-use-python-environment-in-a-systemd-service/28022).
    
For more help visit the [Join VGPU-Unlock discord for Support](https://discord.com/invite/5rQsSV3Byq), for help related to nixOS, tag me (Jonnas#1835)

## Requirements
This has been teste with the kernel `5.15.108` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 22.11.20230428.7449971`

## Additional Notes
To test if everything is installed correctly run `nvidia-smi vgpu`. If there is no output something went wrong with the installation.
Test also `mdevctl types`, if there is no output, maybe your graphics isn't supported yet, maybe you need to add a `vcfgclone` line as per [this repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher). If that is the case, as I'm fetching the pre compiled driver from my google drive in this repo, you'll need to recompile the driver with the new `vcfgclone`, upload it somewhere, and change the src to grab your driver instead:
```nix
  # the new driver (getting from my Google drive)
  src = pkgs.fetchurl {
          name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
          url = "https://drive.google.com/u/1/uc?id=17NN0zZcoj-uY2BELxY2YqGvf6KtZNXhG&export=download&confirm=t&uuid=e2729c36-3bb7-4be6-95b0-08e06eac55ce&at=AKKF8vzPeXmt0W_pxHE9rMqewfXY:1683158182055";
          sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
        };
```

I've tested creating an mdev on my own `NVIDIA GeForce RTX 2060 Mobile` by running:
```bash
> sudo su
> mdevctl start -u ce851576-7e81-46f1-96e1-718da691e53e -p 0000:01:00.0 --type nvidia-258 && mdevctl start -u b761f485-1eac-44bc-8ae6-2a3569881a1a -p 0000:01:00.0 --type nvidia-258 && mdevctl define --auto --uuid ce851576-7e81-46f1-96e1-718da691e53e && mdevctl define --auto --uuid b761f485-1eac-44bc-8ae6-2a3569881a1a && mdevctl list
```
That creates two vgpus in my graphics card (because my card has 6Gb and it needs to devide evenly, so 3Gb each Vgpu)

check if they were created successfully with `mdevctl list`
```bash
 ✘ ⚡ root@nixOS-Laptop  /home/yeshey  mdevctl list
ce851576-7e81-46f1-96e1-718da691e53e 0000:01:00.0 nvidia-258 (defined)
b761f485-1eac-44bc-8ae6-2a3569881a1a 0000:01:00.0 nvidia-258 (defined)
```


## Disclaimer and contributions

I'm not a (good) nix developer and a lot of whats implemented here could be done in a better way, but I don't have time or the skills to improve this much further on my own. If anyone is interested in contributing, you may get in contact through the issues or my email (yesheysangpo@gmail.com) or discord (Jonnas#1835) or simply make a pull request with details as to what it changes.

I have these questions on the nixOS discourse that reflect the biggest problems with this module as of now:
- Hard coded nix store paths: https://discourse.nixos.org/t/how-to-use-python-environment-in-a-systemd-service/28022
- Commands need to be ran manually for the docker volume to work: (no issue created yet)

This was heavily based and inspiered in these two repositories:
- old NixOS module: https://github.com/danielfullmer/nixos-nvidia-vgpu
- vgpu for newer nvidia drivers: https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher