# Every check: the formatting, the lints, the tests, the spec's examples run
# with curl against a relay of its own, and the packages as they deploy.
ci:
    #!/usr/bin/env bash
    set -euo pipefail
    nix fmt -- --ci
    pnpm install --frozen-lockfile
    biome check
    pnpm exec tsc -p participant
    cargo clippy --workspace --all-targets -- -D warnings
    RUSTDOCFLAGS="-D warnings" cargo doc --workspace --no-deps
    cargo test --quiet --workspace
    cargo build --quiet -p agentwire-relay
    # On a port the system picks, so that several checkouts check at once.
    log=$(mktemp)
    AGENTWIRE_ADDRESS=127.0.0.1:0 "${CARGO_TARGET_DIR:-target}/debug/agentwire-relay" 2>"$log" &
    relay=$!
    trap 'kill $relay; rm -f "$log"' EXIT
    until address=$(grep -om1 '127\.0\.0\.1:[0-9]*' "$log"); do
        kill -0 $relay
        sleep 0.1
    done
    tests/transport.sh "http://$address"
    sh tests/agentwire.sh "http://$address"
    node tests/secrets.ts
    nix build --no-link .#agentwire-relay .#agentwire-relay-files

# The relay, locally, on port 8790, with its sessions in memory.
dev:
    cargo run -p agentwire-relay
