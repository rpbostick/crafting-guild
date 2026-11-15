#!/usr/bin/env bash
# The OpenCode 2.x service's password, for a client it did not start: prints it, or prints nothing and exits 1 (see
# oc_service_password in lib.sh for when). The value belongs in the environment, never on a command line.
# Usage: oc-service-password.sh [--note]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
oc_service_password "$@"
