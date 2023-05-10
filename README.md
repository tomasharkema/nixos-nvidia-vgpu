# NixOS NVIDIA vGPU Module

Example usage:
```nix
{
  # Optionally replace "master" with a particular revision to pin this dependency.
  # This repo also provides the module in a "Nix flake" under `nixosModules.nvidia-vgpu` output
  imports = [ (builtins.fetchTarball "https://github.com/Yeshey/nixos-nvidia-vgpu_nixOS22.11_WIP/archive/master.tar.gz") ];

  hardware.nvidia = {
    vgpu = {
      enable = true; # Install NVIDIA KVM vGPU + GRID merged driver for consumer cards with vgpu unlocked.
      unlock.enable = true; # Activates systemd services to enable vGPU functionality on using DualCoder/vgpu_unlock project.
      fastapi-dls = { # For the license server
        enable = true;
        local_ipv4 = "192.168.1.81"; # Your local IP
        timezone = "Europe/Lisbon"; # Your timezone (needs to be the same as the tz in the VM)
      };
    };
  };
}
```
This currently downlaods and installes a merged driver that I built.


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