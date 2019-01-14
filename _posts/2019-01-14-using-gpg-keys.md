---
layout: post
title:  "Using GPG Keys"
date:   2019-01-14 23:00:00 +0500
categories: [security]
---

GNU Privacy Guard (gpg) is the most common implementation of OpenPGP (pretty
good privacy). It is available on all operating systems and provides a safe
way to encrypt messages and protect secrets.

## PGP Explained

PGP works by each person having an identity. This identity consists of a
public/private symmetric key pairs. You then share your identity with others
by delivering your public key to them. Anyone with your public key can
encrypt a message that only you can decrypt. They would then deliver this
encrypted message to you by any means (like email). Upon reciept, you would
then decrypt the message using your private key.

In order for this system to work you must first be able to verify the
authenticity of public keys you recieve and you must never leak your private
key. In order to verify the authenticity of a public key, all keys have
fingerprints. When you recieve a public key, you should also ask the sender
for the fingerprint through another means of communication. The likelyhood of
both of these systems being compromised is minimal. If your private key is
ever leaked, you must issue a revocation certificate to invalidate the
previous key pair.

To assist with the sharing of public keys, there are public PGP key servers.
When obtaining a key from one of these servers, always verify the
fingerprints. A reasonably reliable PGP key infrastructure is the pool of SKS
servers. These servers all replicate with each other and have a round-robin
DNS entry to load balance across them.

## Creating a Key

Use the gpg commannd to generate a new key:

```bash
gpg --gen-key
```

This will walk through prompts to create a new key. It is currently best to
use "RSA and RSA" for the key type. Longer keys are better so I'd recommend
using 4096 bits. You must then select for how long the key should remain
valid. One year is a reasonable amount of time. Permanent keys are not the
end of the world, but if your private key is leaked without your knowledge,
you will forever be vulnerable. Finally, enter your name, comment, and email
address. Once you have done all this, your key will be generated.

## Sharing a Public Key

In order to share a public key, you must first export it.

```bash
gpg --armor --output public.gpg --export email@sample.com
```

Use the email address you used to create your key. This will create a file
called `public.gpg` that will contain your public key. You'll also need to
get your key's fingerprint in order to share it securely.

```bash
gpg --fingerprint email@sample.com
```

Lastly, you'll also need your key ID.

```bash
gpg --keyid-format long --list-keys email@sample.com
```

The pub line will have the format: LENGTH/KEY_ID CREATION.

## Submit Key to Public Server

You'll first need to configure a target public server. This is stored in
`~/.gnupg/gpg.conf` The default is `hkp://keys.gnupg.net`. This server is
alright, but it might be better to use an SKS server in order to ensure the
data is replicated. Set the variable `keyserver` to
`hkp://pool.sks-keyservers.net hkp://keys.gnupg.net`.

Then:

```bash
gpg --send-keys KEY_ID
```

This will publish your keys. It will likely take a while for you key to
propogate and you may occasionally get some HTTP errors. The PGP
infrastructure is actually pretty unreliable. That is why there are so many
servers.

## Get Key from a Public Server

These servers make it easier for you to share your key with others. If you
share your Key ID with someone, they can now download your public key. My Key
ID is E3B61E72947D4FDC. It can be fetched with the following command.

```bash
gpg --recv-keys E3B61E72947D4FDC
```

This will fetch the key, download it, and add it to your keychain. Now you'll
want to verify the the fingerprint for the new key.

```bash
gpg --fingerprint E3B61E72947D4FDC
```

The fingerprint should be:

```bash
Key fingerprint = 6A1E 33D4 B832 9019 96CB  D1C5 E3B6 1E72 947D 4FDC
```

If the fingerprint matches, you can then sign the key so you will trust it.

```bash
gpg --sign-key E3B61E72947D4FDC
gpg --check-sigs E3B61E72947D4FDC
```

You'll now see your signature on the new key.

## Encrypt a Message

```bash
date > message.txt
gpg --output message.txt.gpg --encrypt --sign --armor --recipient rkraus@redhat.com message.txt
rm message.txt
```

This will create a text file and encrypt it for me. You would now send that
file to me for decryption. (Please dont)

## Decrypt a Message

```bash
gpg --output message.txt --decrypt message.txt.gpg
cat message.txt
```

This will decrypt the message using your private key and write it to a file.
In STDOUT, you will see the signature of party that encrypted the message
and if their signature could be verified. Be sure you trust the sending
party's public key so their messages will be trusted.

## Delete a Key

If you want to no longer trust a key, you can delete it from your keyring.

```bash
gpg --delete-keys E3B61E72947D4FDC
```

## Backup Keys

It may be prudent to export your keys and save them to a secure trusted
location.

```bash
gpg --export-secret-keys email@sample.com > private.gpg
gpg --export email@sample.com > public.gpg
```

These files can be imported on a new system like so:

```bash
gpg --import public.gpg
gpg --import private.gpg

gpg --list-keys
gpg --list-secret-keys
```

Be careful with these backups! They are your GPG identity!

## What's Next

There is a lot more you can do with GPG keys and they are very powerful for
signing and encrypting data. The best thing about this system is that it
gives you autonomy from any particular company's infrastructure. Keys can be
shared without any external infrastructure.

## External Sources

* “How to Use GPG Keys to Send Encrypted Messages.” Linode Guides & Tutorials, 8 Aug. 2018, [www.linode.com/docs/security/encryption/gpg-keys-to-send-encrypted-messages/](www.linode.com/docs/security/encryption/gpg-keys-to-send-encrypted-messages/).
