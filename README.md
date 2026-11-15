# keenetic-netcraze-router-dev-skill — toolkit for Keenetic / Netcraze apps on Entware

One CLI that covers the whole loop: scaffold → cross-compile → package `.ipk` →
build an opkg feed (with vendored dependencies) → deploy to the router → QA on the
device → publish a GitHub release.

Built from the real experience of shipping [`keenetic-smb-ui`](https://github.com/tommilevs/keenetic-smb-ui):
correct Entware architecture strings, legacy ipkg layout, opkg feed pitfalls, CIFS
quirks and a deploy loop that rolls back on a failed health check.

## Requirements

- Windows host with **WSL** (Ubuntu) and these tools: `bash ssh sshpass scp tar gzip curl python3 git`
- **Go** toolchain (Windows build is fine — it cross-compiles to `linux/*` with `CGO_ENABLED=0`)
- Router reachable over SSH (Keenetic/Netcraze, Entware installed)

```sh
# from Windows PowerShell / cmd
C:\Users\tommi\.agents\skills\keenetic-dev\bin\keenetic-dev.cmd doctor
# or from WSL
keenetic-dev doctor
```

## Install

```sh
git clone https://github.com/tommilevs/keenetic-netcraze-router-dev-skill \
  /mnt/c/Users/tommi/.agents/skills/keenetic-dev
cp /mnt/c/Users/tommi/.agents/skills/keenetic-dev/config.example.env \
   /mnt/c/Users/tommi/.agents/skills/keenetic-dev/config.env   # fill credentials
chmod +x /mnt/c/Users/tommi/.agents/skills/keenetic-dev/bin/keenetic-dev
```

`config.env` is git-ignored: it holds router and panel credentials. Use
`KEENETIC_DEV_CONFIG=/path/to/other.env` to switch profiles.

## Typical session

```bash
keenetic-dev init ~/src/myapp --module github.com/me/myapp --port 8099
keenetic-dev build --project ~/src/myapp --version 0.1.0 --all
keenetic-dev ipk  --bin ~/src/myapp/dist/myapp_linux_arm64 --arch aarch64-3.10 --version 0.1.0
keenetic-dev feed --dir ~/src/myapp/dist
keenetic-dev deploy --project ~/src/myapp --build
keenetic-dev qa
```

Publishing a feed that carries its own dependencies:

```bash
keenetic-dev vendor --arch aarch64-3.10 --arch armv7-3.2 --out ~/src/myapp/dist/feed
keenetic-dev feed   --dir ~/src/myapp/dist       # app packages
keenetic-dev publish --repo me/myapp --tag v0.1.0 --dir ~/src/myapp/dist
```

On the router, users then run:

```sh
echo "src/gz myapp https://github.com/me/myapp/releases/latest/download" >> /opt/etc/opkg.conf
opkg update
opkg install myapp
```

## Command reference

Run `keenetic-dev help` for the full list. Highlights:

| Command | What it does |
|---|---|
| `doctor` | tools, Go, router SSH, installed package, panel HTTP code |
| `init` | Go skeleton with embedded UI, init script, packaging, Makefile |
| `build` | 6 linux targets, version injected into `internal/web.Version` |
| `ipk` | legacy gzip-tar package with `Conffiles`, `postinst`, `prerm` |
| `feed` | `Packages` / `Packages.gz` (blank-line separated stanzas) |
| `vendor` | Samba dependency closure from Entware, per arch |
| `publish` | GitHub release + upload all assets (token from git credential store) |
| `deploy` | backup → stop → scp → start → health check → rollback |
| `qa` | service, API, SMB listener, mounts, `testparm`, disk space |
| `logs` / `ssh` / `status` | day-to-day operations |
| `setpass` | rotate panel + SMB admin password with verification |
| `update` | self-update from this repository |

## Versioning and self-update

- The version lives in `VERSION`; `keenetic-dev version` prints it plus the git SHA.
- `keenetic-dev update --check` compares it with `main` on GitHub.
- `keenetic-dev update` runs `git pull --ff-only` in a clone, or downloads the branch
  tarball otherwise, always keeping your `config.env`.

## Notes / limitations

- Only `aarch64` was verified on real hardware in this workflow; other binaries are
  built but should be smoke-tested on the target router.
- `publish` needs a GitHub token in the machine's git credential store
  (`git credential fill`), which is where Windows Credential Manager stores it.
- `vendor` follows the current Entware feeds; pin versions if you need reproducible
  images across time.

## License

AGPL-3.0-or-later — see `LICENSE`. Attribution required when redistributing.

## Changelog

- **1.2.0** — разделы про сохранность config.json при `opkg --force-reinstall` и про
  устойчивый bootstrap сетевых монтирований (фоновой watcher, изоляция ошибок).
- **1.1.0** — build через PowerShell для Windows-Go (GOOS/GOARCH не проходили через WSL
  interop), `deploy` с поллингом `/api/session` и `--wait`, проверка ELF в самотесте,
  `vendor` с маппингом архитектур, разделы про UI- и config-грабли; скилл переименован
  в `keenetic-netcraze-router-dev-skill`.
- **1.0.0** — первый выпуск: init/build/ipk/feed/vendor/publish/deploy/qa/status/logs/
  setpass/ssh/doctor/config/update.