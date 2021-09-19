{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell rec {
  nativeBuildInputs = with pkgs; [
    erlangR24 elixir jupyter
    python39 python39Packages.jupyterlab
  ];

  shellHook = ''
    PATH=$HOME/.mix/escripts:$PATH NIX_ENFORCE_PURITY=0 zsh
  '';
}

