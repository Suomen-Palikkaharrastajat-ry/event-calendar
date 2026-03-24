let
  shell =
    { pkgs, config, ... }:

    {
      # Downgrade PocketBase to match production (0.31.0). See overlays.nix.
      overlays = [ (import ./overlays.nix) ];

      # https://devenv.sh/basics/
      env.GREET = "devenv";

      # JavaScript / Node.js (for Vite, pnpm, elm-test, etc.)
      languages.javascript.enable = true;
      languages.javascript.pnpm.enable = true;

      # Elm 0.19 tools
      languages.elm.enable = true;

      # Haskell (GHC + cabal + HLS via languages.haskell.enable)
      # Custom packages (qrcode-core, qrcode-juicypixels) defined in overrides.nix.
      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;

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
        entr # file watcher for make watch
        haskell.packages.ghc96.hlint
        haskell.packages.ghc96.fourmolu
        elmPackages.elm-review
        elmPackages.elm-json
        # elm-format is provided by languages.elm.enable
      ];

      # https://devenv.sh/scripts/
      scripts.hello.exec = "echo hello from $GREET";

      # ── PocketBase local instance ────────────────────────────────────────────────
      # PocketBase has no built-in devenv service; run it as a process.
      # Data dir: .devenv/state/pocketbase/data  (already bootstrapped)
      # Schema migrations: fixtures/pb_migrations/ (run `pocketbase migrate` to apply)
      # Admin UI: http://127.0.0.1:8090/_/
      processes.pocketbase = {
        exec = ''
          pocketbase serve \
            --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" \
            --migrationsDir="$DEVENV_ROOT/fixtures/pb_migrations" \
            --http=127.0.0.1:8090
        '';
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
        echo ""
        echo "── event-calendar dev environment ───────────────────"
        echo "  GHC:    $(ghc --version)"
        echo "  Cabal:  $(cabal --version | head -1)"
        echo "  Elm:    $(elm --version)"
        echo "  pnpm:   $(pnpm --version)"
        echo ""
        echo "  make dist  — build statics + Elm app"
        echo "  devenv up  — start all services"
        echo "    PocketBase: http://127.0.0.1:8090"
        echo "    Keycloak:   http://localhost:8080"
        echo ""
      '';

      # See full reference at https://devenv.sh/reference/options/
    };

in
{
  profiles.shell.module = {
    imports = [ shell ];
  };
}
