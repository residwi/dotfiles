#!/bin/sh

alias redis-cli="docker run -it --rm redis:alpine redis-cli -h host.docker.internal -p 6379"
