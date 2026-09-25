mod-cli
==

Tools for working on mod projects.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/modulo-zero/mod/master/install.sh | bash
```

This clones the repo to `~/mod-cli` and runs the installer. From an existing
checkout, run `./install.sh` instead. Set `MOD_DIR` to clone somewhere else, or
`MOD_REPO` to clone over https instead of ssh.

The installer checks for the tools `mod` shells out to, links `mod` into
`/usr/local/bin` (asking for sudo if needed; set `MOD_BIN_DIR` to link elsewhere),
and creates the `~/.mod` directory. It does not edit your shell rc files and
is safe to rerun.

Tab completion and the `m` alias are optional. To enable them, add this line to
your `.bashrc` or `.zshrc`:

```bash
source ~/mod-cli/shell.sh
```

To update later, run `mod upgrade`. It pulls the checkout and reruns the
installer; `mod pk` reinstalls its npm packages on its next run if they changed.

Requirements:

| Tool | Needed by | Install |
| --- | --- | --- |
| [Foundry](https://getfoundry.sh) (`cast`, `forge`) | almost everything | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `jq` | config lookups | `brew install jq` / `apt install jq` |
| [Solana CLI](https://solana.com/docs/intro/installation) (`solana-keygen`) | `mod wallet sol` only | `sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"` |
| node 18+ | `mod pk` only | `brew install node`; its npm packages install on first use |

### Configuration

Everything personal lives under `~/.mod` (override with `MOD_HOME`), outside
any checkout:

| File | Holds | Edit with |
| --- | --- | --- |
| `~/.mod/env` | secrets: keystore paths, Tenderly and verifier keys | `mod secrets` |
| `~/.mod/mod.config.json` | networks and envs shared by every project | `mod config` |
| `<project>/mod.config.json` | project-specific networks and envs | your editor |

The global and project `mod.config.json` are merged key by key, with the project
winning, so networks defined once globally are available in every project and a
project only needs to declare what differs. Strings in either file can reference
a secret as `${NAME}`, e.g. `"url": "https://mainnet.infura.io/v3/${INFURA_API_KEY}"`,
so API keys never need to be written into a `mod.config.json`. `mod` finds the project file by
walking up from the current directory; with only a global file, `<env>` commands
work from anywhere.

```bash
mod config            # open the global mod.config.json in $EDITOR
mod config create     # write an empty mod.config.json in the current directory
mod config check      # list the merged networks and envs
mod config validate   # check the merged mod.config.json: urls, env -> network refs, secrets
mod config path       # print the file locations

mod secrets           # open the secrets file in $EDITOR
mod secrets check     # which secrets are set, without printing them
mod secrets password  # store the keystore password for cast, forge and mod pk

mod env               # list the envs in the merged config
mod env demo state    # print one field of an env; nested keys are joined with dots
```

The keystore password is not kept in the config; `mod secrets password` writes it
to the file `ETH_PASSWORD_FILE` points to (`~/.foundry/keystore_password` by
default), which is what Foundry's `--password-file` convention expects.

Older installs that kept a `.env` inside the checkout keep working; run
`mod secrets migrate` to move it. A `~/.mod` file from earlier versions is moved
to `~/.mod/env` by the installer.

## Usage

```bash
$ mod <command> [args...]
$ mod help                # list every command, with its alias and description
$ mod <command> --help    # usage, arguments and notes for one command
```

`mod`, `mod help`, `mod -h` and `mod --help` all print the command list, which is
built by scanning `bin/` at runtime, so it cannot drift from what is installed.
Every command also accepts `-h` / `--help` as its first argument, and still prints
its usage line and exits 1 when required arguments are missing.

Commands that take `<env>` resolve it against the `mod.config.json` of the project
you are currently in; `mod` walks up from your working directory to find it. The
optional `[layer]` argument picks a layer for environments whose `rpc` is an object
of layer names to networks, such as `{ "l1": ..., "l2": ... }` or `{ "ethereum": ..., "solana": ... }`.

