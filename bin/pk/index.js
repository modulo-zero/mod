const fs = require('fs');

// mod-usage: mod pk <account>
// mod-usage: mod pk sol <name> [--json]
// mod-description: print the private key for a keystore account
// mod-arg: <account>   keystore account name or address, under ETH_KEYSTORE_DIR
// mod-arg: sol <name>  solana keypair under SOL_KEYPAIR_DIR, as a base58 string
// mod-arg:             (what Phantom and Solflare import); --json prints the
// mod-arg:             byte array solana-keygen uses instead
// mod-note: Decrypts with the password in the file ETH_PASSWORD_FILE points to, the
// mod-note: same file cast and forge use. Set it with `mod secrets password`.
// mod-note: Prints a secret to stdout, where pipes, shell history, scrollback
// mod-note: and CI logs can capture it. Prefer passing --account to cast or
// mod-note: forge, which is what mod script and mod send already do.

// Mirrors the output of lib/help.sh, which builds the same blocks out of the
// same mod-* headers for the shell commands.
const color = process.stdout.isTTY
  ? { orange: '\x1b[0;33m', blue: '\x1b[0;34m', off: '\x1b[0m' }
  : { orange: '', blue: '', off: '' };

function meta(field) {
  const source = fs.readFileSync(__filename, { encoding: 'utf8' });
  const pattern = new RegExp(`^\\s*//\\s*mod-${field}:\\s*(.*)$`, 'gm');
  return [...source.matchAll(pattern)].map((match) => match[1].trimEnd());
}

function printUsage() {
  console.log(`${color.orange}Usage:${color.off}`);
  meta('usage').forEach((line) => console.log(`  ${line}`));
}

function printHelp() {
  console.log(`${color.blue}mod pk${color.off} - ${meta('description')[0]}\n`);
  printUsage();

  const args = meta('arg');
  if (args.length) {
    console.log(`\n${color.orange}Arguments:${color.off}`);
    args.forEach((line) => console.log(`  ${line}`));
  }

  const notes = meta('note');
  if (notes.length) {
    console.log('');
    notes.forEach((line) => console.log(line));
  }
}

const expand = (p) => p.replace(/^~/, process.env.HOME);

// Bitcoin-alphabet base58, as used for solana keys. Inline rather than a
// dependency: it is a base conversion plus leading-zero handling.
function base58(bytes) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  let n = BigInt('0x' + Buffer.from(bytes).toString('hex').padStart(2, '0'));
  let out = '';
  while (n > 0n) {
    out = alphabet[Number(n % 58n)] + out;
    n /= 58n;
  }
  for (const b of bytes) {
    if (b !== 0) break;
    out = '1' + out;
  }
  return out;
}

function solana(name, json) {
  if (!name) {
    printUsage();
    console.log("Run 'mod pk --help' for details.");
    process.exit(1);
  }
  const dir = expand(process.env['SOL_KEYPAIR_DIR'] || '~/.config/solana/keys');
  const file = `${dir}/${name}.json`;
  if (!fs.existsSync(file)) {
    console.error(`Error: no solana keypair named '${name}' in ${dir}.`);
    console.error("Run 'mod wallet sol list' to see what is there.");
    process.exit(1);
  }
  const bytes = JSON.parse(fs.readFileSync(file, { encoding: 'utf8' }));
  if (!Array.isArray(bytes) || bytes.length !== 64) {
    console.error(`Error: ${file} is not a 64-byte solana keypair.`);
    process.exit(1);
  }
  console.log(json ? JSON.stringify(bytes) : base58(bytes));
}

function main(account, ...rest) {
  if (account === '-h' || account === '--help') {
    printHelp();
    process.exit(0);
  }

  if (!account) {
    printUsage();
    console.log("Run 'mod pk --help' for details.");
    process.exit(1);
  }

  if (account === 'sol') {
    solana(rest.find((a) => !a.startsWith('--')), rest.includes('--json'));
    return;
  }

  const keyth = require('keythereum');
  require('dotenv').config();

  const keystorePath = expand(`${process.env['ETH_KEYSTORE_DIR']}/${account}`);
  const passwordPath = expand(process.env['ETH_PASSWORD_FILE'] || '');
  if (!passwordPath || !fs.existsSync(passwordPath)) {
    console.error(`Error: no keystore password file at '${passwordPath}'.`);
    console.error("Set one with 'mod secrets password'.");
    process.exit(1);
  }
  const password = fs.readFileSync(passwordPath, {encoding: "utf8"}).replace(/\r?\n$/, '');
  const keyObject = JSON.parse(fs.readFileSync(keystorePath, {encoding: "utf8"}));
  const privateKey = `0x${keyth.recover(password, keyObject).toString('hex')}`;

  console.log(privateKey);
}

main(...process.argv.slice(2));
