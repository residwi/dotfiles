#!/bin/sh

tools() {
	docker-compose -f "${HOME}/Development/tools/docker-compose.yml" $@
}
