# APM Manifest And Lockfile Notes

Use this file when the request involves editing `apm.yml`, understanding canonical dependency forms, or explaining what `apm.lock.yaml` guarantees.

## apm.yml essentials

Minimum required fields:

```yaml
name: my-project
version: 1.0.0
```

Useful optional top-level fields:

```yaml
description: Shared AI-native project setup
author: Contoso
target: all
type: hybrid
scripts:
  review: codex review.prompt.md
dependencies:
  apm: []
  mcp: []
compilation:
  target: all
  exclude:
    - apm_modules/**
```

## Dependency guidance

Prefer these patterns:

* Use `owner/repo` for a full GitHub-hosted package with rules, skills, prompts, hooks, and MCP config.
* Use `owner/repo/path/to/skill` for a single skill, plugin, or agent stored in a repo subdirectory.
* Reference individual agent files directly with their full path including the file extension, e.g. `owner/repo/agents/name.agent.md`.
* Append `#ref` to any GitHub path form when you need a pinned tag or branch, e.g. `owner/repo/plugins/name#v2.1`.
* Use a plain path string for Azure DevOps (`dev.azure.com/org/project/_git/path`) or Bitbucket (`bitbucket.org/team/repo#ref`) when no extra options are needed — the same shorthand style as GitHub.
* Use the `git:` object form for GitLab, Gitea, self-hosted git, or any non-GitHub host that needs explicit `path`, `ref`, or `alias` options alongside a full `https://` URL.
* Use pinned refs for team-critical dependencies that must not drift unexpectedly.
* Use local paths only for short-lived development loops.

Examples:

```yaml
dependencies:
  apm:
    # Full package (rules, skills, prompts, hooks)
    - microsoft/apm-sample-package
    # Single skill by subdirectory path
    - anthropics/skills/skills/frontend-design
    # Plugin with a pinned tag
    - github/awesome-copilot/plugins/context-engineering#v2.1
    # Individual agent file
    - github/awesome-copilot/agents/api-architect.agent.md
    # Azure DevOps plain-string shorthand
    - dev.azure.com/acme/platform/_git/prompts/review.prompt.md
    # Bitbucket plain-string shorthand with ref
    - bitbucket.org/team/agent-rules#main
    # GitLab or Gitea with git: object form (full URL + path + ref + alias)
    - git: https://gitlab.com/acme/repo.git
      path: instructions/security
      ref: v2.0
      alias: acme-sec
    # Gitea self-hosted
    - git: https://gitea.example.com/team/repo.git
      path: instructions/style
      ref: main
  mcp:
    - io.github.github/github-mcp-server
    - name: internal-knowledge-base
      registry: false
      transport: http
      url: "${KNOWLEDGE_BASE_URL}"
      env:
        KB_TOKEN: "${KB_TOKEN}"
```

## Lockfile rules

Treat `apm.lock.yaml` as the exact resolved state of the dependency graph.

Key properties:

* It records resolved commits, refs, and content hashes.
* It tracks direct and transitive dependency depth.
* It records `deployed_files`, which drive safe uninstall and prune behavior.
* It should be committed for reproducible installs across developers and CI.

Operational consequences:

* `apm install` without `--update` prefers the lockfile.
* `apm install --update` or `apm deps update` re-resolves and refreshes the lockfile.
* `apm pack` reads from the lockfile and expects the listed deployed files to exist on disk.
* `apm uninstall` and `apm prune` remove only files tracked in the lockfile’s deployed file manifest.

## Policy governance

`apm-policy.yml` is an optional file that applies install-time policy, including transitive MCP server gating. Inheritance flows enterprise → org → repo and is tighten-only (a downstream policy can only add restrictions, never relax them).

Key points:
* Policy is enforced automatically at `apm install`; no extra command is needed.
* Transitive MCP servers that violate policy are blocked before they reach disk.
* See the [Governance Guide](https://microsoft.github.io/apm/enterprise/governance-guide/) for enterprise configuration.

## Official reference map

Use the official APM docs in this order when deeper details are needed:

* Quick start: `https://microsoft.github.io/apm/quickstart/`
* CLI commands: `https://microsoft.github.io/apm/reference/cli-commands/`
* Manifest schema: `https://microsoft.github.io/apm/reference/manifest-schema/`
* Dependencies and lockfile guide: `https://microsoft.github.io/apm/guides/dependencies/`
* Compilation guide: `https://microsoft.github.io/apm/guides/compilation/`
* Pack and distribute guide: `https://microsoft.github.io/apm/guides/pack-distribute/`
* Governance guide: `https://microsoft.github.io/apm/enterprise/governance-guide/`