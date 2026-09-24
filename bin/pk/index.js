const fs = require('fs');

// mod-usage: mod pk <account>
// mod-description: print the private key for a keystore account
// mod-arg: <account>   keystore account name or address, under ETH_KEYSTORE_DIR
// mod-note: Decrypts with the password in the file ETH_PASSWORD_FILE points to, the
// mod-note: same file cast and forge use. Set it with `mod config password`.
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

function main(account) {
  if (account === '-h' || account === '--help') {
    printHelp();
    process.exit(0);
  }

  if (!account) {
    printUsage();
    console.log("Run 'mod pk --help' for details.");
    process.exit(1);
  }

  const keyth = require('keythereum');
  require('dotenv').config();

  const expand = (p) => p.replace(/^~/, process.env.HOME);
  const keystorePath = expand(`${process.env['ETH_KEYSTORE_DIR']}/${account}`);
  const passwordPath = expand(process.env['ETH_PASSWORD_FILE'] || '');
  if (!passwordPath || !fs.existsSync(passwordPath)) {
    console.error(`Error: no keystore password file at '${passwordPath}'.`);
    console.error("Set one with 'mod config password'.");
    process.exit(1);
  }
  const password = fs.readFileSync(passwordPath, {encoding: "utf8"}).replace(/\r?\n$/, '');
  const keyObject = JSON.parse(fs.readFileSync(keystorePath, {encoding: "utf8"}));
  const privateKey = `0x${keyth.recover(password, keyObject).toString('hex')}`;

  console.log(privateKey);
}

main(process.argv[2]);
