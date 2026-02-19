#!/bin/bash
set -e

# Install discount markdown library (required by Text::Markdown::Discount)
apt-get update
apt-get install -y libmarkdown2-dev

# Install Pandoc (ARM64) for ikiwiki-to-markdown conversion
curl -L https://github.com/jgm/pandoc/releases/download/3.8.3/pandoc-3.8.3-1-arm64.deb -o /tmp/pandoc.deb
dpkg -i /tmp/pandoc.deb
rm /tmp/pandoc.deb

# Clean up apt cache
rm -rf /var/lib/apt/lists/*
