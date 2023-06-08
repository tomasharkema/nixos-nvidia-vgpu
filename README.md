# NixOS NVIDIA vGPU Module

This module unlocks vGPU functionality on your consumer nvidia card.

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
      imports = [ (builtins.fetchTarball "https://github.com/Yeshey/nixos-nvidia-vgpu_nixOS/archive/master.tar.gz") ];

      boot.kernelPackages = pkgs.linuxPackages_5_15; # Requires this kernel to work
      hardware.nvidia = {
        vgpu = {
          enable = true; # Install NVIDIA KVM vGPU + GRID merged driver for consumer cards with vgpu unlocked.
          unlock.enable = true; # Activates systemd services to enable vGPU functionality on using DualCoder/vgpu_unlock project.
          fastapi-dls = { # For the license server for unrestricted use of the vgpu driver in guests
            enable = true;
            local_ipv4 = "localhost"; # Use your local IP or hostname if not working (Ex: 192.168.1.81)
            timezone = "Europe/Lisbon"; # Your timezone (needs to be the same as the tz in the VM)
          };
        };
      };
    }
    ```
    This currently downlaods and installs a merged driver that I built, gets it from my google drive. And requires kernel `5.15`.
3. Run `nixos-rebuild switch --impure`. (unfortunatley it still needs --impure to run, see issues) 

## Requirements

- Unlockable consumer NVIDIA GPU card (can't be `Ampere` architecture)
  - These are the graphics cards the driver I pre-compiled supports: ([from here](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher/blob/525.105/patch.sh))
    ```
      # RTX 2070 super 8GB
      # RTX 2080 super 8GB
      # RTX 2060 12GB
      # RTX 2060 Mobile 6GB
      # GTX 1660 6GB
      # GTX 1650 Ti Mobile 4GB
      # Quadro RTX 4000
      # Quadro T400 4GB
      # GTX 1050 Ti 4GB
      # GTX 1070
      # GTX 1030 -> Tesla P40
      # Tesla M40 -> Tesla M60
      # GTX 980 -> Tesla M60
      # GTX 980M -> Tesla M60
      # GTX 950M -> Tesla M10
    ```
    If yours is not in this list, you'll likely have to add support for your graphics card and compile the driver, please refer to [Compile your driver](#compile-your-driver).
- Trust in my google drive
  - The module lazily grabs the driver I pre-built from my google drive, if you're not confortable with this, please refer to [Compile your driver](#compile-your-driver) to compile your own driver and use it.
- Kernel `5.15` as stated above

### Warning: 

The current version in the `master` branch only works in version `23.05` of nixOS and older. If you're on `unstable` please refer below:
 
#### `unstable`
 
- To make this module work in unstable, you'll have to clone the repo and change in the file `flake.nix` the line: `inputs.frida.url = "github:Yeshey/frida-nix";` to `inputs.frida.url = "github:itstarsun/frida-nix";`.  
  The original repository that provides frida tools already works with the unstable channel.

### Tested in

- kernel `5.15.108` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 22.11.20230428.7449971`. 
- kernel `5.15.108` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 23.05.20230605.70f7275`.

## Guest VM

### Windows

In the Windows VM you need to install the appropriate drivers too, if you use a A profile([difference between profiles](https://youtu.be/cPrOoeMxzu0?t=1244)) for example (from the `mdevctl types` command) you can use the normal driver from the [nvidia licensing server](#nvidia-drivers), if you want a Q profile, you're gonna need to get the driver from the [nvidia servers](#nvidia-drivers) and patch it with the [community vgpu unlock repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher).

That [didn't work for me either](https://discord.com/channels/829786927829745685/830520513834516530/1109199157299793970) tho, so I had to use the special `GeForce RTX 2070-` profiles (from `mdevctl types`) and a special driver for the VM, [this one](https://nvidia-gaming.s3.us-east-1.amazonaws.com/windows/528.49_Cloud_Gaming_win10_win11_server2019_server2022_dch_64bit_international.exe).  
Here is the explenation of where that driver is from:
> vGaming is specially licensed.  
> there's no trial and you need to buy a compute cluster from nuhvidya.  
> But Amazon has this and they host the drivers for people to use.  
> The link comes from their bucket that has the vGaming drivers

### Looking Glass

You can add [this module](https://github.com/NixOS/nixpkgs/blob/63c34abfb33b8c579631df6b5ca00c0430a395df/nixos/modules/programs/looking-glass.nix) to your nixOS configuration, I don't think it's in nixpkgs yet, so you can import it like this:
```nix
imports = [
  (import (builtins.fetchurl{
        url = "https://github.com/NixOS/nixpkgs/raw/63c34abfb33b8c579631df6b5ca00c0430a395df/nixos/modules/programs/looking-glass.nix";
        sha256 = "sha256:1lfrqix8kxfawnlrirq059w1hk3kcfq4p8g6kal3kbsczw90rhki";
      } ))
];
```

Then you can activate it like this:

```nix
  programs.looking-glass = {
    enable = true;
  };
