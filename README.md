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


## Requirements
This module currently only works with a NixOS `>= 21.05` which has the `hardware.nvidia.package` option (Added in January 2021).
Additionally, the NVIDIA drivers used do not compile with newer kernels (I think `>= 5.10`).
This module has been tested using the `5.4` Linux kernel.

## Additional Notes
See also: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/assembly_managing-nvidia-vgpu-devices_configuring-and-managing-virtualization

I've tested creating an mdev on my own 1080 Ti by running:
```shell
$ sudo mdevctl start -u 2d3a3f00-633f-48d3-96f0-17466845e672 -p 0000:03:00.0 --type nvidia-51
```
`nvidia-51` is the code for "GRID P40-8Q" in vgpuConfig.xml
```shell
$ sudo mdevctl define --auto --uuid 2d3a3f00-633f-48d3-96f0-17466845e672
```

## Disclaimer and contributions

I'm not a (good) nix developer and a lot of whats implemented here could be done in a better way, but I don't have time or the skills to improve this much further on my own. If anyone is interested in contributing, you may get in contact through the issues or my email (yesheysangpo@gmail.com) or discord (Jonnas#1835) or simply make a pull request with details as to what it changes.

I have these questions on the nixOS discourse that reflect the biggest problems with this module as of now:
- Hard coded nix store paths: https://discourse.nixos.org/t/how-to-use-python-environment-in-a-systemd-service/28022
- Commands need to be ran manually for the docker volume to work: (no issue created yet)

This was heavily based and inspiered in these two repositories:
- old NixOS module: https://github.com/danielfullmer/nixos-nvidia-vgpu
- vgpu for newer nvidia drivers: https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher