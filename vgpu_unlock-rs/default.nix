{
  lib,
  stdenv,
  makeWrapper,
  bash,
  getopt,
  jq,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "vgpu_unlock-rs";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "mbilker";
    repo = "vgpu_unlock-rs";
    rev = "v${version}";
    hash = "sha256-N/JtAvwiEyGxh41KkxVyCR/utewOF1MrAjsTaVoekzM=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  cargoHash = "";
  postPatch = ''
    ln -s ${./Cargo.lock} Cargo.lock
  '';
  # buildInputs = [(pythonPackages.python.withPackages (p: [p.frida-python]))];

  # postPatch = ''
  #   substituteInPlace vgpu_unlock \
  #     --replace /bin/bash ${pkgs.bash}/bin/bash
  # '';

  # installPhase = "install -Dm755 vgpu_unlock $out/bin/vgpu_unlock";
}
