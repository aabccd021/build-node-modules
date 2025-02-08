{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { nixpkgs, treefmt-nix, self }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      buildNodeModules = pkgs: packageJson: lockJson:
        let
          locks = pkgs.runCommandNoCC "locks" { } ''
            mkdir -p $out
            cp -L ${packageJson} $out/package.json
            cp -L ${lockJson} $out/package-lock.json
          '';
        in
        pkgs.buildNpmPackage {
          name = "node_modules";
          src = locks;
          npmDeps = pkgs.importNpmLock { npmRoot = locks; };
          npmConfigHook = pkgs.importNpmLock.npmConfigHook;
          dontNpmBuild = true;
          installPhase = "mkdir $out && cp -r node_modules/* $out";
        };

      exampleNodeModules = buildNodeModules pkgs ./example/package.json ./example/package-lock.json;

      packages = {
        exampleNodeModules = exampleNodeModules;
        formatting = treefmtEval.config.build.check self;
        snapshot-test = pkgs.runCommandNoCCLocal "snapshot-test" { } ''
          mkdir -p $out/snapshot/nested
          echo "foo" > $out/snapshot/nested/file.txt
        '';
      };

      gcroot = packages // {
        gcroot-all = pkgs.linkFarm "gcroot-all" packages;
      };

      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixpkgs-fmt.enable = true;
        programs.prettier.enable = true;
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
        settings.formatter.shellcheck.options = [ "-s" "sh" ];
      };

    in

    {

      packages.x86_64-linux = gcroot;

      checks.x86_64-linux = gcroot;

      formatter.x86_64-linux = treefmtEval.config.build.wrapper;

      lib.buildNodeModules = buildNodeModules;


    };
}
