# Copilot instructions — copilot-otel-grafana

OpenTelemetry-for-GitHub-Copilot observability experiment: turn Copilot's OTel signals into Grafana
dashboards across the surfaces that emit them — **VS Code** (`service.name = copilot-chat`) and the
**GitHub Copilot CLI** (`service.name = github-copilot`) — over four backends (A local Docker, B Azure
with a local collector, C Azure Container Apps collector, D Grafana Cloud). Prompt-cache hit rate is the
headline metric.

## REQUIRED: keep the promo page in sync with the README

`docs/index.html` is the public **promo landing page** (served via GitHub Pages) and is the visual mirror
of `README.md`. **Whenever you change `README.md`, make the matching change in `docs/index.html` — and
vice versa. The two must never contradict each other.** This applies to:

- the surfaces that emit OTel and their `service.name` values;
- the honest surface-coverage list (what does / does not emit OTel today);
- the four backend options (A/B/C/D), their descriptions, and cost;
- "what you can monitor", the data-privacy statements, and the quick-start steps;
- repository and article links, and any headline claims/wording.

After editing either file, re-read the other and reconcile before finishing. Do not let the landing page
drift from the README.

## Other conventions

- **Never commit secrets.** `.env` and `.env.aca` are git-ignored (App Insights connection string,
  Grafana Cloud / ACA bearer tokens). Local APM tooling (`.agents/`, `apm.yml`, `apm.lock.yaml`,
  `.github/prompts/`, `apm_modules/`) is git-ignored — don't `git add -A` it back in; **stage files
  explicitly**.
- **Dashboards.** `dashboards/tempo/copilot-otel-tempo.json` (TraceQL) is auto-provisioned into the local
  Grafana and uploadable to Grafana Cloud; `dashboards/appinsights/copilot-otel-appinsights.json` (KQL)
  is for Azure Monitor. Both carry a **Copilot surface** selector (`All (VS Code + CLI)` / `VS Code` /
  `Copilot CLI`) filtering on `resource.service.name` (TraceQL) or `cloud_RoleName` (KQL).
- **Honest scope.** Only VS Code, the CLI, and the SDK emit customer-collectable OTel today. Don't
  reintroduce "all surfaces" overclaiming (Visual Studio, JetBrains, the Copilot app, and the cloud
  coding agent are not covered).
- **Discovery / SEO.** `docs/` also ships crawler + AI-agent discovery: `sitemap.xml`, `robots.txt`
  (welcomes major AI agents), `llms.txt`, `site.webmanifest`, favicons/PWA icons, a branded `404.html`,
  and JSON-LD + Open Graph/Twitter tags in `index.html`. The canonical origin is the custom domain in
  `docs/CNAME` — currently `https://copilot-opentelemetry.isainative.dev/` (served at the root). Keep
  **every absolute URL** (canonical, `og:*`, `twitter:*`, JSON-LD `@id`/`url`, sitemap `<loc>`, the
  robots `Sitemap:` line, and the `llms.txt` landing link) pointing at that origin; if the title,
  description, or social image change, update `index.html`, `site.webmanifest`, and `llms.txt` together.
  Regenerate icons with `python scripts/generate-icons.py` (don't hand-edit the PNG/ICO), and preserve
  `docs/CNAME`.
- **Site analytics (cookieless RUM).** The promo site is instrumented with cookieless Azure Application
  Insights via `@webmaxru/cookieless-insights` (a `navigator.sendBeacon` beacon — no cookies, no storage,
  no persistent id, no banner). `src/analytics.js` is bundled by `npm run build` (esbuild) into
  `docs/analytics.js` — a **git-ignored build artifact** — with the connection string injected from
  `APPINSIGHTS_CONNECTION_STRING` (a **public client key**: local `.env`, or the CI repo **variable** of
  the same name; never a secret, never committed). GitHub Pages deploys via the
  `.github/workflows/deploy-pages.yml` **Actions** workflow (Pages `build_type=workflow`) — don't switch
  Pages back to a branch build or `analytics.js` won't be generated. One-line **kill switch**:
  `ANALYTICS_ENABLED = false` in `src/analytics.js`. Keep the tracked-event list and the "no cookies / no
  PII" wording in sync across `src/analytics.js`, the `index.html` footer note, and the README "Watching
  the promo site" section. Report with `npm run report` (App Insights `ghcpotel-web-ai`, RG
  `rg-ghcp-otel`).
