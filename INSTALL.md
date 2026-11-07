# OL Gene __OL_GENE_VERSION__

Install OL Gene on one host from this bundle. The command is `./olgene`.

## System requirements

- 4 vCPU, 8 GB RAM, 40 GB disk, on a trusted network
- Docker or Podman
- This archive and its `.sha256` file
- A model provider key to paste after you sign in
- Optional: a `.license` file from OpenLegacy. Without it, this install runs as a 30-day trial

## Install

The checksum file is next to the archive. Verify it, then unpack and start.

```bash
sha256sum -c ol-gene-__OL_GENE_VERSION__-linux-amd64.tar.gz.sha256
tar xzf ol-gene-__OL_GENE_VERSION__-linux-amd64.tar.gz
cd ol-gene-__OL_GENE_VERSION__
./olgene setup
```

On macOS the check is `shasum -a 256 -c ol-gene-__OL_GENE_VERSION__-linux-amd64.tar.gz.sha256`.

`./olgene setup` loads `olgene-images.tar.gz`, generates an auth secret for this host, and starts the stack. It does not contact a registry.

## What you unpacked

The archive opens as `ol-gene-__OL_GENE_VERSION__/`.

- `olgene` — setup, start, stop, and logs
- `olgene-images.tar.gz` — the container images. Setup loads this file
- `.env` — host settings. Setup writes the auth secret here
- `INSTALL.md` — this guide
- `sbom/` — a CycloneDX file for each image
- `docker-compose.yml`, `nginx.conf`, and `mongod.conf` — the stack setup starts

## Create the administrator

```bash
./olgene test
```

Open `http://<host>:8080`. Create the first email and password. That person administers this installation. The trial runs for 30 days from that first organization.

## Add a model key

Chat and agents use the provider you add here.

1. Open **Settings**. Stay on the **Organization** tab.
2. Under **AI Provider Configuration**, choose a provider.
3. Paste the API key and click **Add Provider**.
4. Click **Save Changes**.

## Apply the license

When you have a license file from OpenLegacy:

1. Open **Settings → Organization → OnPrem License**
2. Choose the `.license` file and upload it

A valid file ends the trial. The screen shows who it is licensed to, when it was issued, and when it expires. Uploading another file replaces the current license.

## Host setup

Docker Engine with Compose v2, or Podman 4.7 or newer with Docker Compose v2.

Windows: [WSL2](https://learn.microsoft.com/windows/wsl/install) with Docker Desktop’s WSL backend. Run the commands inside Ubuntu.

On x86_64, the CPU must expose AVX. MongoDB 7 exits with code 132 without it. On a VM, set the hypervisor CPU to host passthrough, reboot, and confirm `avx` is listed in `grep -m1 '^flags' /proc/cpuinfo`.

Published images are `linux/amd64`. On an arm64 host, install qemu user-mode emulation so the engine can run them.

Podman needs its API socket before setup.

Rootless:

```bash
loginctl enable-linger "$USER"
systemctl --user enable --now podman.socket podman-restart.service
```

Rootful:

```bash
systemctl enable --now podman.socket podman-restart.service
```

## Day to day

```bash
./olgene start
./olgene stop
./olgene logs
./olgene test
```

`./olgene stop` keeps the data. `./olgene stop --volumes` deletes it.

## Custom URL

For a name other than localhost, put TLS on a proxy in front of port 8080 and set `NEXT_PUBLIC_SERVER_BASE_URL` in `.env` to that `https://` URL.

## Network and data

The bundled MongoDB has no username and publishes port 27017. Redis has no password. The UI is HTTP. Keep this host on a trusted network.

## Upgrade

Unpack the new release. Keep this directory’s `.env` and the MongoDB volume. Load the new image archive and start:

```bash
./olgene images load olgene-images.tar.gz
./olgene start
```

Set `APIGENE_IMAGE_TAG` in `.env` to the new version before starting, so Compose uses the images you just loaded.

## If it does not start

| Problem | What to do |
|---------|------------|
| Docker is not running | Start Docker Desktop or the Podman socket, then run `./olgene setup` again |
| Archive not found | Run `./olgene setup` from the unpacked `ol-gene-__OL_GENE_VERSION__` directory |
| Mongo exits 132 | The CPU does not expose AVX. Set the hypervisor CPU to host passthrough and reboot |
| Port 8080 is taken | Set `APIGENE_PORT` in `.env` and run `./olgene start` |
| UI loads and the API fails | The browser URL must match `NEXT_PUBLIC_SERVER_BASE_URL`, or `http://localhost:8080` when that variable is unset |
