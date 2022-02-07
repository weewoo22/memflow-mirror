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

          buildInputs = with pkgs; [
            (rust-bin.stable."1.58.1".default.override {
              # Extra toolchain components to install
              # See: https://rust-lang.github.io/rustup/concepts/components.html#components
              extensions = [ "rust-src" "rls" ];
            })
            # cargo install cargo-edit requires OpenSLL
            openssl
            # Compiling Rust OpenSSL on Linux requires pkg-config utility to find OpenSSL
            pkg-config

            SDL2
          ];
        };
      }
    );
}
