{
  description = "NixOS module which provides NVIDIA vGPU functionality";

  inputs = {
    nixpkgs = {
      url = "https://github.com/NixOS/nixpkgs/archive/c0d0be00d4ecc4b51d2d6948e37466194c1e6c51.tar.gz"; # a working revision (09/07/2024)
    };
  };

  outputs = { self, nixpkgs,... }@inputs: 
    let

    in {
      nixosModules.nvidia-vgpu = import ./default.nix inputs;
    };
}


