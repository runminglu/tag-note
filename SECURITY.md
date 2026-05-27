# Security Policy

## Supported Versions

Security fixes target the latest release and the `main` branch.

## Reporting A Vulnerability

Please do not open a public issue for a suspected vulnerability.

Use GitHub private vulnerability reporting for this repository, or open a
private GitHub security advisory if you have maintainer access:

https://github.com/runminglu/tag-note/security/advisories/new

Include:

- A clear description of the issue.
- Affected version or commit.
- Reproduction steps or proof of concept.
- Impact assessment, including whether authentication is required.
- Any suggested mitigation or patch.

You should receive an initial response within 7 days. Valid reports will be
triaged privately until a fix or mitigation is available.

## Security Notes For Operators

- Set a strong `JWT_SECRET` in production.
- Keep `.env`, SQLite databases, backups, uploads, and logs out of Git.
- Put TagNote behind HTTPS in production.
- Back up both the SQLite database and upload directory.
- Rotate `JWT_SECRET` immediately if it is exposed. Existing sessions will be invalidated.
