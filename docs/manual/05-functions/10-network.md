---
title: Network
manTitle: 5.10 Network
sidebar:
  order: 10
helpKeywords:
- network
---

## gip

    Synopsis:  gip
    Fetches and prints both the public IPv4 and IPv6 address via
    icanhazip.com.

## gip4

    Synopsis:  gip4
    Fetches and prints the public IPv4 address.

## gip6

    Synopsis:  gip6
    Fetches and prints the public IPv6 address. Returns 1 if IPv6 is
    unavailable.

## ping

    Synopsis:  ping [args...]
    Wraps prettyping with --nolegend. Pass --legend to show the legend.
    Falls back to system ping.

    ping google.com

## qr

    Synopsis:  qr [text...]
    Generates a UTF-8 QR code from text or stdin. Uses qrencode locally;
    falls back to the qrenco.de API.

    qr "https://example.com"
    echo "https://example.com" | qr

---
