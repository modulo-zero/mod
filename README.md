mod-cli
==

Tools for working on mod projects.

## Dependencies

Install node 18 and go 1.20.

TODO add these steps to the installation script.

## Installation

```bash
# set up your secrets
$ cp .env.config .env

# run the install script
$ ./install.sh

# or similar, if not using zsh
$ source ~/.zshrc
```

`.env.config` is a checked-in template. It holds no real values — fill in your own
keys in `.env`, which is gitignored. Never commit `.env`.

## Usage

```bash
$ mod <command> [args...]
$ mod help          # list every command
```

Commands that take `<env>` resolve it against the `mod.config.json` of the project
you are currently in; `mod` walks up from your working directory to find it. The
optional `l1`/`l2` argument picks a layer for environments that define both.

| Command | Arguments | Description |
| --- | --- | --- |
| `address` | `<network> <contract-name>` | Print a deployed contract address from `deployments/`. |
| `balance` | `<env> [l1\|l2] <address>` | Show the ether balance of an address. |
| `balance-full` | `<address>` | Show that balance on every configured network. |
| `call` | `<env> [l1\|l2] <address> <selector> [args...]` | Make a read-only contract call. |
| `drain` | `<address>` | Sweep balances into an address. See known gaps. |
| `e2e` | `<env> <layers> <contract> <selector> [args...]` | Run an end-to-end script sequence. See known gaps. |
| `pk` | `<account>` | Print the private key for a keystore account. See below. |
| `rpc` | `<network>` or `<env> <l1\|l2>` | Resolve the rpc url for a network. |
| `script` | `<env> [l1\|l2] <contract> <selector> [args...]` | Run a forge script. |
| `send` | `<env> [l1\|l2] <address> <selector> [args...]` | Send a transaction. |
| `tenderly` | `<env> <l1\|l2>` | Create a Tenderly fork and print its id. |
| `trace` | `<tx-hash>` | Visualize a transaction trace. See known gaps. |
| `verify` | `<verifier> <chain-id> <address> <contract> [forge-args...]` | Verify a deployed contract. |
| `wallet` | `<subcommand> [args...]` | Manage keystore accounts. Run `mod wallet` for subcommands. |

### Aliases

`a`=address, `b`=balance, `c`=call, `e`=e2e, `r`=rpc, `s`=script, `t`=trace,
`ve`=verify, `wa`=wallet. `send` has no alias.

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
3. Print a `Usage: mod <your-command> ...` line and exit 1 when required arguments are missing.
4. Edit shell.sh and add your command/subcommands to the level 1/level 2 completion cases.
5. Add your command to the `usage()` function in mod.sh so it shows up in `mod help`.
6. Add your command to the usage table in README.md.
7. (optional) Edit mod.sh and add an alias for your command to make it easier to type in.
