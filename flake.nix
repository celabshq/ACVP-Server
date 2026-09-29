{
  description = "Dev shell for building and running the ACVP-Server gen/vals";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        dotnet = pkgs.dotnet-sdk_8;

        # Run from anywhere inside the repository.
        root = ''"$(git rev-parse --show-toplevel)"'';

        # The Orleans silo that performs all crypto for the gen/vals. Must be
        # running while `acvp-genval` is used.
        acvp-orleans = pkgs.writeShellScriptBin "acvp-orleans" ''
          cd ${root}/gen-val/samples/NIST.CVP.ACVTS.Orleans.ServerHost
          exec dotnet run -c Release -- --console "$@"
        '';

        # The GenValAppRunner, e.g.
        #   acvp-genval -g /abs/path/registration.json
        # Output files are written next to the registration file. Paths must be
        # absolute since the runner is executed from its project directory.
        acvp-genval = pkgs.writeShellScriptBin "acvp-genval" ''
          cd ${root}/gen-val/samples/GenValAppRunner/src
          exec dotnet run -c Release -- "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            dotnet
            pkgs.git
            pkgs.jq
            acvp-orleans
            acvp-genval
          ];

          DOTNET_ROOT = "${dotnet}/share/dotnet";
          DOTNET_CLI_TELEMETRY_OPTOUT = "1";
          DOTNET_NOLOGO = "1";
          DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1";

          # The build expects the files from `_config` at the repository root
          # (see "Sym Links" in the README).
          shellHook = ''
            top=$(git rev-parse --show-toplevel)
            for f in Directory.Build.props Directory.Packages.props; do
              [ -e "$top/$f" ] || ln -s "./_config/$f" "$top/$f"
            done
          '';
        };
      }
    );
}
