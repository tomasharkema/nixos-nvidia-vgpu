{
  description = "NixOS module which provides NVIDIA vGPU functionality";

  # Changed to use my fork because of the "Python version mismatch" error.
  # SO in my fork it uses channel 23.05 instead of unstable. But there should be a better way to approach this.
  inputs.frida.url = "github:Yeshey/frida-nix";

  outputs = { self, frida }: {
    nixosModules.nvidia-vgpu = import ./default.nix frida;
  };
}