```

If your looking glass version currently in nixpkgs is below B6, I advise you to get at least the [B6 version](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/virtualization/looking-glass-client/default.nix), to also have sound transfered over:

```nix
  programs.looking-glass = let
    # Looking glass B6 version in nixpkgs: 
    myPkgs = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/9fa5c1f0a85f83dfa928528a33a28f063ae3858d.tar.gz";
    }) {};

    LookingGlassB6 = myPkgs.looking-glass-client;
  in {
    enable = true;
    package = LookingGlassB6;
  };
```

#### Debug

If it gives a permission error like this:
```
[E]    242844972           ivshmem.c:159  | ivshmemOpenDev                 | Permission denied
```
You can fix it for the current session with `sudo chmod 777 /dev/shm/looking-glass`

If it gives a reerr like this:
```
Invalid value provided to the option: app:shmFile

 Error: Invalid path to the ivshmem file specified

Valid values are:
```

then `sudo touch /dev/shm/looking-glass` and `sudo chmod 777 /dev/shm/looking-glass` and THEN start the VM. If the VM was already running you'll need to reboot and try to run looking glass before starting the VM.

### Share folders

The best way I found to share folders is through the network with samba, couldn't make `spice-webdav` work with looking-glass. 

Take a look at the following configuration to realise that:

```nix
  # For sharing folders with the windows VM
  # Make your local IP static for the VM to never lose the folders
  networking.interfaces.eth0.ipv4.addresses = [ {
    address = "192.168.1.109";
    prefixLength = 24;
  } ];
  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  networking.firewall.allowedTCPPorts = [
    5357 # wsdd
  ];
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
  ];
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      security = user 
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      #hosts allow = 192.168.0. 127.0.0.1 localhost
      #hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      hdd-ntfs = {
        path = "/mnt/hdd-ntfs";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        #"force user" = "username";
        #"force group" = "groupname";
      };
      DataDisk = {
        path = "/mnt/DataDisk";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        #"force user" = "username";
        #"force group" = "groupname";
      };
    };
  };
  networking.firewall.allowPing = true;
  services.samba.openFirewall = true;
  # However, for this samba share to work you will need to run `sudo smbpasswd -a <yourusername>` after building your configuration! (as stated in the nixOS wiki for samba: https://nixos.wiki/wiki/Samba)
  # In windows you can access them in file explorer with `\\192.168.1.xxx` or whatever your local IP is
  # In Windowos you should also map them to a drive to use them in a lot of programs, for this:
  #   - Add a file MapNetworkDriveDataDisk and MapNetworkDriveHdd-ntfs to the folder C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup (to be accessible to every user in every startup):
  #      With these contents respectively:
  #         net use V: "\\192.168.1.109\DataDisk" /p:yes
  #      and
  #         net use V: "\\192.168.1.109\hdd-ntfs" /p:yes
  # Then to have those drives be usable by administrator programs, open a cmd with priviliges and also run both commands above! This might be needed if you want to for example install a game in them, see this reddit post: https://www.reddit.com/r/uplay/comments/tww5ey/any_way_to_install_games_to_a_network_drive/
```

As explained in the comments in the above code you'll have to mount the network drives in windows.

I also advise you to make your local IP static, to prevent windows from loosing access to those folder because of IP changes:

```nix
  # For sharing folders with the windows VM
  # Make your local IP static for the VM to never lose the folders
  networking.interfaces.eth0.ipv4.addresses = [ {
    address = "192.168.1.109";
    prefixLength = 24;
  } ];
