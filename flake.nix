{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    treefmt-nix,
    ...
  }: let
    inherit (nixpkgs) lib;

    forEachSystem = f:
      lib.genAttrs ["aarch64-darwin" "x86_64-linux"]
      (system:
        f (import nixpkgs {
          inherit system;
          overlays = [(import rust-overlay)];
        }));

    # The one toolchain, which the shell and the packages share.
    rust = pkgs: pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

    # One environment, entered by the shell and by the checks alike. The
    # TypeScript compiler is pinned by pnpm instead, since editors look for it
    # in node_modules.
    tools = pkgs: with pkgs; [(rust pkgs) nodejs pnpm biome just curl jq];
  in {
    packages = forEachSystem (pkgs: {
      # Built from the Rust sources alone, so that a new wording of the spec
      # or a change to the TypeScript participant changes no binary.
      agentwire-relay =
        (pkgs.makeRustPlatform {
          cargo = rust pkgs;
          rustc = rust pkgs;
        }).buildRustPackage {
          pname = "agentwire-relay";
          version = "0.1.0";
          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              (lib.fileset.fileFilter (file: file.hasExt "rs" || file.name == "Cargo.toml") ./.)
              ./Cargo.lock
              ./relay/people.html
            ];
          };
          cargoLock.lockFile = ./Cargo.lock;
          cargoBuildFlags = ["-p" "agentwire-relay"];
          cargoTestFlags = ["-p" "agentwire-relay" "-p" "agentwire"];
          # A binary names the toolchain's sources, in panic messages, which
          # would pull all of it into whatever runs it.
          nativeBuildInputs = [pkgs.removeReferencesTo];
          # The HTTP client loads the system's certificates even for the tests'
          # local relay, and the build sandbox has none.
          nativeCheckInputs = [pkgs.cacert];
          postFixup = "remove-references-to -t ${rust pkgs} $out/bin/agentwire-relay";
          disallowedReferences = [(rust pkgs)];
          meta.mainProgram = "agentwire-relay";
        };

      # The spec and the script the relay serves, apart from its binary, so
      # that a new wording changes no binary and restarts no relay.
      agentwire-relay-files = pkgs.runCommandLocal "agentwire-relay-files" {} ''
        mkdir $out
        cp ${./agentwire} $out/agentwire
        cp ${./agentwire.md} $out/agentwire.md
      '';
    });

    nixosModules.relay = import ./nixos-module.nix self;

    # Every language in the tree, behind one command. The global pre-commit
    # hook checks a repository by running this, so a language left out here is
    # a language nothing checks.
    formatter = forEachSystem (pkgs:
      treefmt-nix.lib.mkWrapper pkgs {
        projectRootFile = "flake.nix";
        programs.biome.enable = true;
        # treefmt names the files itself, and Biome would look for the ignore
        # file next to the copy in the store. Biome checks the configuration as
        # it loads, and treefmt-nix's schema lags behind it.
        programs.biome.validate.enable = false;
        programs.biome.settings = removeAttrs (builtins.fromJSON (builtins.readFile ./biome.json)) ["vcs"];
        programs.alejandra.enable = true;
        programs.rustfmt.enable = true;
        programs.just.enable = true;
        programs.shellcheck.enable = true;
        programs.shfmt.enable = true;
        # direnv reads it, no shell runs it.
        settings.formatter.shellcheck.excludes = [".envrc"];
        # The script has no extension, since it is run as `sh agentwire`.
        settings.formatter.shellcheck.includes = ["*.sh" "agentwire"];
        settings.formatter.shfmt.includes = ["*.sh" "agentwire"];
      });

    devShells = forEachSystem (pkgs: {
      default = pkgs.mkShell {packages = tools pkgs;};
    });
  };
}
