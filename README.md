# fivem-enhanced-docker

A small Docker image and compose stack for running a **FiveM FXServer on GTA V
Enhanced** with txAdmin and MariaDB. It is the setup behind a live Enhanced
server since August 2026, with the parts that bit us written down.

The image does **not** contain the FXServer artifact. You give it the link to a
build from Cfx.re's own artifacts page and it downloads that build into a
volume on first start. One image tag serves every server build, and nothing of
Cfx.re's is redistributed here.

## Quick start

```sh
git clone https://github.com/chaosen3/fivem-enhanced-docker
cd fivem-enhanced-docker
cp .env.example .env        # fill in CFX_URL, TXHOST_TXA_URL and the MariaDB passwords
docker compose up -d
docker compose logs -f fivem
```

The first start downloads the artifact (a few hundred MB), then txAdmin prints
its setup PIN in the log. Open `http://<host>:40120`, enter the PIN and run the
txAdmin setup; it writes `server.cfg` under `./txData`. You need a server
licence key from the [Cfx.re portal](https://portal.cfx.re), as with any
FXServer.

For the database connection in `server.cfg`, the MariaDB service is reachable
as `mariadb` on the compose network:

```
set mysql_connection_string "mysql://fivem:<MARIADB_PASSWORD>@mariadb/fivem?charset=utf8mb4"
```

## Getting the artifact URL

Enhanced server files are published on Cfx.re's
[Server Download](https://docs.fivem.net/docs/server-download/) page, separate
from the Legacy artifact listing. Copy the Linux link
(`downloads.cfx-services.net/prod/<uuid>/cfx-server_linux_x64.tar.xz`); the
UUID changes with every build, so there is nothing to automate: paste the link
into `CFX_URL`.

Legacy artifacts from the
[build_proot_linux listing](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)
have the same layout and run in this image too; `citizen_dir` is only needed
on Enhanced and is harmless on Legacy.

## Updating the server build

Change `CFX_URL` in `.env` and run `docker compose up -d`. The launcher
records the URL it last fetched; a different URL means a new build, so it
downloads and swaps the artifact tree before starting. Set `CFX_FORCE_FETCH=1`
to re-download the same URL, and `CFX_SHA256` to make the fetch refuse a file
that does not match.

Updating the *image* (`docker compose pull`) changes nothing about the server
build; the artifact lives in the `cfx` volume.

## Things that bit us

- **`+set citizen_dir` is required on Enhanced.** Without it the server cannot
  find its own `citizen/` tree and segfaults at start. The launcher sets it.
- **No bash in the container.** The artifact's `run.sh` is a two-line bash
  wrapper around the musl loader; the launcher does the same in plain `sh`.
- **txAdmin v8 moved from ConVars to `TXHOST_*` environment variables.** The
  old ConVar names are ignored silently, so a headless setup that still uses
  them boots txAdmin blank. `.env.example` has the current names.
- **`restart: unless-stopped`, not `on-failure`.** `on-failure` never restores
  the container after the daemon's clean shutdown at reboot, so the server
  stays down until someone notices.
- **`stop_grace_period: 60s`.** FXServer flushes txAdmin and resource state on
  SIGTERM; compose's default 10 s cut that off mid-save.
- **`depends_on: condition: service_healthy` is honoured by `compose up` only.**
  The daemon's boot restore starts containers in whatever order; FXServer's
  resources must tolerate the database arriving a few seconds late.
- **`security_opt: seccomp:unconfined`** is carried over from the stack this
  came from, where it has run from the beginning. We have not proven it is
  needed; drop it and test if your host policy objects.
- **The server runs as root inside the container**, so files it writes under
  `./txData` are root-owned on the host. A PUID/PGID option is a welcome PR.
- **Tag images by build, never let `docker compose build` write over the tag
  you run.** This image avoids the problem (the build is in a volume), but if
  you bake your own, tag by build number and repoint compose.

## Building it yourself

```sh
docker build -t fivem-enhanced .
```

The workflow in `.github/workflows/publish.yml` builds on every push, runs a
smoke test (a start without `CFX_URL` must fail with exit 64 and a clear
message) and pushes to `ghcr.io/chaosen3/fivem-enhanced` on `main` and on
`v*` tags.

## Licence

The files in this repository are MIT licensed. FXServer, txAdmin and the
artifact you download are Cfx.re's, under their
[terms](https://fivem.net/terms); the download happens on your machine, with
your consent to those terms, and needs your own licence key.
