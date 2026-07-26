---
title: Media and Utilities
manTitle: 5.13 Media and Utilities
sidebar:
  order: 13
helpKeywords:
- media
---

## dng2avif

    Synopsis:  dng2avif [-i <file>] [-o <file>] [-q <n>] [-s <n>] [input.dng]
    Converts a DNG raw image to a 10-bit HDR AVIF using an ImageMagick,
    ffmpeg, avifenc pipeline with metadata sync via exiftool.

      -i/--input    Input file (or positional arg)
      -o/--output   Output file (default: same name, .avif extension)
      -q/--quality  Quality 0-100 (default 92)
      -s/--speed    Encoding speed 0-10 (default 3)

    dng2avif photo.dng
    dng2avif -q 85 -s 5 -i shot.dng -o out.avif

## steam-dl

    Synopsis:  steam-dl
    Launches Steam under systemd-inhibit, preventing the system from going
    idle or sleeping while a download is in progress.

## spark

    Synopsis:  spark [--min=<n>] [--max=<n>] [numbers...]
    Renders a Unicode sparkline bar chart for a sequence of numbers.
    Reads from stdin if no numbers are given.

    spark 1 1 2 5 14 42
    echo "3 7 2 9 1" | spark

## yt-dlp

    Synopsis:  yt-dlp [args...] URL [URL...]
    Wraps yt-dlp, prepending sane defaults: --sponsorblock-remove all,
    --embed-subs, --embed-metadata, and --embed-thumbnail. Each default
    is suppressed when you already pass that flag, its alias, or its
    negation (e.g. --no-embed-thumbnail drops the thumbnail default;
    --no-sponsorblock or your own --sponsorblock-remove drops ours). All
    other arguments pass through unchanged, and --help falls through to
    real yt-dlp. Opinionated component (C1 aliases); when disabled it
    passes straight through to the system yt-dlp.

    yt-dlp dQw4w9WgXcQ
    yt-dlp --no-embed-thumbnail dQw4w9WgXcQ

---
