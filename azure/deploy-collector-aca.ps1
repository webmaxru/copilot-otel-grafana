<#
.SYNOPSIS
  Option D: deploy the OTel Collector to Azure Container Apps (Consumption plan, scale-to-zero)
  as a public, token-protected OTLP endpoint that forwards Copilot traces to Application Insights.

  Nothing runs on the developer's machine — VS Code points straight at the ACA endpoint.

.DESCRIPTION
  - Consumption workload profile + minReplicas=0 => no always-running instance, ~$0 when idle
    (ACA's monthly free grant typically covers demo traffic).
  - Public HTTPS ingress on port 4318, protected by a shared Bearer token (bearertokenauth).
  - Requires Application Insights to already exist (run setup-azure.ps1 first).
  - Writes the endpoint + token + ready-to-paste VS Code env vars to ..\.env.aca (git-ignored).

.EXAMPLE
  ./deploy-collector-aca.ps1 -ResourceGroup rg-ghcp-otel -NamePrefix ghcpotel
#>
[CmdletBinding()]
param(
  [string]$SubscriptionId = (az account show --query id -o tsv),
  [string]$Location       = "swedencentral",
  [string]$ResourceGroup  = "rg-ghcp-otel",
  [string]$NamePrefix     = "ghcpotel",
  [string]$IngestToken    = ""
)

$ErrorActionPreference = "Stop"
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

$appi    = "$NamePrefix-appi"
$law     = "$NamePrefix-law"
$acaEnv  = "$NamePrefix-acaenv"
$acaApp  = "$NamePrefix-collector"
$cfgPath = Join-Path $PSScriptRoot "..\config\otel-collector-cloud.yaml"
$outFile = Join-Path $PSScriptRoot "..\.env.aca"

az account set --subscription $SubscriptionId | Out-Null

if (-not $IngestToken) {
  $bytes = [byte[]]::new(32)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  $IngestToken = -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

Step "Reading Application Insights connection string ($appi)"
$connStr = az monitor app-insights component show -g $ResourceGroup -a $appi --query connectionString -o tsv
if (-not $connStr) { throw "Application Insights '$appi' not found in '$ResourceGroup'. Run setup-azure.ps1 first." }

Step "Ensuring providers + containerapp extension"
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.OperationalInsights --wait
az extension add --upgrade -n containerapp 2>$null

Step "Creating Container Apps environment $acaEnv (Consumption; logs -> $law)"
$lawCustomerId = az monitor log-analytics workspace show -g $ResourceGroup -n $law --query customerId -o tsv
$lawKey        = az monitor log-analytics workspace get-shared-keys -g $ResourceGroup -n $law --query primarySharedKey -o tsv
az containerapp env create -g $ResourceGroup -n $acaEnv -l $Location `
  --logs-destination log-analytics --logs-workspace-id $lawCustomerId --logs-workspace-key $lawKey | Out-Null
$envId = az containerapp env show -g $ResourceGroup -n $acaEnv --query id -o tsv

Step "Building container app manifest (scale-to-zero, token-protected OTLP :4318)"
$cfgIndented = ((Get-Content $cfgPath -Raw) -replace "`r","" -split "`n" | ForEach-Object { "          $_" }) -join "`n"
$manifest = @"
location: $Location
properties:
  managedEnvironmentId: $envId
  configuration:
    activeRevisionsMode: Single
    ingress:
      external: true
      targetPort: 4318
      transport: auto
      allowInsecure: false
    secrets:
      - name: otelcol-config
        value: |
$cfgIndented
      - name: ingest-token
        value: "$IngestToken"
      - name: appi-conn
        value: "$connStr"
  template:
    containers:
      - name: otelcol
        image: otel/opentelemetry-collector-contrib:0.155.0
        args:
          - "--config=env:OTELCOL_CONFIG"
        resources:
          cpu: 0.5
          memory: 1.0Gi
        env:
          - name: OTELCOL_CONFIG
            secretRef: otelcol-config
          - name: INGEST_TOKEN
            secretRef: ingest-token
          - name: APPLICATIONINSIGHTS_CONNECTION_STRING
            secretRef: appi-conn
    scale:
      minReplicas: 0
      maxReplicas: 2
"@
$manifestPath = Join-Path ([System.IO.Path]::GetTempPath()) "aca-collector-manifest.yaml"
$manifest | Out-File -FilePath $manifestPath -Encoding ascii

Step "Deploying container app $acaApp"
az containerapp create -g $ResourceGroup -n $acaApp --yaml $manifestPath | Out-Null
Remove-Item $manifestPath -ErrorAction SilentlyContinue

$fqdn     = az containerapp show -g $ResourceGroup -n $acaApp --query properties.configuration.ingress.fqdn -o tsv
$endpoint = "https://$fqdn"

Step "Writing $outFile (git-ignored)"
@"
# Option D - Azure Container Apps collector. LOCAL ONLY - do not commit.
OTLP_ENDPOINT=$endpoint
INGEST_TOKEN=$IngestToken

# Set these as environment variables for VS Code (restart VS Code afterwards).
# Headers are env-var only for the Copilot client - there is no settings.json key.
#   OTEL_EXPORTER_OTLP_ENDPOINT = $endpoint
#   OTEL_EXPORTER_OTLP_HEADERS  = Authorization=Bearer $IngestToken
#   COPILOT_OTEL_ENABLED        = true
"@ | Out-File -FilePath $outFile -Encoding ascii

Write-Host "`nDONE." -ForegroundColor Green
Write-Host "  OTLP endpoint : $endpoint"
Write-Host "  Bearer token  : $IngestToken"
Write-Host "  Details       : $outFile"
Write-Host "`nPoint VS Code at it (PowerShell, user-level env vars, then restart VS Code):"
Write-Host "  setx OTEL_EXPORTER_OTLP_ENDPOINT `"$endpoint`""
Write-Host "  setx OTEL_EXPORTER_OTLP_HEADERS  `"Authorization=Bearer $IngestToken`""
Write-Host "  setx COPILOT_OTEL_ENABLED        `"true`""
Write-Host "`nView data: Azure Monitor -> Dashboards with Grafana -> GitHub Copilot."
