# logos-tor-ui

`tor_ui`, the Tor app: it manages the Tor that comes with Logos
([`tor_module`](https://github.com/logos-co/logos-tor-module)), which the wallets reach
their servers through. Built on the Logos Design System, like the Zcash Node app it is
modelled on.

```bash
nix build .#install        # -dev variant, for Basecamp's standalone mode
nix build .#lgx
```

- **Status:** Idle (no app set to use Tor has asked for it, so nothing connects to the Tor
  network), Connecting with Tor's progress, Ready, Blocked (no progress for a while: no
  network, or a network that blocks Tor) or Failed, in Arti's own words, and how long the
  last join took. **Reconnect** stops Tor and joins again on the same SOCKS port, so the
  apps keep their proxy; on an idle Tor it reads **Start**.
- **Apps using Tor:** the modules that made a request or asked `tor_module` for its status in
  the last 90 s, with what each received. Logos apps ask Tor over IPC, so it knows which app
  asks; what goes through the SOCKS port (the Bitcoin wallet's connections) is counted under
  **Since Tor started**. An app set to skip Tor, or to use the user's own, does not ask.
- **Since Tor started:** what apps, and the SOCKS port (the Bitcoin wallet's connections and any
  program outside Logos, counted together), sent and received through
  Tor, the connections it opened, Tor's files on disk and its memory.
- **What Tor hides, and what it doesn't**, and **if Tor is blocked where you are**: the
  privacy text behind two info buttons. Until bridges come to this app, a blocked user is
  sent to Tor Browser's bridges, used as each wallet's own Tor.
- **Advanced:**
  - **SOCKS port:** on by default. The Bitcoin wallet connects through it, since its servers
    and peers take a SOCKS proxy; other Logos apps reach Tor over IPC. Closing it goes through a
    warning that the Bitcoin wallet then cannot reach what it sends through Tor. Opening it
    goes through a warning: any program on this computer can use it without a password, and on
    an address other than loopback, any computer that reaches it. It listens at
    `127.0.0.1:9250` unless the user names another IP and port, and stays put through a
    Reconnect.
  - **Forget Tor's data** behind a confirmation: new entry guards and a fresh directory. It
    fixes a join stuck on guards that stopped answering, and is no routine step.
  - Tor's log, kept in memory only.

The view polls `status()`, `usage()`, `settings()` and `log_tail()` every 2 s and applies
`status_changed` as it arrives. `tor_module` answers `usage()`, `settings()`,
`set_socks()`, `log_tail()`, `reconnect()` and `forget_data()` to this app only.

## Intents

The app **provides** `tor.manage` (handoff), with no parameters. The wallets' privacy
settings send it from "Manage Tor…".
