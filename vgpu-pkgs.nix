{pkgs ? import <nixpkgs> {} }:

pkgs.callPackage ./vgpu_unlock-rs {}
