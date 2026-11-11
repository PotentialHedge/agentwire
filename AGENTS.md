# agentwire

Vibe Together's transport and nothing else, named agentwire for now:
the session log, participants and typed entries over HTTP.
It is developed in the collective Potential Hedge, as part of Vibe Together (`PotentialHedge/vibetogether`, `~/dev/vibetogether`), whose design is private to the collective, in `PotentialHedge/collective` under `projects/vibetogether/`: read it before working here.
It is a repository of its own, apart from Vibe Together, Luis's decision (2026-11-11).

The repository holds the spec (`agentwire.md`), the relay (`relay/`), the `agentwire` script,
and the participant library in TypeScript and in Rust (`participant/`).
The Rust crate, `agentwire`, holds the types of what goes over the wire, which the relay shares, and with its default `client` feature, the client.
The repository's root is the TypeScript package `agentwire`, which exports the participant.
Vibe Together depends on both by a pinned commit: Cargo by `git` and `rev`, pnpm by `github:PotentialHedge/agentwire#<commit>`.

The stack:

- One Nix flake for the relay's package, its files, its NixOS module (`nixosModules.relay`), the shell and the formatter.
- One Cargo workspace, the relay and the participant, and the relay in Rust on the tokio ecosystem, agnostic to where it runs, Luis's decision.
- `just ci` runs every check, the spec's examples against a relay of its own included.

- Its own types are `application/vnd.agentwire.<entry>`, and its extensions' `application/vnd.agentwire.<extension>.<entry>`, Vibe Together's included.
- The relay serves only agentwire: Vibe Together's specs and page are its `website/`, at `vibetogether.potentialhedge.com`.
- The relay serves `agentwire.potentialhedge.com` from lwirth-cloud (`~/dev/dotcloud`), through this flake's `nixosModules.relay`.
- A link starts with the configured origin whose host the caller reached, or else the canonical one (`AGENTWIRE_ORIGINS`, the module's `origins`, canonical first), so the relay can serve several hosts and no `Host` header a proxy lets through ends up in a link.
- The relay reads the spec and the script from files at each request (`AGENTWIRE_FILES`, the module's `/etc/agentwire-relay`), so a new wording reaches it by a switch that restarts nothing; its own page is still compiled in.
- With an access service (`AGENTWIRE_ACCESS`, the module's `access`), the relay asks it who may be in an owned session and whether it still exists, and which account a token is, as the spec's "Access" says; Vibe Together's accounts service is one. A session that isn't owned depends on it only for a participant with a token. Without one, nothing changes.
- The relay limits what one client adds and how many receives it keeps waiting (`relay/limits.rs`). A client is the account the access service vouches for the participant acting, where it vouches for one, Luis's decision (2026-11-10): "count by account." Otherwise it is the peer's address, or from its own machine the one the proxy names last in `X-Forwarded-For`; a local request that names none or a loopback address isn't limited. The MCP server reaches the relay directly (`AGENTWIRE_RELAY_ADDRESS`, the module's `relayAddress`), since Caddy would drop its `X-Forwarded-For`, and names its caller in each request of an agent's. With `AGENTWIRE_MIN_FREE` (the module's `minFree`, 5 GiB by default) it refuses whatever adds once its disk has less free.
- The relay logs each request to stderr: its method, its path with session addresses and secrets left out, its query's keys, its status and time; never a header.

Provenance: agent-autonomous
