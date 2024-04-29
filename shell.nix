with import <nixpkgs> {};

# Tools to run the https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher repo
# doesnt have mscompress (https://github.com/stapelberg/mscompress) tho :( 

pkgs.mkShell {
  nativeBuildInputs = [
    p7zip
    unzip
    coreutils
    bash
    zstd
  ];
}
