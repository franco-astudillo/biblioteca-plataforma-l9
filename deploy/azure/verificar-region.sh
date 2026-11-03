#!/usr/bin/env bash
# Prueba una region sin usar ni eliminar grupos preexistentes.
# Uso: REGION=northcentralus bash deploy/azure/verificar-region.sh
set -euo pipefail
export MSYS_NO_PATHCONV=1
REGION="${REGION:-northcentralus}"
SALIDA="${SALIDA:-deploy/azure/region.txt}"
GRUPO="ep3-region-$(date -u +%Y%m%d%H%M%S)-$RANDOM"
creado=0
mkdir -p "$(dirname "$SALIDA")"
command -v az > /dev/null || { echo "FALTA Azure CLI: instala az y ejecuta az login"; exit 1; }
az account show --output none
limpiar() {
  if [ "$creado" -eq 1 ]; then
    az group delete --name "$GRUPO" --yes --output none
  fi
}
trap limpiar EXIT
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Network --wait
if [ "$(az group exists --name "$GRUPO" --output tsv | tr -d '\r')" = "true" ]; then
  echo "El grupo de prueba ya existe; no se modifica: $GRUPO"
  exit 1
fi
az group create --name "$GRUPO" --location "$REGION" --output none
creado=1
az network vnet create --resource-group "$GRUPO" --name prueba --location "$REGION" \
  --address-prefixes 10.9.0.0/16 --output none
{
  echo "Region probada con una VNet: $REGION"
  az vm list-skus --location "$REGION" --size Standard_B2a --resource-type virtualMachines --output table
  az vm list-usage --location "$REGION" --output table
  az consumption budget list --output table
} > "$SALIDA"
cat "$SALIDA"
echo "Comprueba B2ats_v2 y B2als_v2 sin restricciones, al menos 4 vCPU y el presupuesto con alerta."
