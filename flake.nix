{
  inputs = {
    flake-utils.url = github:numtide/flake-utils;
    rust-overlay.url = github:oxalica/rust-overlay;
    memflow.url = github:memflow/memflow-nixos;
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
          # crossSystem = { config = "x86_64-w64-mingw32"; };
        };
        lib = pkgs.lib;

        # Collect overridden memflow package outputs into this variable
        memflowPkgs = builtins.mapAttrs
          (name: package:
            (package.overrideAttrs
              (super: {
                # Turn these on for debugging
                # dontStrip = true;
                # buildType = "debug";
              })
            )
          )
          inputs.memflow.packages.${system};
      in
      {
        devShell = pkgs.mkShell {
          MEMFLOW_EXTRA_PLUGIN_PATHS = with memflowPkgs; lib.concatStringsSep ":" [
            "${memflow-kvm}/lib/" # KVM Connector
            "${memflow-win32}/lib/" # Win32 Connector plugin
          ];
          # CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = with pkgs.pkgsCross.mingwW64.stdenv;
          #   "${cc}/bin/${cc.targetPrefix}gcc";

          # See: https://github.com/nix-community/naersk/issues/181#issuecomment-874352470
          shellHook = ''
            export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-C link-args=''$(echo $NIX_LDFLAGS | tr ' ' '\n' | grep -- '^-L' | tr '\n' ' ')"
            export NIX_LDFLAGS=
          '';
          buildInputs = with pkgs; with pkgsCross.mingwW64.windows; [
            (rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
              # Extra toolchain components to install
              # See: https://rust-lang.github.io/rustup/concepts/components.html#components
              extensions = [
                "rust-src"
                "rls"
              ];
              targets = [
                # Needed for compiling Windows guest executable
                "x86_64-pc-windows-gnu"
              ];
            }))
            openssl # cargo install cargo-edit requires OpenSLL
            pkg-config # Compiling Rust OpenSSL on Linux requires pkg-config utility to find OpenSSL
            SDL2 # The mirror viewer requires SDL 2
            # "= note: /nix/store/...-x86_64-w64-mingw32-binutils-.../bin/x86_64-w64-mingw32-ld: cannot find -l:libpthread.a"
            mingw_w64_pthreads
            # pthreads
          ];
          nativeBuildInputs = with pkgs; [
            # "error: linker `x86_64-w64-mingw32-gcc` not found"
            pkgsCross.mingwW64.stdenv.cc
          ];
        };
      }
    );
}
