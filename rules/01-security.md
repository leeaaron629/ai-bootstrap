---
title: Security Rules
harnesses: [claude, cursor]
cursor-always-apply: true
---

## Security Rules

- **Never read `.env` files or any file matching `.env.*` or `*.env`.** These files contain live secrets. If a task seems to require reading one, stop and ask the user to provide only the specific value needed via chat — never read the whole file.
- Do not read files named `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_ed25519`, or any file in a `secrets/` or `credentials/` directory.
- If you accidentally read a file containing secrets, immediately warn the user that the secrets were exposed and that they should rotate them.

## Security Anti-Patterns

### Always Wrong (dev and prod)

- No hardcoded credentials, tokens, or secrets anywhere in code — not even as placeholders like `"changeme"` or `"TODO-replace"`
- No secrets committed to git — not in code, not in config files, not in comments
- No `eval()` or equivalent dynamic code execution on any external or user-supplied input
- No string interpolation to build queries (SQL, NoSQL, shell commands) — always use parameterized queries or safe APIs
- No disabling TLS/SSL certificate verification in code, even for dev or testing
- No PII (emails, names, IDs, IP addresses) written to logs or telemetry
- No weak hashing algorithms (MD5, SHA1) for anything security-related — passwords, tokens, signatures
- No storing passwords or secrets in plain text — always use a proper secrets manager or hashing

### Production Guards (flag and confirm before shipping)

- No HTTP for external API calls — always HTTPS
- No wildcard CORS (`Access-Control-Allow-Origin: *`) on authenticated endpoints
- No internal error details, stack traces, or DB errors exposed to the client
- No processes or containers running as root unless explicitly required and justified
