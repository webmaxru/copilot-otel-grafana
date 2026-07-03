<#
.SYNOPSIS
  Provisions the *free-to-visualize* Azure backend for the Copilot OTel demo:
  a Log Analytics workspace + Application Insights (the trace sink).

  There is NO paid Grafana instance. You view the dashboards for free in the Azure portal via
  Azure Monitor > Dashboards with Grafana (the same Grafana engine, billed $0).

.DESCRIPTION
  Architecture:
    VS Code -> OTel Collector -> { Grafana Tempo (local), Azure Application Insights }
    Azure portal > Azure Monitor > Dashboards with Grafana -> Azure Monitor data source -> App Insights

  The script is idempotent (safe to re-run). On success it writes the App Insights connection
  string to ..\.env for docker-compose.azure.yml.

  Cost: Log Analytics / Application Insights bill per GB ingested (negligible for a demo).
        No hourly instance charge — unlike Azure Managed Grafana.

.EXAMPLE
  az login
  ./setup-azure.ps1 -Location swedencentral -ResourceGroup rg-ghcp-otel -NamePrefix ghcpotel
#>
[CmdletBinding()]
param(
  [string]$SubscriptionId = (az account show --query id -o tsv),
  [string]$Location       = "swedencentral",
  [string]$ResourceGroup  = "rg-ghcp-otel",
  [string]$NamePrefix     = "ghcpotel"
)

$ErrorActionPreference = "Stop"
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

$law     = "$NamePrefix-law"
$appi    = "$NamePrefix-appi"
$envFile = Join-Path $PSScriptRoot "..\.env"

Step "Using subscription $SubscriptionId"
az account set --subscription $SubscriptionId | Out-Null

Step "Registering resource providers (Microsoft.Insights / Microsoft.OperationalInsights)"
az provider register -n Microsoft.Insights --wait
az provider register -n Microsoft.OperationalInsights --wait

Step "Creating resource group $ResourceGroup ($Location)"
az group create -n $ResourceGroup -l $Location | Out-Null

Step "Creating Log Analytics workspace $law"
az monitor log-analytics workspace create -g $ResourceGroup -n $law -l $Location | Out-Null
$lawId = az monitor log-analytics workspace show -g $ResourceGroup -n $law --query id -o tsv

Step "Creating workspace-based Application Insights $appi"
az monitor app-insights component create -g $ResourceGroup -a $appi -l $Location `
  --workspace $lawId --application-type web | Out-Null
$connStr = az monitor app-insights component show -g $ResourceGroup -a $appi --query connectionString -o tsv

Step "Granting the current user read access (so Dashboards with Grafana can query the data)"
# Not needed if you are already Owner/Contributor, but makes the setup portable to other users.
$me      = az ad signed-in-user show --query id -o tsv
$rgScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
az role assignment create --assignee $me --role "Monitoring Reader"    --scope $rgScope 2>$null | Out-Null
az role assignment create --assignee $me --role "Log Analytics Reader" --scope $rgScope 2>$null | Out-Null

Step "Writing $envFile"
"APPLICATIONINSIGHTS_CONNECTION_STRING=$connStr" | Out-File -FilePath $envFile -Encoding ascii -NoNewline

Write-Host "`nDONE." -ForegroundColor Green
Write-Host "  Application Insights : $appi  (resource group $ResourceGroup)"
Write-Host "  .env written         : $envFile"
Write-Host "`nNext steps:"
Write-Host "  1. docker compose -f docker-compose.yml down          # stop the local-only stack"
Write-Host "  2. docker compose -f docker-compose.azure.yml up -d   # collector -> Tempo + App Insights"
Write-Host "  3. Use Copilot Chat in VS Code for a few minutes."
Write-Host "  4. View the dashboard for FREE in the Azure portal:"
Write-Host "       Azure Monitor -> Dashboards with Grafana -> GitHub Copilot"
Write-Host "       (or open https://aka.ms/amg/dash/gh-copilot). Pick the Azure Monitor data source."
