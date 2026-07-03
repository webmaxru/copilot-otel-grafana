<#
.SYNOPSIS
  Deletes everything created by setup-azure.ps1 (the whole resource group:
  Log Analytics workspace + Application Insights).

  There is no Grafana instance to delete in this variant — dashboards are viewed for free
  in the Azure portal (Azure Monitor > Dashboards with Grafana), so tearing down the resource
  group removes all remaining cost.

.EXAMPLE
  ./teardown-azure.ps1 -ResourceGroup rg-ghcp-otel
#>
[CmdletBinding()]
param(
  [string]$ResourceGroup = "rg-ghcp-otel"
)
$ErrorActionPreference = "Stop"
Write-Host "Deleting resource group '$ResourceGroup' (Log Analytics + Application Insights)..." -ForegroundColor Yellow
az group delete -n $ResourceGroup --yes --no-wait
Write-Host "Delete submitted (runs in the background). Check with: az group show -n $ResourceGroup" -ForegroundColor Green
Write-Host "Optional: remove the local secret too -> Remove-Item ..\.env"
