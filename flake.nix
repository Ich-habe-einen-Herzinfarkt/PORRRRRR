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
        # Default to generic for JIT compilation (portable but has startup overhead)
        acppTargets =
          if pkgs.config.cudaSupport or false then
            "generic"
          else if pkgs.config.rocmSupport or false then
            "generic"
          else
            "omp";

        # AOT target architectures
        # ROCm: gfx1100 = RX 7900 series, gfx1102 = RX 7800/7700 series, gfx1030 = RX 6800/6900 series
        # CUDA: sm_89 = RTX 40 series, sm_86 = RTX 30 series, sm_75 = RTX 20 series
        #
        # NOTE: AOT compilation for ROCm may fail due to LLVM version mismatches in nixpkgs.
        # If you encounter errors like "Invalid attribute group entry", use the JIT variants instead:
        #   nix run .#rocm-jit
        #   nix run .#cuda-jit
        defaultRocmArch = "gfx1102";  # RX 7800 XT
        defaultCudaArch = "sm_89";    # RTX 40 series

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

        # CUDA with AOT compilation
        packages.cuda = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-cuda";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
          ];

          # AOT compilation for CUDA - specify architecture explicitly
          # Use cuda.explicit-multipass for AOT compilation
          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithCuda or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=cuda:${defaultCudaArch}"
          ];

          # Disable hardening flags that aren't compatible with GPU compilation
          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
          '';
        };

        # ROCm with AOT compilation
        packages.rocm = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-rocm";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithRocm or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithRocm or pkgs.adaptivecpp)
          ];

          # AOT compilation for HIP/ROCm - specify architecture explicitly
          # Use hip.explicit-multipass for AOT compilation
          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithRocm or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=hip:${defaultRocmArch}"
          ];

          # Disable hardening flags that aren't compatible with GPU compilation
          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
          '';
        };

        # JIT variants (portable, but has startup overhead)
        packages.rocm-jit = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-rocm-jit";
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
            cat > $out/bin/PORRRRRR <<'WRAPPER'
#!/bin/bash
DIR="$(dirname "$0")"
exec "$DIR/.PORRRRRR-unwrapped" "$@" 2> >(grep -v "librt-backend-cuda.so" >&2)
WRAPPER
            chmod +x $out/bin/PORRRRRR
          '';
        };

        packages.cuda-jit = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-cuda-jit";
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

        # Benchmark variants
        packages.bench = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-bench";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            adaptivecpp
          ];

          buildInputs = [
            adaptivecpp
            pkgs.gbenchmark
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=${acppTargets}"
            "-DBUILD_BENCHMARKS=ON"
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
            cp PORRRRRR_bench $out/bin/
          '';
        };

        # ROCm benchmark with AOT compilation
        packages.bench-rocm = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-bench-rocm";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithRocm or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithRocm or pkgs.adaptivecpp)
            pkgs.gbenchmark
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithRocm or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=hip:${defaultRocmArch}"
            "-DBUILD_BENCHMARKS=ON"
          ];

          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
            cp PORRRRRR_bench $out/bin/
          '';
        };

        # CUDA benchmark with AOT compilation
        packages.bench-cuda = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-bench-cuda";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
            pkgs.gbenchmark
          ];

          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithCuda or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=cuda:${defaultCudaArch}"
            "-DBUILD_BENCHMARKS=ON"
          ];

          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
            cp PORRRRRR_bench $out/bin/
          '';
        };

        # Apps for `nix run` - map package names to the correct binary
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/PORRRRRR";
        };
        apps.cpu = {
          type = "app";
          program = "${self.packages.${system}.cpu}/bin/PORRRRRR";
        };
        apps.cuda = {
          type = "app";
          program = "${self.packages.${system}.cuda}/bin/PORRRRRR";
        };
        apps.rocm = {
          type = "app";
          program = "${self.packages.${system}.rocm}/bin/PORRRRRR";
        };
        apps.cuda-jit = {
          type = "app";
          program = "${self.packages.${system}.cuda-jit}/bin/PORRRRRR";
        };
        apps.rocm-jit = {
          type = "app";
          program = "${self.packages.${system}.rocm-jit}/bin/PORRRRRR";
        };
        apps.bench = {
          type = "app";
          program = "${self.packages.${system}.bench}/bin/PORRRRRR_bench";
        };
        apps.bench-rocm = {
          type = "app";
          program = "${self.packages.${system}.bench-rocm}/bin/PORRRRRR_bench";
        };
        apps.bench-cuda = {
          type = "app";
          program = "${self.packages.${system}.bench-cuda}/bin/PORRRRRR_bench";
        };
      });
}
