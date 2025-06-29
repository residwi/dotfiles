#!/bin/bash

if command -v brew >/dev/null 2>&1; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

export PGHOST=localhost
