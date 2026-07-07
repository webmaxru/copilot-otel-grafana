# Sample prompt — request instrumentation

Paste this to your AI coding agent (Copilot CLI, Claude Code, Cursor, …) from the root of the
static site you want to instrument. Edit the **‹bracketed›** parts.

---

> Instrument this static site with **cookieless Azure Application Insights** using the
> **`@webmaxru/cookieless-insights`** package — **no cookie/GDPR banner**, **Azure free tier only**.
>
> - If a resource group for this project already exists, reuse it; otherwise create one
>   (region ‹westeurope›). Provision workspace-based Application Insights with 30-day retention
>   and a 0.16 GB/day ingestion cap.
> - Install the package and initialize it once at the app entry with the connection string from a
>   build-time env var. Wire a **page view** plus **all key interactions** (buttons, toggles,
>   presets, add/remove, and outbound links); **debounce** sliders/typing. Keep a one-line
>   **kill switch** (`enabled`).
> - The connection string is a public client key: inject it at **build time** via a CI **variable**
>   (not a secret), and update the deploy workflow’s build step.
> - Deploy the Azure Portal **engagement dashboard** and add the **report** command.
> - Then build, run tests, commit, and **redeploy**. Keep everything in sync and show me the
>   engagement report once data arrives.
>
> Use the **beacon** transport by default. Validate every Azure/billing claim against official
> Microsoft docs.

---

Prefer the agent to follow the full playbook? Install the skill first (see the repo README:
**Use with an AI agent**), then simply ask: *“Instrument this static site with cookieless-insights.”*