| Command | Arguments | Description |
| --- | --- | --- |
| `address` | `<network> <contract-name>` | Print a deployed contract address from `deployments/`. |
| `balance` | `<env> [layer] <address>` | Show the ether balance of an address. |
| `balance-full` | `<address>` | Show that balance on every configured network. |
| `call` | `<env> [layer] <address> <selector> [args...]` | Make a read-only contract call. |
| `config` | `[edit\|create\|check\|validate\|path]` | Edit or inspect `mod.config.json`. |
| `drain` | `<address>` | Sweep balances into an address. See known gaps. |
| `e2e` | `<env> <layers> <contract> <selector> [args...]` | Run an end-to-end script sequence. See known gaps. |
| `env` | `[<env> [key.key]]` | Print an env, or one of its fields, from the merged `mod.config.json`. |
| `fork` | `<network\|env [layer]\|url> [anvil args...]` | Start a local anvil fork of a network. |
| `pk` | `<account>` | Print the private key for a keystore account. See below. |
| `rpc` | `<network>` or `<env> [layer]` | Resolve the rpc url for a network. |
| `script` | `<env> [layer] <contract> <selector> [args...]` | Run a forge script. |
| `secrets` | `[edit\|check\|password\|migrate]` | Edit or inspect the secrets file. |
| `send` | `<env> [layer] <address> <selector> [args...]` | Send a transaction. |
| `tenderly` | `<env> [layer]` | Create a Tenderly fork and print its id. |
| `trace` | `<tx-hash>` | Visualize a transaction trace. See known gaps. |
| `upgrade` | | Pull the latest version and rerun the installer. |
| `verify` | `<verifier> <chain-id> <address> <contract> [forge-args...]` | Verify a deployed contract. |
| `wallet` | `<subcommand> [args...]` | Manage keystore accounts. Run `mod wallet --help` for subcommands. |
| `wallet sol` | `<subcommand> [args...]` | The same subcommands for Solana keypairs, via `solana-keygen`. |

Every command in this table accepts `--help` / `-h` for the same information plus
per-argument detail, e.g. `mod verify --help`.

### Aliases

`a`=address, `b`=balance, `c`=call, `e`=e2e, `r`=rpc, `s`=script, `se`=send,
`t`=trace, `ve`=verify, `wa`=wallet.

They are defined once in the `MOD_ALIASES` table in mod.sh, which both the
dispatcher and `mod help` read.

### Environment variables

| Variable | Effect |
| --- | --- |
| `ACCOUNT` | Keystore account used to sign for `script` and `send`. |
| `FORK=true` | Route `balance`, `call`, `script` and `send` through a fresh Tenderly fork. |

### A note on `mod pk`

`mod pk` decrypts a keystore file and prints the private key to stdout. Anything that
captures stdout — a pipe, a shell transcript, your scrollback, CI logs — captures the
key. Prefer passing `--account` to `cast`/`forge` (which is what `script` and `send`
already do) so the key never leaves the keystore.

## Known gaps

These commands are present but not currently working. They are listed here so the
help output stays honest about what ships.

- `trace` invokes `lib/trace-vis/index.js`, which is not in this repo, and hardcodes
  the rpc url to `http://localhost:9545`.
- `e2e` shells out to `../../blast.sh`, a leftover from the rename to `mod`; the file
  does not exist.
- `drain` never sends anything — the `cast send` is commented out and the balance
  arithmetic around it is unfinished.
- `call` builds its selector from `$1` instead of `$2` in the non-`returns` branch,
  so the address is passed where the selector belongs. Compare `send`, which is correct.

## Adding a new command

1. Create a new subfolder under `bin` with your command name, exactly as you want people to type it.
2. If you can write your command as a shell script, create a new index.sh file in that subfolder. Otherwise make it an index.js file.
3. Document it with `mod-` header comments at the top of the file (see below). It
   will appear in `mod help` automatically — there is no list to update.
4. Source `lib/help.sh` and use its helpers so your command answers `--help` and
   prints its usage when arguments are missing:

   ```bash
   source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

   if mod_is_help_flag "${1:-}"; then
     mod_print_help <your-command>
     exit 0
   fi

   if [ $# -lt 1 ]; then
     mod_missing_args <your-command>
   fi
   ```

5. Edit shell.sh and add your command/subcommands to the level 1/level 2 completion cases.
6. Add your command to the usage table in README.md.
7. (optional) Add an alias to the `MOD_ALIASES` table in mod.sh to make it easier to type in.

### Command headers

Help text lives in header comments in the command itself, so the one-line
description in `mod help` and the detail page in `mod <command> --help` cannot
disagree. Both `#` and `//` comments are read, so node commands work the same way.

```bash
# mod-usage: mod balance <env> [layer] <address>
# mod-description: show the ether balance of an address
# mod-arg: <env>       environment named in the project's mod.config.json
# mod-arg: <address>   address to look up
# mod-note: free-form line, printed last
```

`mod-usage`, `mod-arg` and `mod-note` may be repeated to produce several lines.
`mod-description` should stay short — it is the one-line summary in `mod help`.
