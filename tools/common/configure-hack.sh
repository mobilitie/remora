#!/usr/bin/env bash

set -eu
export LC_ALL=C

iptables -P FORWARD ACCEPT
