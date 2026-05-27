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
      packages = forAllSystems (
        system:
        let
          version = "2.0.0";
          src = pkgs.${system}.fetchFromGitHub {
            owner = "D3DEnergetic";
            repo = "FIDASIM";
            tag = "v${version}";
            hash = "sha256-/w5dqCwqn2bIsTi6ieLdKZb/uAHFvsB7S4s72S02pNI=";
          };
        in
        {
          hdf5 = pkgs.${system}.stdenvNoCC.mkDerivation (final: {
            pname = "hdf5";
            version = "1.8.16";
            src = "${src}/deps/hdf5-${final.version}.tar.gz";
            nativeBuildInputs = with pkgs.${system}; [
              gcc13
              gnumake
              gfortran
              zlib
            ];
            configureFlags = [ "--enable-fortran" ];
            dontDisableStatic = true;
            postPatch = ''
              substituteInPlace configure --replace-fail "/bin/mv" "mv"
              substituteInPlace configure.ac --replace-fail "/bin/mv" "mv"
            '';
          });
          fidasim = pkgs.${system}.stdenv.mkDerivation (final: {
            inherit src;
            pname = "fidasim";
            version = "2.0.0";
            patches = [
              ./numpy.patch
              ./scipy.patch
            ];
            buildInputs =
              (with pkgs.${system}; [
                gnumake
                gfortran
                zlib
                git
              ])
              ++ [ self.packages.${system}.hdf5 ];
            propagatedNativeBuildInputs = [ pkgs.${system}.python3 ];
            makeFlags = [
              "FC=gfortran"
              "HDF5_LIB=${self.packages.${system}.hdf5}/lib"
              "HDF5_INCLUDE=${self.packages.${system}.hdf5}/include"
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
          default = self.packages.${system}.fidasim;
        }
      );
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
