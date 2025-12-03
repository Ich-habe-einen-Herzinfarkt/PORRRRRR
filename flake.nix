{
  description = "SYCL Edge Detection with AdaptiveCpp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = builtins.elem system [ "x86_64-linux" "aarch64-linux" ];
            rocmSupport = system == "x86_64-linux";
          };
        };

        # Select the appropriate AdaptiveCpp variant based on platform support
        adaptivecpp =
          if pkgs.config.cudaSupport or false then
            pkgs.adaptivecppWithCuda or pkgs.adaptivecpp
          else if pkgs.config.rocmSupport or false then
            pkgs.adaptivecppWithRocm or pkgs.adaptivecpp
          else
            pkgs.adaptivecpp;

        # Determine ACPP_TARGETS based on available backends
        acppTargets =
          if pkgs.config.cudaSupport or false then
            "generic"  # generic works best with CUDA
          else if pkgs.config.rocmSupport or false then
            "generic"  # generic works best with ROCm
          else
            "omp";     # CPU-only fallback

        # Filter source to exclude build artifacts
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let
              baseName = baseNameOf path;
            in
            !(baseName == "build" ||
              baseName == ".git" ||
              baseName == "result" ||
              pkgs.lib.hasSuffix ".o" baseName ||
              pkgs.lib.hasSuffix ".a" baseName);
        };

      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            adaptivecpp
          ];

          buildInputs = [
            adaptivecpp
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=${acppTargets}"
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "SYCL-based edge detection using Sobel filter";
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.cmake
            adaptivecpp
          ];

          shellHook = ''
            export AdaptiveCpp_DIR="${adaptivecpp}/lib/cmake/AdaptiveCpp"
            export ACPP_TARGETS="${acppTargets}"
            echo "AdaptiveCpp development environment"
            echo "  AdaptiveCpp: ${adaptivecpp.name}"
            echo "  ACPP_TARGETS: $ACPP_TARGETS"
            echo ""
            echo "To build:"
            echo "  mkdir -p build && cd build"
            echo "  cmake .. -DAdaptiveCpp_DIR=\$AdaptiveCpp_DIR -DACPP_TARGETS=\$ACPP_TARGETS"
            echo "  cmake --build ."
          '';
        };

        # Expose all three variants for explicit selection
        packages.cpu = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-cpu";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.adaptivecpp
          ];

          buildInputs = [
            pkgs.adaptivecpp
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=omp"
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
          '';
        };

        packages.cuda = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithCuda or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=generic"
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
          '';
        };

        packages.rocm = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithRocm or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithRocm or pkgs.adaptivecpp)
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithRocm or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=generic"
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/.PORRRRRR-unwrapped
            # Wrap the binary to filter out CUDA backend loading warnings
            # is this stupid? yes. But for *some* reason even the rocm package seems to be trying to load cuda despite working perfectly fine without them...
            # probably some issue in adaptivecppWithRocm, but I can't be bothered to debug it and fix it properly right now
            cat > $out/bin/PORRRRRR <<'WRAPPER'
#!/bin/bash
DIR="$(dirname "$0")"
exec "$DIR/.PORRRRRR-unwrapped" "$@" 2> >(grep -v "librt-backend-cuda.so" >&2)
WRAPPER
            chmod +x $out/bin/PORRRRRR
          '';
        };
      });
}
