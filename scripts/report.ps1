#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pull cookieless-insights engagement analytics from Azure Application Insights
    to the terminal, and/or open the Portal dashboard. (PowerShell alternative to
    `cookieless-insights report`.)

.EXAMPLE
    pwsh scripts/report.ps1 -ResourceGroup my-site-rg -AppInsights my-site-ai
    pwsh scripts/report.ps1 -ResourceGroup my-site-rg -AppInsights my-site-ai -Days 7 -Open
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$AppInsights,
    [string]$DashboardName = 'cookieless-insights-dashboard',
    [int]$Days = 30,
    [switch]$Open,
    [switch]$OpenOnly
)
$ErrorActionPreference = 'Stop'

function Get-Az([string[]]$AzArgs) {
    $out = & az @AzArgs 2>$null
    if ($LASTEXITCODE -ne 0) { throw "az $($AzArgs -join ' ') failed (exit $LASTEXITCODE)" }
    return ($out | Out-String).Trim()
}

$appId  = Get-Az @('monitor','app-insights','component','show','--app',$AppInsights,'-g',$ResourceGroup,'--query','appId','-o','tsv')
$subId  = Get-Az @('account','show','--query','id','-o','tsv')
$tenant = Get-Az @('account','show','--query','tenantId','-o','tsv')
$dashId = "/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.Portal/dashboards/$DashboardName"
$dashUrl = "https://portal.azure.com/#@$tenant/dashboard/arm$dashId"

function Open-Dashboard { Write-Host "Opening dashboard: $dashUrl" -ForegroundColor Green; Start-Process $dashUrl }
if ($OpenOnly) { Open-Dashboard; return }

$queries = @(
    @{ Title = 'Overview (page views, sessions, events)';
       Query = "union pageViews, customEvents | summarize PageViews=countif(itemType=='pageView'), Events=countif(itemType=='customEvent'), Sessions=dcount(session_Id), Countries=dcount(client_CountryOrRegion)" },
    @{ Title = 'Engagement per visit (events/session, dwell seconds)';
       Query = "union pageViews, customEvents | summarize events=count(), start=min(timestamp), stop=max(timestamp) by session_Id | extend dwellSec=datetime_diff('second', stop, start) | summarize Sessions=count(), MedianEventsPerSession=percentile(events,50), MedianDwellSec=percentile(dwellSec,50), AvgDwellSec=round(avg(dwellSec),1)" },
    @{ Title = 'Key events (by name)';
       Query = "customEvents | summarize Events=count(), Sessions=dcount(session_Id) by Event=name | sort by Events desc" },
    @{ Title = 'Top pages';
       Query = "pageViews | summarize Views=count(), Sessions=dcount(session_Id) by Page=name | sort by Views desc | take 15" },
    @{ Title = 'Top countries';
       Query = "pageViews | summarize Sessions=dcount(session_Id) by Country=client_CountryOrRegion | sort by Sessions desc | take 15" },
    @{ Title = 'Browser & OS';
       Query = "pageViews | summarize Sessions=dcount(session_Id) by Browser=client_Browser, OS=client_OS | sort by Sessions desc | take 20" }
)

Write-Host ("`ncookieless-insights - engagement (last {0} days)" -f $Days) -ForegroundColor White
Write-Host ("App Insights: {0}  |  RG: {1}" -f $AppInsights, $ResourceGroup) -ForegroundColor DarkGray

foreach ($q in $queries) {
    Write-Host "`n== $($q.Title) ==" -ForegroundColor Cyan
    try {
        $json = Get-Az @('monitor','app-insights','query','--app',$appId,'--analytics-query',$q.Query,'--offset',"$($Days)d",'-o','json')
        $table = ($json | ConvertFrom-Json).tables[0]
        if (-not $table -or $table.rows.Count -eq 0) { Write-Host '  (no data yet)' -ForegroundColor DarkGray; continue }
        $cols = @($table.columns.name)
        $rows = foreach ($row in $table.rows) {
            $o = [ordered]@{}
            for ($i = 0; $i -lt $cols.Count; $i++) { $o[$cols[$i]] = $row[$i] }
            [pscustomobject]$o
        }
        ($rows | Format-Table -AutoSize | Out-String).TrimEnd() | Write-Host
    } catch {
        Write-Host "  query failed: $_" -ForegroundColor Red
    }
}

Write-Host "`nDashboard: $dashUrl" -ForegroundColor DarkGray
if ($Open) { Open-Dashboard }
