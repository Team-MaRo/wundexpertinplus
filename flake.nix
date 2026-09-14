{
  description = "Wund Expertin Plus";

  inputs = {
    # Branch ref (not SHA): `nix flake update` resolves to the latest commit,
    # and Dependabot's nix ecosystem watches the resulting flake.lock.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Shared scripts + lib helpers. `follows` keeps a duplicate nixpkgs out
    # of flake.lock.
    nix-utils.url = "github:Team-MaRo/nix-utils";
    nix-utils.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-utils }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "riscv64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems
        (system: f (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nodejs_24
            pkgs.pnpm_10
            pkgs.curl
            pkgs.cacert
          ];
        };
      });

      packages = forAllSystems (pkgs:
        let
          wundexpertinplus = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "wundexpertinplus";
            version = "2.3.4"; # x-release-please-version
            src = ./.;

            nativeBuildInputs = [
              pkgs.nodejs-slim_24
              pkgs.pnpm_10
              pkgs.pnpmConfigHook
            ];

            pnpmDeps = pkgs.fetchPnpmDeps {
              inherit (finalAttrs) pname version src;
              pnpm = pkgs.pnpm_10;
              fetcherVersion = 3;
              hash = "sha256-aVRcRxhZ5LA6C/d6mjJ1Z9/K22asreyVYAldno3ag/c=";
            };

            # Skip fixupPhase. patchShebangs / patchELF would rewrite every
            # `#!/usr/bin/env node` and dynamic-loader path inside node_modules
            # to absolute /nix/store/...-nodejs/... paths, dragging the full
            # nodejs (with npm/headers), stdenv, perl, python, gcc-libs into
            # the runtime closure. The original `/usr/bin/env <prog>` shebangs
            # work at runtime via dockerTools.usrBinEnv + nodejs-slim_24 +
            # bashInteractive + coreutils + gnused.
            dontFixup = true;
            dontStrip = true;
            dontPatchShebangs = true;
            dontPatchELF = true;

            disallowedReferences = [ pkgs.nodejs_24 ];

            buildPhase = ''
              runHook preBuild

              pnpm run build

              # Drop devDependencies (~280 MB → ~40 MB) and pnpm's CAS mirror
              # (already hardlinked into the workspace).
              pnpm prune --prod
              rm -rf node_modules/.pnpm/node_modules

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              # Lay bundle at $out/opt/wundexpertinplus/* so adding this
              # derivation to streamLayeredImage's `contents` puts it straight
              # at /opt/wundexpertinplus/* in the image.
              mkdir -p $out/opt/wundexpertinplus
              cp -r build node_modules package.json $out/opt/wundexpertinplus/

              runHook postInstall
            '';
          });

          # docker/metadata-action labels (KEY=VAL\n…) serialised to JSON.
          labelsJson = builtins.getEnv "DOCKER_LABELS_JSON";
          labels = if labelsJson == "" then { } else builtins.fromJSON labelsJson;

          inherit (nix-utils.lib.oci) secondsToNanos createdFromDate;

          fixHistoryScript = nix-utils.packages.${pkgs.stdenv.hostPlatform.system}.fixOciImageHistory;

          # Healthcheck only hits localhost over plain HTTP, so strip
          # everything but TLS. `curlMinimal` upstream still keeps gss + scp
          # on in nixos-25.11; override directly.
          curlSlim = pkgs.curl.override {
            scpSupport = false;
            gssSupport = false;
            pslSupport = false;
            brotliSupport = false;
            zstdSupport = false;
            ldapSupport = false;
            rtmpSupport = false;
            http3Support = false;
            websocketSupport = false;
          };

          dockerImageStream = pkgs.dockerTools.streamLayeredImage {
            name = "d3strukt0r/wundexpertinplus";
            tag = "latest";

            # Default is epoch 0 — shows up as "Created: 56 years ago" in
            # `docker images`. Use the flake's last-modified date (commit
            # time on a clean tree) so identical sources produce an
            # identical config digest. `"now"` would change every build.
            created = createdFromDate self.lastModifiedDate;

            contents = [
              pkgs.dockerTools.usrBinEnv

              # /etc/passwd, /etc/group, /etc/nsswitch.conf. extraPasswdLines
              # appends our nonroot user to the default root + nobody entries.
              (pkgs.dockerTools.fakeNss.override {
                extraPasswdLines = [
                  "nonroot:x:65532:65532:nonroot:/opt/wundexpertinplus:/sbin/nologin"
                ];
                extraGroupLines = [
                  "nonroot:x:65532:"
                ];
              })

              # bashInteractive (not plain bash) because nodejs-slim_24
              # transitively pulls bash-interactive into the closure anyway;
              # adding bash on top would ship two shells. coreutils + gnused
              # cover the `dirname / sed / uname / [` calls in pnpm's
              # node_modules/.bin/* shims.
              pkgs.bashInteractive
              pkgs.coreutils
              pkgs.gnused
              pkgs.which
              pkgs.nodejs-slim_24
              curlSlim
              wundexpertinplus
            ];

            # /tmp needs explicit creation: dockerTools-created dirs default
            # to root:root 755, and uid 65532 needs to write tmp files.
            # 1777 = sticky world-writable (FHS).
            extraCommands = ''
              mkdir -p tmp
              chmod 1777 tmp
            '';

            # Hardening: app files stay root:root, world-readable. Runtime
            # user (65532) can only write to /tmp.
            enableFakechroot = true;

            config = {
              User = "65532:65532";
              WorkingDir = "/opt/wundexpertinplus";
              Env = [
                "NODE_ENV=production"
                "PORT=3000"
                # .bin first so `react-router-serve` resolves via the pnpm shim.
                "PATH=/opt/wundexpertinplus/node_modules/.bin:/bin:/usr/bin"
                # Node ships its own Mozilla CA bundle compiled in.
              ];
              ExposedPorts = { "3000/tcp" = { }; };
              Cmd = [ "react-router-serve" "./build/server/index.js" ];
              Healthcheck = {
                Test = [ "CMD" "curl" "-fsS" "http://localhost:3000/" ];
                Interval = secondsToNanos 30;
                Timeout = secondsToNanos 3;
                StartPeriod = secondsToNanos 5;
              };
              Labels = labels;
            };
          };

          dockerImage = pkgs.runCommand "wundexpertinplus-image.tar" { } ''
            ${dockerImageStream} | ${fixHistoryScript} > $out
          '';
        in
        {
          inherit wundexpertinplus dockerImage dockerImageStream;
          default = dockerImage;
        });
    };
}
