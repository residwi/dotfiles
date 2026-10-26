#!/bin/bash

if command -v brew >/dev/null 2>&1; then
  export PATH="$PATH:/opt/homebrew/opt/libpq/bin"
fi

export PGHOST=localhost
