---
name: keenetic-netcraze-router-dev-skill
description: Build, package and deploy applications for Keenetic/Netcraze routers running Entware. Use when creating or shipping a Go app for a Keenetic router — cross-compiling for aarch64/armv7/mipsel/mips, building legacy ipkg .ipk files, publishing an opkg feed with vendored Samba dependencies, deploying over SSH, running on-router QA, or changing the panel password.
homepage: https://github.com/tommilevs/keenetic-netcraze-router-dev-skill
metadata: {"clawdbot":{"emoji":"📦","requires":{"bins":["bash","ssh","sshpass","scp","tar","gzip","curl","python3","git"]}}}
---

# keenetic-dev

Toolkit for developing and shipping apps on **Keenetic / Netcraze** routers with
**Entware**. Encodes everything learned while building `keenetic-smb-ui`: correct
Entware architecture strings, legacy ipkg layout, opkg feed pitfalls, CIFS quirks,
and a deploy/QA loop that verifies on the device.

All commands run from **WSL** (Linux tools), calling the Windows Go toolchain for
cross-compilation. The wrapper `bin/keenetic-dev.cmd` does it for you on Windows.

## Quick start

```bash
# check the environment and the router
keenetic-dev doctor

# create a new app (Go, static, embedded UI, init script, packaging)
keenetic-dev init ~/src/myapp --module github.com/me/myapp --port 8099

# build every Entware architecture
keenetic-dev build --project ~/src/myapp --version 0.1.0

# package one architecture
keenetic-dev ipk --bin ~/src/myapp/dist/myapp_linux_arm64 --arch aarch64-3.10 --version 0.1.0

# install on the router, restart, verify
keenetic-dev deploy --project ~/src/myapp

# functional checks on the device
keenetic-dev qa
```

## Commands

| Command | Purpose |
|---|---|
| `init <dir> --module M` | scaffold a Go app: `cmd/app`, `internal/web` with embedded UI, `packaging/{init.d,postinst,prerm,config.default.json}`, Makefile |
| `build --project DIR [--all]` | cross-compile `linux/{arm64,arm,mipsle,mips,amd64,386}` with `-X …web.Version` |
| `ipk --bin F --arch A` | legacy gzip-tar `.ipk` (Entware layout, not Debian `ar`) |
| `feed --dir DIR` | write `Packages` / `Packages.gz` from `*.ipk` |
| `vendor --arch A1 --arch A2` | resolve and download the Samba dependency closure from Entware into `dist/feed/<arch>/` |
| `publish --repo O/R --tag vX --dir DIR` | create a GitHub release and upload every file (token from git credential store) |
| `deploy [--bin F | --build]` | backup, stop, scp, start, health-check, rollback on failure |
| `status` / `qa` | package/service/panel/SMB checks on the router |
| `logs [--which app|samba]` | tail logs |
| `setpass <new>` | change panel + SMB admin password, verify login, roll back on failure |
| `ssh <cmd>` | run a shell command on the router |
| `update [--check]` | self-update from `tommilevs/keenetic-netcraze-router-dev-skill` (git pull or tarball) |

## Entware architecture strings (use exactly these)

| GOARCH | Entware `Architecture:` | Feed directory |
|---|---|---|
| `arm64` | `aarch64-3.10` | `aarch64-k3.10` |
| `arm` | `armv7-3.2` | `armv7sf-k3.2` |
| `mipsle` | `mipsel-3.4` | `mipselsf-k3.4` |
| `mips` | `mips-3.4` | `mipssf-k3.4` |
| `amd64` | `x64-3.2` | `x64-k3.2` |
| `386` | `x86-2.6` | `x86-k2.6` |

Feed directory names differ from package architecture strings — do not mix them up
(that was the source of "no valid architecture" warnings).

## Packaging rules (hard-won)

- `.ipk` for opkg-on-Entware is a **gzip-compressed tar** containing
  `./debian-binary`, `./control.tar.gz`, `./data.tar.gz`. A Debian `ar` archive fails
  with `Malformed package file`.
- Config file must be listed under `Conffiles:` or it is silently replaced on upgrade.
- `Depends: libc, samba4-server, samba4-client` works only if those names exist in a
  configured feed — otherwise vendor them (see below).
- Scripts in `control.tar.gz` (`postinst`/`prerm`) run on the router; guard them with
  `[ -n "$IPKG_INSTROOT" ] && exit 0`.

## opkg feed rules

- `Packages` needs a **blank line between stanzas**. Without it, opkg on Keenetic
  crashes with `truncating field … realloc(): invalid pointer`.
- A GitHub release works as a feed: `src/gz name https://github.com/O/R/releases/latest/download`
  resolves `Packages.gz` and every `Filename:` as flat assets of that tag.
- GitHub's CDN caches assets for a few minutes — after replacing an index, use a new
  tag or wait before testing.
- `busybox wget` on Keenetic has no TLS: always `curl`.
- Listing packages for foreign architectures in one index is fine, but opkg prints
  `has no valid architecture, ignoring` for them — cosmetic.

## Device quirks

- Kernel CIFS client supports **`vers=2.1`** only; `retrans=` → `EINVAL`; load
  `cifs.ko` with `insmod` if the module is built as a module.
- Writing into an aggregated tree of root-owned CIFS mounts requires
  `force user = root` in the Samba share section, otherwise `NT_STATUS_ACCESS_DENIED`.
- No `nohup`/`setsid`/`python3` on the NDMS shell — use an `rc.func`-style init
  script and plain `sh`.
- Per-folder permissions are implemented as one Samba share per folder
  (`read only = yes` + `write list`), because mounted CIFS offers no xattr storage.
- Samba private dir must be explicit (`private dir = …`), and `smbpasswd -c <conf>`
  avoids "file did not exist" surprises.

## Deploy loop

`deploy` keeps the previous binary, starts the service and calls
`/api/session`; if the app does not answer within the health window it restores the
backup automatically. `qa` then checks service, API, SMB listener, mounts and
`testparm` against the generated config.

## Credentials

Router access and panel credentials live in `config.env` (git-ignored) next to
`SKILL.md`; `config.example.env` shows the shape. Prefer overriding via environment
for CI: `ROUTER_HOST`, `ROUTER_PORT`, `ROUTER_USER`, `ROUTER_PASS`,
`APP_PANEL_USER`, `APP_PANEL_PASS`.

## Self-update

`keenetic-dev update --check` compares local `VERSION` with
`tommilevs/keenetic-netcraze-router-dev-skill`; `keenetic-dev update` runs `git pull --ff-only`
when the skill is a clone, otherwise downloads the branch tarball and copies files
(keeping `config.env` untouched).
