# Cloud sync

Ciyue can merge your wordbook, tags, flashcards, and review history through a remote file store. The first connection shows a read-only preview; nothing is written until you confirm. Dictionaries are listed separately and are transferred only when you select them.

Credentials are stored in the platform secure storage, not in app preferences. Ciyue does not provide a hosted sync service. WebDAV, SFTP, and S3-compatible connections use open protocols and do not require a Ciyue account.

## WebDAV

Enter the server URL, remote folder, and optional username/password. Use HTTPS whenever the server is not on the local machine. WebDAV works with services such as Nextcloud, ownCloud, and NAS servers that expose WebDAV.

## SFTP

Enter an `sftp://` URL, such as `sftp://nas.example.net:22/backups`. The URL path is a base directory; when omitted, Ciyue uses the SFTP account's home directory. Enter the username and either a password, an SSH private-key file, or both. An optional passphrase unlocks an encrypted private key.

Ciyue requires a pinned SSH host-key fingerprint and will reject a missing or different fingerprint. Obtain the SHA-256 fingerprint from your server administrator through a trusted channel. For an OpenSSH server, this command prints a fingerprint that can be compared with the administrator's value:

```sh
ssh-keyscan -t ed25519 nas.example.net | ssh-keygen -lf -
```

Copy the `SHA256:...` value into Ciyue. `ssh-keyscan` alone does not authenticate the server, so do not trust its output without independently verifying it. If your server uses a different host-key algorithm, specify that algorithm instead of `ed25519`. A changed host key (for example, after server replacement) requires updating the saved fingerprint.

## S3-compatible storage

Enter the HTTPS endpoint, bucket, region, access key ID, and secret access key. The remote folder is used as a prefix inside the bucket, so Ciyue lists only that prefix rather than scanning unrelated bucket objects. For example:

- MinIO: use the server's endpoint and region; path-style addressing is commonly enabled.
- Cloudflare R2: use the account endpoint, region `auto`, and usually disable path-style addressing.
- AWS S3: use `https://s3.<region>.amazonaws.com`, the matching region, and disable path-style addressing.

The addressing mode depends on the provider; if connection tests fail, check the provider's endpoint and bucket-addressing requirements. Plain HTTP is accepted only for loopback development endpoints such as `http://127.0.0.1:9000`. Use credentials scoped to the chosen bucket and the minimum permissions needed to list, read, write, copy, and delete Ciyue sync objects.

## Sync behavior

Ciyue stores versioned sync records and merges changes from each device. Concurrent edits and deletions are preserved as conflicts rather than silently overwriting one another. A preview does not create directories, upload data, or modify the remote store. Confirming the preview begins the sync.

Dictionary files are not included by default. Select each dictionary explicitly in the preview. Downloads are checked before being added to the local dictionary library and are not automatically enabled.
