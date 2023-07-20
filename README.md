# NixOS NVIDIA vGPU Module

This module unlocks vGPU functionality on your consumer nvidia card.

Example usage:

1. Add this repo to the inputs of your system flake. For an introduction to flakes, see [here](https://nixos.wiki/wiki/Flakes).

2. Add this to your nixOS configuration:
   
   ```nix
   {
     hardware.nvidia = {
       vgpu = {
         enable = true; # Install NVIDIA KVM vGPU + GRID merged driver for consumer cards with vgpu unlocked.
         fastapi-dls = { # For the license server for unrestricted use of the vgpu driver in guests
           enable = true;
           #local_ipv4 = "localhost"; # Hostname is autodetected, use this setting to override
           #timezone = "Europe/Lisbon"; # Timezone is autodetected, use this setting to override (needs to be the same as the tz in the VM)
         };
       };
     };
   }
   ```

3. Run `nixos-rebuild switch`.

## Requirements

- Unlockable consumer NVIDIA GPU card (can't be `Ampere` architecture)
  - These are the graphics cards the driver supports: ([from here](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher/blob/525.105/patch.sh))
    
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
    
    TODO: Add mechanism to add more cards
- Trust in https://github.com/justin-himself/NVIDIA-VGPU-Driver-Archive/tree/master
  - The module fetches (what are supposed to be) unmodified nvidia drivers from this repo. If you don't trust it and you [have access to known good sources](https://gitlab.com/polloloco/vgpu-proxmox#nvidia-driver) you can verify the hashes of the .run files with them.
- This was only tested on NixOS `23.05`. Might work with older versions, might not.

## Guest VM

### Windows

In the Windows VM you need to install the appropriate drivers too, if you use a A profile ([difference between profiles](https://youtu.be/cPrOoeMxzu0?t=1244)) for example (from the `mdevctl types` command) you can use the normal driver from the [nvidia licensing server](#nvidia-drivers), if you want a Q profile, you're gonna need to get the driver from the [nvidia servers](#nvidia-drivers) and patch it with the [community vgpu unlock repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher).

## Additional Notes

To test if everything is installed correctly run `nvidia-smi vgpu`. If there is no output something went wrong with the installation.  
Also test `mdevctl types`, if there is no output, maybe your graphics card isn't supported yet. (TODO: add setting to modify the [vcfgclone lines](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher#usage))

You can also check if the services `nvidia-vgpu-mgr` and `nvidia-vgpud` executed without errors with `systemctl status nvidia-vgpud` and `systemctl status nvidia-vgpu-mgr`. (or something like `journalctl -fu nvidia-vgpud` to see the logs in real time)

You should get a notification when your windows VM starts saying "Nvidia license acquired"

---

For more help [Join VGPU-Unlock discord for Support](https://discord.com/invite/5rQsSV3Byq)

## Acknowledgements

This was heavily based and inspired in these three repositories:

- old NixOS module: https://github.com/danielfullmer/nixos-nvidia-vgpu
- the repo this was forked from: https://github.com/Yeshey/nixos-nvidia-vgpu_nixOS
- vgpu for newer nvidia drivers: https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher

