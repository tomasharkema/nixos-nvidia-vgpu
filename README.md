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
    This currently downlaods and installs a merged driver that I built, gets it from my google drive.
3. Run `nixos-rebuild switch`. 

## Guest VM

### Windows

In the Windows VM you need to install the appropriate drivers too, if you use a A profile for example (from the `mdevctl types` command) you can use the normal driver from the [nvidia licensing server](#nvidia-drivers), if you want a Q profile ([difference between profiles](https://youtu.be/cPrOoeMxzu0?t=1244)), you're gonna need to get the driver from the [nvidia servers](#nvidia-drivers) and patch it with the [community vgpu unlock repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher).

That [didn't work for me either](https://discord.com/channels/829786927829745685/830520513834516530/1109199157299793970) tho, so I had to use the special `GeForce RTX 2070-` profiles (from `mdevctl types`) and a special driver for the VM, [this one](https://nvidia-gaming.s3.us-east-1.amazonaws.com/windows/528.49_Cloud_Gaming_win10_win11_server2019_server2022_dch_64bit_international.exe).  
Here is the explenation of where that driver is from:
> vGaming is specially licensed.  
> there's no trial and you need to buy a compute cluster from nuhvidya.  
> But Amazon has this and they host the drivers for people to use.  
> The link comes from their bucket that has the vGaming drivers

### nvidia-drivers

To get the nvidia vgpu drivers: downloads are available from nvidia site [here](http://nvid.nvidia.com/dashboard/), evaluation account may be obtained [here](http://www.nvidia.com/object/vgpu-evaluation.html)  
For guest drivers for windows get the ones with the name `Microsoft Hyper-V Server`  
To check and match versions see [here](https://docs.nvidia.com/grid/index.html). For example:
| vGPU Software | Linux vGPU Manager | Windows vGPU Manager | Linux Driver | Windows Driver | Release Date |
|--------------|-------------------|---------------------|--------------|----------------|--------------|
| 15.2         | 525.105.14        | 528.89              | 525.105.17   | 528.89         | March 2023   |
| 15.1         | 525.85.07         | 528.24              | 525.85.05    | 528.24         | January 2023 |
| 15.0         | 525.60.12         | 527.41              | 525.60.13    | 527.41         | December 2022|


## Requirements
This has been tested with the kernel `5.15.108` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 22.11.20230428.7449971`

## Additional Notes
To test if everything is installed correctly run `nvidia-smi vgpu`. If there is no output something went wrong with the installation.  
Test also `mdevctl types`, if there is no output, maybe your graphics isn't supported yet, maybe you need to add a `vcfgclone` line as per [this repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher). If that is the case, you'll need to recompile the driver with the new `vcfgclone`, upload it somewhere, and change the src to grab your driver instead:
```nix
  # the new driver (getting from my Google drive)
  src = pkgs.fetchurl {
          name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
          url = "https://drive.google.com/u/1/uc?id=17NN0zZcoj-uY2BELxY2YqGvf6KtZNXhG&export=download&confirm=t&uuid=e2729c36-3bb7-4be6-95b0-08e06eac55ce&at=AKKF8vzPeXmt0W_pxHE9rMqewfXY:1683158182055";
          sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
        };
```

You can also check if the services `nvidia-vgpu-mgr` and `nvidia-vgpud` executed without errors with `systemctl status nvidia-vgpud` and `systemctl status nvidia-vgpu-mgr`. (or something like `journalctl -fu nvidia-vgpud` to see the logs in real time)

I've tested creating an mdev on my own `NVIDIA GeForce RTX 2060 Mobile` by running:
```bash
> sudo su
> mdevctl start -u ce851576-7e81-46f1-96e1-718da691e53e -p 0000:01:00.0 --type nvidia-258 && mdevctl start -u b761f485-1eac-44bc-8ae6-2a3569881a1a -p 0000:01:00.0 --type nvidia-258 && mdevctl define --auto --uuid ce851576-7e81-46f1-96e1-718da691e53e && mdevctl define --auto --uuid b761f485-1eac-44bc-8ae6-2a3569881a1a
```
That creates two vgpus in my graphics card (because my card has 6Gb and it needs to devide evenly, so 3Gb each Vgpu)

check if they were created successfully with `mdevctl list`
```bash
 ✘ ⚡ root@nixOS-Laptop  /home/yeshey  mdevctl list
ce851576-7e81-46f1-96e1-718da691e53e 0000:01:00.0 nvidia-258 (defined)
b761f485-1eac-44bc-8ae6-2a3569881a1a 0000:01:00.0 nvidia-258 (defined)
```

Also you can change the resolution and other parameters of a profile directly in the vgpu config xml, so you can mod for example a A profile as you need, just need to reboot to get the changes loaded (or reload all the stuff)

## To-Do

- Fix issues below
- Make a full guide for begginers on how to make virt-manager, looking-glass, windows VM with vgpu unlock in nixOS
- Make it get the files it neesd from <https://archive.biggerthanshit.com/> and compile the merged driver that it will install with the [community vgpu repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher), instead of grabbing the prebuilt version from your google drive.

---

For more help visit the [Join VGPU-Unlock discord for Support](https://discord.com/invite/5rQsSV3Byq), for help related to nixOS, tag me (Jonnas#1835)

## Disclaimer and contributions

I'm not an experienced nix developer and a lot of whats implemented here could be done in a better way. If anyone is interested in contributing, you may get in contact through the issues or my email (yesheysangpo@gmail.com) or simply make a pull request with details as to what it changes.

I have these questions on the nixOS discourse that reflect the biggest problems with this module as of now:
- Commands need to be ran manually for the docker volume to work: (no issue created yet)
- ~~Hard coded nix store paths: https://discourse.nixos.org/t/how-to-use-python-environment-in-a-systemd-service/28022~~ (fixed!)

This was heavily based and inspiered in these two repositories:
- old NixOS module: https://github.com/danielfullmer/nixos-nvidia-vgpu
- vgpu for newer nvidia drivers: https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher
