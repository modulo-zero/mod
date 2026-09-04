const fs = require('fs');
const keyth = require('keythereum');
require('dotenv').config();

function main(account) {
  if (!account) {
    console.error('Usage: mod pk <account>');
    console.error('Prints the private key for a keystore account to stdout.');
    process.exit(1);
  }

  const keystorePath = `${process.env['ETH_KEYSTORE_DIR']}/${account}`.replace('~', process.env.HOME);
  const keyObject = JSON.parse(fs.readFileSync(keystorePath, {encoding: "utf8"}));
  const privateKey = `0x${keyth.recover(process.env['CAST_PASSWORD'], keyObject).toString('hex')}`;

  console.log(privateKey);
}

main(process.argv[2]);
