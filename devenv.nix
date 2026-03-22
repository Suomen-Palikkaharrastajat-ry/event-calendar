let
  shell =
    { pkgs, config, ... }:

    {
      # Downgrade PocketBase to match production (0.31.0).
      # Override is needed because nixpkgs/master tracks the latest release.
      # Hashes sourced from nixpkgs commit 594420d4 (pocketbase: 0.30.4 -> 0.31.0).
      overlays = [
        (final: prev: {
          pocketbase = prev.pocketbase.overrideAttrs (
            finalAttrs: old: {
              version = "0.31.0";
              src = final.fetchFromGitHub {
                owner = "pocketbase";
                repo = "pocketbase";
                rev = "v${finalAttrs.version}";
                hash = "sha256-YCYihhPq24JdJKAU8zr4h4z131zj4BN3Qh/y5tHmyRs=";
              };
              vendorHash = "sha256-wsPJIlsq4Q26cce69a0oqEalfDrNIMVFt8ufdj+WId4=";
            }
          );
        })
      ];

      # https://devenv.sh/basics/
      env.GREET = "devenv";

      # JavaScript / Node.js (for Vite, pnpm, elm-test, etc.)
      languages.javascript.enable = true;
      languages.javascript.pnpm.enable = true;

      # Elm 0.19 tools
      languages.elm.enable = true;

      # Haskell (GHC + cabal + tools)
      # Uses ghcWithPackages to provide a GHC with all statics/ and planet/ dependencies
      languages.haskell.enable = true;
      languages.haskell.package =
        (pkgs.haskellPackages.override {
          overrides = self: super: {
            qrcode-core = super.callPackage (
              {
                mkDerivation,
                base,
                binary,
                bytestring,
                case-insensitive,
                containers,
                dlist,
                primitive,
                text,
                vector,
              }:
              mkDerivation {
                pname = "qrcode-core";
                version = "0.9.11";
                sha256 = "sha256-bYbshOLd8XarNGzIbopFLmc/3KAdYkHDH++l0cm2iaI=";
                libraryHaskellDepends = [
                  base
                  binary
                  bytestring
                  case-insensitive
                  containers
                  dlist
                  primitive
                  text
                  vector
                ];
              }
            ) { };
            qrcode-juicypixels = super.callPackage (
              {
                mkDerivation,
                base,
                base64-bytestring,
                bytestring,
                JuicyPixels,
                qrcode-core,
                text,
                vector,
              }:
              mkDerivation {
                pname = "qrcode-juicypixels";
                version = "0.8.7";
                sha256 = "sha256-4tZ8n18LK790VNUMkbSNDu4Jh7lc/2PvqVhQh1BIb/M=";
                libraryHaskellDepends = [
                  base
                  base64-bytestring
                  bytestring
                  JuicyPixels
                  qrcode-core
                  text
                  vector
                ];
              }
            ) { };
          };
        }).ghcWithPackages
          (
            ps: with ps; [
              # Core
              aeson
              http-client
              http-client-tls
              http-conduit
              time
              directory
              filepath
              text
              bytestring
              containers
              vector
              unordered-containers
              scientific
              uuid
              base64-bytestring
              async
              # Feed generation
              feed
              blaze-html
              blaze-markup
              # Timezone
              tz
              tzdata
              # Image / QR (statics/)
              qrcode-core
              qrcode-juicypixels
              # XML / Atom (planet/)
              xml-conduit
              xml-types
              tagsoup
              uri-bytestring
              toml-parser
              # Testing
              tasty
              tasty-hunit
              tasty-quickcheck
              # Formatter
              fourmolu
              # Linter
              hlint
            ]
          );

      dotenv.enable = true;

      # ── PocketBase URL (statics + Elm frontend) ──────────────────────────────────
      # Both the statics generator and the Elm frontend default to the production
      # database. Use the *-local Makefile targets to target the local devenv
      # PocketBase instance instead (requires: devenv up):
      #
      #   make statics-local      # Haskell generator → local PocketBase
      #   make elm-dev-local      # Vite dev server   → local PocketBase
      #   make elm-build-local    # Production build  → local PocketBase
      #   make dist-local         # Both of the above combined
      #
      # Env vars used internally by those targets:
      #   POCKETBASE_URL          → statics generator (Haskell, runtime)
      #   VITE_POCKETBASE_URL     → Elm SPA (Vite, build-time)
      #
      # To always use the local instance in your devenv shell, add to devenv.local.nix:
      #   { env.POCKETBASE_URL = "http://127.0.0.1:8090";
      #     env.VITE_POCKETBASE_URL = "http://127.0.0.1:8090"; }
      # Or set both in a .env file (dotenv.enable = true above handles loading it).

      # Extra tools available in devenv shell
      packages = with pkgs; [
        pocketbase # local PocketBase instance for testing
        treefmt # universal formatter runner
        cabal-install # Haskell build tool (cabal CLI)
        # elm-format is provided by languages.elm.enable
      ];

      # https://devenv.sh/scripts/
      scripts.hello.exec = "echo hello from $GREET";

      # ── PocketBase local instance ────────────────────────────────────────────────
      # PocketBase has no built-in devenv service; run it as a process.
      # Data dir: .devenv/state/pocketbase/data  (already bootstrapped)
      # Schema migrations: pb_migrations/ (run `pocketbase migrate` to apply)
      # Admin UI: http://127.0.0.1:8090/_/
      processes.pocketbase = {
        # types.d.ts is auto-generated by PocketBase's JSVM plugin for IDE support but
        # older PocketBase versions try to execute it as a JS migration and panic.
        # Delete it before every start so only real *.js migrations are discovered.
        exec = "pocketbase serve --dir=$DEVENV_ROOT/.devenv/state/pocketbase/data --http=127.0.0.1:8090 --migrationsDir=$DEVENV_ROOT/fixtures/pb_migrations";
      };

      # ── Keycloak OIDC provider ───────────────────────────────────────────────────
      # Admin UI: http://localhost:8080  (admin / admin)
      # Realm "pocketbase" imported from devenv-fixtures-keycloak.json
      services.keycloak = {
        enable = true;
        initialAdminPassword = "admin";
        settings = {
          hostname = "localhost";
          http-port = 8080;
          http-enabled = true;
          http-relative-path = "/";
        };
        realms.pocketbase = {
          path = "./devenv-fixtures-keycloak.json";
          import = true;
        };
      };

      enterShell = ''
        hello
        pnpm --version
        echo "GHC: $(ghc --version)"
        echo "cabal: $(cabal --version | head -1)"
        echo "Elm: $(elm --version)"
        echo "PocketBase: http://127.0.0.1:8090  (run: devenv up)"
        echo "Keycloak:   http://localhost:8080   (run: devenv up)"
      '';

      # See full reference at https://devenv.sh/reference/options/
    };

in
{
  profiles.shell.module = {
    imports = [ shell ];
  };
}
