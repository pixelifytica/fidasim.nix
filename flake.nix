{
  description = "Nix flake to install FIDASIM";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/b62426f57f9200f2af566998f1fdd9b23cccb185";
  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (system: {
        default = self.packages.${system}.fidasim;
        hdf5 =
          (pkgs.${system}.hdf5_1_10.override {
            cppSupport = false;
            enableShared = false;
          }).overrideAttrs
            (prev: {
              nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.${system}.gfortran ];
              dontDisableStatic = true;
              configureFlags = prev.configureFlags ++ [ "--enable-fortran" ];
            });
        fidasim = pkgs.${system}.stdenv.mkDerivation (final: {
          pname = "fidasim";
          version = "2.0.0";
          src = pkgs.${system}.fetchFromGitHub {
            owner = "D3DEnergetic";
            repo = "FIDASIM";
            tag = "v${final.version}";
            hash = "sha256-/w5dqCwqn2bIsTi6ieLdKZb/uAHFvsB7S4s72S02pNI=";
          };
          patches = [ ./scipy.patch ];
          nativeBuildInputs =
            (with pkgs.${system}; [
              gnumake
              gfortran
              zlib
              python3
              git
            ])
            ++ [ self.packages.${system}.hdf5 ];
          makeFlags = [
            "HDF5_LIB=${self.packages.${system}.hdf5.out}/lib"
            "HDF5_INCLUDE=${self.packages.${system}.hdf5.dev}/include"
          ];
          buildFlags = [
            "src"
            "tables"
          ];
          installPhase = ''
            mkdir -p $out/bin
            cp fidasim tables/generate_tables $out/bin
            cp -R lib tables test docs $out
          '';
          meta = {
            homepage = "https://d3denergetic.github.io/FIDASIM/index.html";
            licence = pkgs.lib.licence.bsd3;
            mainProgram = "fidasim";
          };
        });
      });
      devShells = forAllSystems (system: {
        default = pkgs.${system}.mkShellNoCC {
          packages = [
            self.packages.${system}.fidasim
            (pkgs.${system}.python3.withPackages (
              ps: with ps; [
                numpy
                scipy
                scikit-image
                h5py
              ]
            ))
          ];
          env.PYTHONPATH = "${self.packages.${system}.fidasim}/lib/python";
        };
      });
    };
}
