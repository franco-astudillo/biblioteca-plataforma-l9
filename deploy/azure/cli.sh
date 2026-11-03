#!/usr/bin/env bash
# Azure CLI oficial en Docker, sin instalarla en Windows. La sesion queda local e ignorada por Git.
# Desde la plataforma:
#   bash deploy/azure/cli.sh az version
#   bash deploy/azure/cli.sh az login --use-device-code
#   REGION=northcentralus bash deploy/azure/cli.sh bash deploy/azure/verificar-region.sh
set -euo pipefail
export MSYS_NO_PATHCONV=1
PLATAFORMA="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="$PLATAFORMA/.azure-local"
mkdir -p "$CONFIG"
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  MONTAR_PLATAFORMA="$(cd "$PLATAFORMA" && pwd -W)"
  MONTAR_CONFIG="$(cd "$CONFIG" && pwd -W)"
else
  MONTAR_PLATAFORMA="$PLATAFORMA"
  MONTAR_CONFIG="$CONFIG"
fi
docker run --rm -i \
  --mount "type=bind,source=$MONTAR_PLATAFORMA,target=/trabajo" \
  --mount "type=bind,source=$MONTAR_CONFIG,target=/root/.azure" \
  --workdir /trabajo \
  -e AZURE_CORE_LOGIN_EXPERIENCE_V2=off \
  -e REGION="${REGION:-northcentralus}" \
  mcr.microsoft.com/azure-cli:azurelinux3.0 "$@"
