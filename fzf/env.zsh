#!/bin/sh

if command -v fzf > /dev/null 2>&1; then
	export FZF_BASE=$(which fzf)
	export FZF_DEFAULT_OPTS='--height 40%'
fi
