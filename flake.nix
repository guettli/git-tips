{
  description = "Development environment for git-tips";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          markdown
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            go-task
            mise
            markdownlint-cli
            prek
            pythonEnv
            shellcheck
            yamllint
          ];

          shellHook = ''
            prek install --prepare-hooks >/dev/null
          '';
        };
      });
}