```

### nvidia-drivers

To get the nvidia vgpu drivers: downloads are available from nvidia site [here](http://nvid.nvidia.com/dashboard/), evaluation account may be obtained [here](http://www.nvidia.com/object/vgpu-evaluation.html)  
For guest drivers for windows get the ones with the name `Microsoft Hyper-V Server`  
To check and match versions see [here](https://docs.nvidia.com/grid/index.html). For example:
| vGPU Software | Linux vGPU Manager | Windows vGPU Manager | Linux Driver | Windows Driver | Release Date |
|--------------|-------------------|---------------------|--------------|----------------|--------------|
| 15.2         | 525.105.14        | 528.89              | 525.105.17   | 528.89         | March 2023   |
| 15.1         | 525.85.07         | 528.24              | 525.85.05    | 528.24         | January 2023 |
| 15.0         | 525.60.12         | 527.41              | 525.60.13    | 527.41         | December 2022|

## Additional Notes

To test if everything is installed correctly run `nvidia-smi vgpu`. If there is no output something went wrong with the installation.  
Test also `mdevctl types`, if there is no output, maybe your graphics card isn't supported yet, you'll need to add a `vcfgclone` line as per [this repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher). If that is the case, you'll need to recompile the driver with the new `vcfgclone`, upload it somewhere, and change the src to grab your driver instead. Refer to [Compile your driver](#compile-your-driver)

You can also check if the services `nvidia-vgpu-mgr` and `nvidia-vgpud` executed without errors with `systemctl status nvidia-vgpud` and `systemctl status nvidia-vgpu-mgr`. (or something like `journalctl -fu nvidia-vgpud` to see the logs in real time)

If you set up fastapi-dls correctly, you should get a notification when your windows VM starts saying "nvidia license aquiered"

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

## Compile your driver

If you don't trust my Google drive pre built driver, or if it doesn't have support for your graphics card yet, you'll need to compile the driver:

1. Refer to the [vGPU community repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher) to compile your own driver. If your graphics card isn't supported you'll likely have to add a `vcfgclone` in patch.sh of their repository as per their instructions.
   1. I compiled it in another OS(manjaro in my case), as nixOS proved to be harder.
2. Upload your driver somewhere, for example, google drive 
3. Download or clone this repo and change the following line to point to the download link of your new driver instead. You might also have to change the `sha256`
    ```nix
      # the new driver (getting from my Google drive)
      src = pkgs.fetchurl {
              name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
              url = "https://drive.google.com/u/1/uc?id=17NN0zZcoj-uY2BELxY2YqGvf6KtZNXhG&export=download&confirm=t&uuid=e2729c36-3bb7-4be6-95b0-08e06eac55ce&at=AKKF8vzPeXmt0W_pxHE9rMqewfXY:1683158182055";
              sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
            };
    ```
4. In your configuration point to this new module instead.

## To-Do

- Fix issues below
- Make a full guide for begginers on how to make virt-manager, looking-glass, windows VM with vgpu unlock in nixOS
- Make it get the files it neesd from <https://archive.biggerthanshit.com/> and compile the merged driver that it will install with the [community vgpu repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher), instead of grabbing the prebuilt version from your google drive.

---

For more help [Join VGPU-Unlock discord for Support](https://discord.com/invite/5rQsSV3Byq), for help related to nixOS, tag me (Jonnas#1835)

## Disclaimer and contributions

I'm not an experienced nix developer and a lot of whats implemented here could be done in a better way. If anyone is interested in contributing, you may get in contact through the issues or my email (yesheysangpo@gmail.com) or simply make a pull request with details as to what it changes.

I have these questions on the nixOS discourse that reflect the biggest problems with this module as of now:
- Commands need to be ran manually for the docker volume to work: (no issue created yet)
- Still needs `--impure`: `access to absolute path '/opt/docker' is forbidden in pure eval mode (use '--impure' to override)`
- ~~Needs `--impure` to run.~~
  - ~~`error: cannot call 'getFlake' on unlocked flake reference 'github:itstarsun/frida-nix'`, because of the line:~~
  - ~~`frida = (builtins.getFlake "github:itstarsun/frida-nix").packages.x86_64-linux.frida-tools;`~~ (fixed, [thanks](https://discourse.nixos.org/t/for-nixos-on-aws-ec2-how-to-get-ip-address/15616/12?u=yeshey)!)
- ~~Hard coded nix store paths: https://discourse.nixos.org/t/how-to-use-python-environment-in-a-systemd-service/28022~~ (fixed!)

This was heavily based and inspiered in these two repositories:
- old NixOS module: https://github.com/danielfullmer/nixos-nvidia-vgpu
- vgpu for newer nvidia drivers: https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher
