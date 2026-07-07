---
name: cookieless-insights
description: Instrument any static website (SPA) with cookieless Azure Application Insights Real User Monitoring — no cookie/GDPR banner, free tier only — using the @webmaxru/cookieless-insights package + CLI. Covers Azure setup, code wiring (incl. build step), a Portal dashboard, and a terminal engagement report. WHEN making a static site/SPA observable, "add analytics without a cookie banner", cookieless RUM, privacy-friendly analytics, Application Insights for a frontend/GitHub Pages/Static Web Apps/Netlify/S3, page views + engagement + geo + key events.
version: 1.0.1
author: webmaxru
license: MIT
---

# Instrument a static site with cookieless Azure Application Insights

> **Sample request prompt:** see [`PROMPT.md`](./PROMPT.md) for a ready-to-paste prompt. Once
> this skill is installed, "Instrument this static site with cookieless-insights" is enough.


Use the **`@webmaxru/cookieless-insights`** package + CLI to give any static front end
privacy-friendly Real User Monitoring that needs **no cookie/GDPR banner** and stays on
Azure's **free tier**. Work autonomously; state assumptions instead of asking.

## Why this approach (validated against Microsoft Learn)
- A static site is **browser-only** — the Azure Monitor **OpenTelemetry Distro is
  server-side only** (ASP.NET Core/Java/Node.js/Python). Browser telemetry uses the
  **Application Insights JavaScript SDK** path (RUM). `@webmaxru/cookieless-insights`
  wraps this: a tiny dependency-free **beacon** by default (~1–2 KB gzipped) or an optional
  SDK adapter.
- **Cookieless** = no cookies, no local/session storage, no persistent id → no consent
  banner. The beacon is cookieless by construction; the SDK adapter sets
  `disableCookiesUsage` + `enableSessionStorageBuffer:false`.
- **Free tier** = workspace-based Application Insights, 30-day retention, and a **0.16 GB/day**
  ingestion cap (Microsoft's documented "160 MB/day stays under the 5 GB/month free grant").

## Steps

1. **Discover** the project: framework, build tool, hosting, deploy workflow, and the single
   **state/store choke point** (Zustand/Redux/Pinia/signals) or top-level event handlers to
   wire events into. Enumerate key events (page view, meaningful controls — debounce
   sliders/typing —, presets, add/remove, outbound clicks, "opened via shared link").

2. **Provision Azure** (reuse a project resource group if it exists, else create one):
   ```
   npx cookieless-insights setup --name <project> --location <region> --run
   ```
   Capture the printed **connection string** (a public client key).

3. **Install + wire** (framework-agnostic):
   ```
   npm i @webmaxru/cookieless-insights
   ```
   ```ts
   import { init, trackEvent, trackChangeDebounced } from '@webmaxru/cookieless-insights';
   init({ connectionString: import.meta.env.VITE_APPINSIGHTS_CONNECTION_STRING });
   // wire trackEvent(...) at the store choke point + trackChangeDebounced for sliders/typing.
   ```
   For the heavier official SDK instead of the beacon:
   `import { initAppInsights } from '@webmaxru/cookieless-insights/appinsights'` (install the
   `@microsoft/applicationinsights-web` peer dep).
   **Kill switch:** `init({ ..., enabled: false })` disables all telemetry.

4. **Build step / deploy:** the connection string is a **public client key** — provide it at
   build time. Locally via `.env` (`VITE_APPINSIGHTS_CONNECTION_STRING=...`); in CI as a repo
   **variable** passed to the build step (never a secret, never committed as source). Verify
   the build succeeds and the site initializes analytics.

5. **Dashboard + report:**
   ```
   npx cookieless-insights dashboard --app-insights-id <appInsightsResourceId>
   npx cookieless-insights report --resource-group <rg> --app-insights <name> --days 30 --open
   ```
   `report` prints engagement (page views, sessions, per-visit dwell, key events, top pages,
   geo, browser/OS) and `--open` launches the Portal dashboard. A `scripts/report.ps1`
   PowerShell equivalent is scaffolded by `cookieless-insights init`.

6. **Ship:** ensure build + tests pass, commit, and push to the deploy branch. After a real
   visit, `report` shows data within ~1–3 minutes.

## Definition of done
- [ ] Cookieless (no cookies/storage, no persistent id) — no banner needed.
- [ ] Free tier: workspace-based, 30-day retention, 0.16 GB/day cap.
- [ ] Key events wired at the choke point; page view + engagement time collected.
- [ ] Connection string injected at build time (repo variable in CI); kill switch documented.
- [ ] Portal dashboard deployed; `report` prints real data and `--open` works.
- [ ] Built, committed, pushed → deployed.
