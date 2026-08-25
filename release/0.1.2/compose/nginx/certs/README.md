# TLS certs go here

Empty by design — generate a cert pinned to the offline server's actual
IP/hostname before first start:

```bash
cd release/compose
./nginx/generate_self_signed_cert.sh <this-server's-IP>
```

This writes `cert.pem` and `key.pem` into this folder. Re-run it (and
`docker compose restart nginx`) any time the server's IP changes — a cert
generated for one IP will not validate for another.
