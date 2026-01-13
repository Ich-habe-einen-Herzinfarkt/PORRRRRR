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
        acppTargets = "generic";

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
            pkgs.llvmPackages.openmp
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
          pname = "PORRRRRR-cuda";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
            pkgs.cudaPackages.cudatoolkit
          ];

          buildInputs = [
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
            pkgs.cudaPackages.cudatoolkit
          ];
          runtimeDependencies = [ pkgs.cudaPackages.cudatoolkit  pkgs.cudaPackages.cuda_cudart ];
          # use generic for now due to issues compiling to cuda
          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithCuda or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=generic"
          ];

          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
          '';
        };

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

          # use generic for now
          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithRocm or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=generic"
          ];

          # Disable hardening flags that aren't compatible with GPU compilation
          hardeningDisable = [ "zerocallusedregs" ];

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
            pkgs.llvmPackages.openmp
            pkgs.mpi
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
            
            # Create mpiexec wrapper for easy MPI execution
            cat > $out/bin/PORRRRRR_bench_mpi << 'EOF'
#!/usr/bin/env bash
exec ${pkgs.mpi}/bin/mpiexec "$(dirname "$0")/PORRRRRR_bench" "$@"
EOF
            chmod +x $out/bin/PORRRRRR_bench_mpi
          '';
        };

        # ROCm benchmark
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
            pkgs.llvmPackages.openmp
            pkgs.mpi
          ];

          # use generic for now
          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithRocm or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=generic"
            "-DBUILD_BENCHMARKS=ON"
          ];

          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
            cp PORRRRRR_bench $out/bin/
            
            # Create mpiexec wrapper for easy MPI execution
            cat > $out/bin/PORRRRRR_bench_mpi << 'EOF'
#!/usr/bin/env bash
exec ${pkgs.mpi}/bin/mpiexec "$(dirname "$0")/PORRRRRR_bench" "$@"
EOF
            chmod +x $out/bin/PORRRRRR_bench_mpi
          '';
        };

        packages.bench-cuda = pkgs.stdenv.mkDerivation {
          pname = "PORRRRRR-bench-cuda";
          version = "0.1.0";

          inherit src;

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.cudaPackages.cudatoolkit 
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
          ];

          buildInputs = [
            (pkgs.adaptivecppWithCuda or pkgs.adaptivecpp)
            pkgs.cudaPackages.cudatoolkit 
            pkgs.gbenchmark
            pkgs.llvmPackages.openmp
            pkgs.mpi
          ];
          runtimeDependencies = [ pkgs.cudaPackages.cudatoolkit  pkgs.cudaPackages.cuda_cudart ];

          # use generic for now
          cmakeFlags = [
            "-DAdaptiveCpp_DIR=${pkgs.adaptivecppWithCuda or pkgs.adaptivecpp}/lib/cmake/AdaptiveCpp"
            "-DACPP_TARGETS=cuda:generic"
            "-DBUILD_BENCHMARKS=ON"
          ];

          hardeningDisable = [ "zerocallusedregs" ];

          installPhase = ''
            mkdir -p $out/bin
            cp PORRRRRR $out/bin/
            cp PORRRRRR_bench $out/bin/
            
            # Create mpiexec wrapper for easy MPI execution
            cat > $out/bin/PORRRRRR_bench_mpi << 'EOF'
#!/usr/bin/env bash
exec ${pkgs.mpi}/bin/mpiexec "$(dirname "$0")/PORRRRRR_bench" "$@"
EOF
            chmod +x $out/bin/PORRRRRR_bench_mpi
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
        apps.bench = {
          type = "app";
          program = "${self.packages.${system}.bench}/bin/PORRRRRR_bench";
        };
        apps.bench-mpi = {
          type = "app";
          program = "${self.packages.${system}.bench}/bin/PORRRRRR_bench_mpi";
        };
        apps.bench-rocm = {
          type = "app";
          program = "${self.packages.${system}.bench-rocm}/bin/PORRRRRR_bench";
        };
        apps.bench-rocm-mpi = {
          type = "app";
          program = "${self.packages.${system}.bench-rocm}/bin/PORRRRRR_bench_mpi";
        };
        apps.bench-cuda = {
          type = "app";
          program = "${self.packages.${system}.bench-cuda}/bin/PORRRRRR_bench";
        };
        apps.bench-cuda-mpi = {
          type = "app";
          program = "${self.packages.${system}.bench-cuda}/bin/PORRRRRR_bench_mpi";
        };
      });
}
