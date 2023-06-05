{
  description = "NixOS module which provides NVIDIA vGPU functionality";

  inputs.frida.url = "github:itstarsun/frida-nix";

  outputs = { self, frida }: {
    nixosModules.nvidia-vgpu = import ./default.nix frida;
  };
}
