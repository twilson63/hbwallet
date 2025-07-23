# hbwallet a lua binary that creates jwk files for arweave

The HP wallet is a little binary that creates wallet files to be used for authentication with arweave

## Dependencies

This project depends on the hype framework. You can find details about the hype framework at https://twilson63.github.io/hype. Also you can find information about the source code of the hype framework at https://github.com/Twilson63/hype.

This CLI tool should be a single downloadable binary that is built using the hype framework to generate a wallet with no command line option so HP wallet enter generates a new wallet and names the wallet based on it or outputs the wallet data to standard in or standabackspace erase word. Erase word delete word.

To rephrase this CLI binary when in vote with no arguments will output wallet key file JWK data to standard out.
If you invoke the CI binary with an argument of pub and another argument option of – F for file with the file name, it will read that file as Jason and determine the 43 character hash of the public key to print as the wallet identifier.
So this project will need to create a module in Lua that can receive command line arguments and return to standard out a string representation of a JWKRSA file.

And should be able to take an argument like public key with a additional option – F – – file and a value for the file name and then return the 43 character representation of the wall file.

What we may want to do is reference or do some research at https://github.com/arweave/arweave-js


Usage:

Create a new wallet

```sh
hbwallet > new-wallet.json
```

get public-key of wallet

```sh
hbwallet public-key --file new-wallet.json
```

Expected output is a 43 character has of the public key


