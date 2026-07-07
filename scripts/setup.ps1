#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create free-tier Azure resources for cookieless-insights: a resource group,
    a workspace-based Application Insights (30-day retention) with a 0.16 GB/day
    ingestion cap, then print the connection string. (PowerShell alternative to
    `cookieless-insights setup --run`.)

.EXAMPLE
    pwsh scripts/setup.ps1 -Name my-site -Location westeurope
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Location = 'westeurope',
    [string]$ResourceGroup = ''
)
$ErrorActionPreference = 'Stop'

if (-not $ResourceGroup) { $ResourceGroup = "$Name-rg" }
$law = "$Name-law"
$ai  = "$Name-ai"

Write-Host "==> Resource group $ResourceGroup ($Location)" -ForegroundColor Cyan
az group create -n $ResourceGroup -l $Location -o table

Write-Host "==> Log Analytics workspace $law (30-day retention = free)" -ForegroundColor Cyan
az monitor log-analytics workspace create -g $ResourceGroup -n $law -l $Location --retention-time 30 -o table

Write-Host "==> Cap daily ingestion at 0.16 GB (under the 5 GB/month free grant)" -ForegroundColor Cyan
az monitor log-analytics workspace update -g $ResourceGroup --workspace-name $law --quota 0.16 -o table

Write-Host "==> Workspace-based Application Insights $ai" -ForegroundColor Cyan
$wsid = az monitor log-analytics workspace show -g $ResourceGroup -n $law --query id -o tsv
az monitor app-insights component create --app $ai -g $ResourceGroup -l $Location --workspace $wsid --kind web --application-type web -o table

$cs = az monitor app-insights component show --app $ai -g $ResourceGroup --query connectionString -o tsv
Write-Host "`nConnection string (set as VITE_APPINSIGHTS_CONNECTION_STRING at build time):" -ForegroundColor Green
Write-Host $cs

$aiId = az monitor app-insights component show --app $ai -g $ResourceGroup --query id -o tsv
Write-Host "`nNext: deploy the dashboard" -ForegroundColor DarkGray
Write-Host "  cookieless-insights dashboard --app-insights-id $aiId"
