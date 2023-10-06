#!/bin/sh

if command -v brew > /dev/null 2>&1; then
	brew() {
		command brew "$@"
	}
fi
