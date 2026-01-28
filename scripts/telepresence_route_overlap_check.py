#!/usr/bin/env python3
"""
Detects routing-table overlap with Telepresence's chosen virtual subnet and
suggests alternative CIDRs that don't overlap.

This is intentionally lightweight and dependency-free (std lib only).
"""

from __future__ import annotations

import ipaddress
import os
import platform
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterable, List, Optional, Tuple


@dataclass(frozen=True)
class Route:
    network: ipaddress.IPv4Network
    raw: str


def _run(cmd: List[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)


_CIDR_RE = re.compile(
    r"(?P<ip>\d{1,3}(?:\.\d{1,3}){3})\s*/\s*(?P<prefix>\d{1,2})"
)
_SHORT_NETSTAT_RE = re.compile(
    r"^(?P<first>\d{1,3})(?:\.(?P<second>\d{1,3}))?(?:\.(?P<third>\d{1,3}))?(?:\.(?P<fourth>\d{1,3}))?/(?P<prefix>\d{1,2})$"
)


def _parse_ipv4_network(token: str) -> Optional[ipaddress.IPv4Network]:
    token = token.strip()
    if token in ("default", "0/0", "0.0.0.0/0"):
        return ipaddress.IPv4Network("0.0.0.0/0")

    # Full CIDR like 8.0.0.0/5
    m = _CIDR_RE.search(token)
    if m:
        try:
            return ipaddress.IPv4Network(f"{m.group('ip')}/{int(m.group('prefix'))}", strict=False)
        except ValueError:
            return None

    # macOS netstat sometimes shows "8/5" or "10.245/16" style.
    m2 = _SHORT_NETSTAT_RE.match(token)
    if m2:
        octets = []
        for g in ("first", "second", "third", "fourth"):
            v = m2.group(g)
            if v is None:
                break
            octets.append(v)
        while len(octets) < 4:
            octets.append("0")
        try:
            return ipaddress.IPv4Network(f"{'.'.join(octets)}/{int(m2.group('prefix'))}", strict=False)
        except ValueError:
            return None

    return None


def _routes_from_macos_netstat(output: str) -> List[Route]:
    routes: List[Route] = []
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        # Skip headers.
        if line.startswith(("Destination", "Routing", "Internet", "Gateway", "Netif", "Flags")):
            continue
        parts = re.split(r"\s+", line)
        if not parts:
            continue
        net = _parse_ipv4_network(parts[0])
        if net is None:
            continue
        routes.append(Route(network=net, raw=line))
    return routes


def _routes_from_linux_iproute(output: str) -> List[Route]:
    routes: List[Route] = []
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        # Examples:
        # default via 192.168.1.1 dev eth0
        # 10.0.0.0/8 via 10.1.2.3 dev tun0
        first = line.split()[0]
        net = _parse_ipv4_network(first)
        if net is None:
            continue
        routes.append(Route(network=net, raw=line))
    return routes


def get_ipv4_routes() -> List[Route]:
    system = platform.system().lower()
    if system == "darwin":
        out = _run(["netstat", "-rn", "-f", "inet"])
        return _routes_from_macos_netstat(out)
    if system == "linux":
        out = _run(["ip", "-4", "route"])
        return _routes_from_linux_iproute(out)
    raise RuntimeError(f"Unsupported OS: {platform.system()}")


def overlaps(a: ipaddress.IPv4Network, b: ipaddress.IPv4Network) -> bool:
    return a.overlaps(b)


def find_overlaps(target: ipaddress.IPv4Network, routes: Iterable[Route]) -> List[Route]:
    hits = [r for r in routes if overlaps(target, r.network)]
    # Sort broadest first for readability.
    hits.sort(key=lambda r: r.network.prefixlen)
    return hits


def candidate_subnets() -> List[ipaddress.IPv4Network]:
    """
    Candidate Telepresence virtual subnets (/24) to try.

    - Prefer reserved ranges that are unlikely to be routed by VPN policies.
      198.18.0.0/15 is reserved for benchmarking (RFC 2544 / RFC 6815).
    - Provide a few fallbacks across other non-public ranges.
    """
    cidrs = [
        # Reserved benchmark range (preferred).
        "198.18.0.0/24",
        "198.18.1.0/24",
        "198.19.0.0/24",
        "198.19.1.0/24",
        # CGNAT (sometimes used by ISPs, but often not routed by corp VPNs).
        "100.64.0.0/24",
        "100.96.0.0/24",
        # Private ranges (more likely to be claimed by VPN, but useful as last resort).
        "172.31.240.0/24",
        "192.168.255.0/24",
    ]
    return [ipaddress.IPv4Network(c, strict=False) for c in cidrs]


def main(argv: List[str]) -> int:
    # Default Telepresence subnet mentioned in the user error, as a useful check.
    default_tp = ipaddress.IPv4Network(os.environ.get("TELEPRESENCE_VPN_SUBNET", "10.245.0.0/24"), strict=False)

    try:
        routes = get_ipv4_routes()
    except Exception as e:
        print(f"Failed to read routes: {e}", file=sys.stderr)
        return 2

    print(f"Detected {len(routes)} IPv4 routes on {platform.system()}.")
    print()

    hits = find_overlaps(default_tp, routes)
    if hits:
        print(f"Telepresence subnet {default_tp} overlaps with existing routes:")
        for r in hits[:10]:
            print(f"- {r.network}  ({r.raw})")
        if len(hits) > 10:
            print(f"- ... and {len(hits) - 10} more")
    else:
        print(f"Telepresence subnet {default_tp} does NOT overlap with existing routes.")

    print()
    print("Suggested non-overlapping Telepresence subnets to try:")
    any_ok = False
    for cand in candidate_subnets():
        chits = find_overlaps(cand, routes)
        if not chits:
            any_ok = True
            print(f"- {cand}  (example: telepresence config set routing.vpnSubnet {cand})")
    if not any_ok:
        print("- None of the built-in candidates were clean. Your VPN may be routing very broadly.")
        print("  Tip: run with a custom candidate by setting TELEPRESENCE_VPN_SUBNET to test a CIDR, e.g.:")
        print("  TELEPRESENCE_VPN_SUBNET=198.18.2.0/24 python3 scripts/telepresence_route_overlap_check.py")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

