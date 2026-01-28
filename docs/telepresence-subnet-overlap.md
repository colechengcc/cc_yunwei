## Telepresence: “subnet … overlaps with existing route …” (macOS + VPN)

### What it means

Telepresence creates a small **virtual subnet** on your machine (example: `10.245.0.0/24`) and adds routes so it can tunnel traffic to your Kubernetes cluster.  
If you are connected to a VPN that installs a **very broad route** (example: `8.0.0.0/5`), that broad route can *cover* the subnet Telepresence wants to use. Telepresence detects the overlap and aborts to avoid unpredictable routing.

Your error is exactly this:

- Telepresence wanted: `10.245.0.0/24`
- VPN already routed: `8.0.0.0/5` (this range includes `10.245.0.0/24`)

### Confirm on macOS

Run:

```bash
netstat -rn -f inet
```

Look for a route like `8.0.0.0/5` (or equivalent) that points to a `utun*` interface (VPN).

### Fix (recommended): change Telepresence’s virtual subnet to a non-overlapping range

Pick a subnet that your VPN does **not** route. A good choice is the RFC-reserved benchmarking range `198.18.0.0/15` (rarely used by VPN split-tunnel policies).

Try setting Telepresence’s VPN subnet to something like:

- `198.18.0.0/24` (smallest, usually safest)
- `198.18.0.0/16` (larger, if your setup requires)

Then restart Telepresence and reconnect.

#### Using the Telepresence CLI (preferred)

Depending on your Telepresence version, the setting is exposed as a config key under `routing` (commonly `routing.vpnSubnet`).

```bash
telepresence config set routing.vpnSubnet 198.18.0.0/24
telepresence quit
telepresence connect
```

If your Telepresence version uses a different key name, run:

```bash
telepresence config view
```

and search for the current “vpn subnet / virtual subnet” routing setting, then set it to a non-overlapping CIDR.

#### Editing the config file directly (fallback)

On macOS Telepresence stores config under:

- `~/Library/Application Support/telepresence/`

Locate the config file there (often `config.yml`), update the VPN/virtual subnet value to a non-overlapping CIDR (e.g. `198.18.0.0/24`), then:

```bash
telepresence quit
telepresence connect
```

### Alternative fixes

- **Ask your VPN admin** to exclude the Telepresence subnet (or narrow the VPN route). Broad routes like `8.0.0.0/5` are common in corporate VPNs and frequently collide with developer tooling.
- **Disconnect the VPN** while using Telepresence (if allowed).

### Helper script

This repo includes a helper that reads your routing table and suggests a Telepresence subnet that doesn’t overlap:

```bash
python3 scripts/telepresence_route_overlap_check.py
```

