{ inputs, pkgs, lib, project, utils, ghc }:

let

  allTools = {
    "ghc966".cabal                   = project.projectVariants.ghc966.tool "cabal" "latest";
    "ghc966".haskell-language-server = project.projectVariants.ghc966.tool "haskell-language-server" "latest";
  };

  tools = allTools.${ghc};

  shell = project.shellFor {
    name = "plinth-${project.args.compiler-nix-name}";

    buildInputs = [
      tools.cabal
      tools.haskell-language-server

      pkgs.git
      pkgs.curl
      pkgs.which
    ];

    withHoogle = true;

    shellHook = ''
      export PS1="\n\[\033[1;32m\][nix-shell:\w]\$\[\033[0m\] "
    '';
  };

in

shell
