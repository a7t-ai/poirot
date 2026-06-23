<h1 align="center">POIROT — Feature Showcase</h1>

<p align="center">
  <strong>A visual tour of every feature in Poirot.</strong><br/>
  For installation, architecture, and contributing info, see the <a href="README.md">README</a>.
</p>

---

## Session Analytics
Track your Claude Code usage with visual dashboards. See token consumption, cost breakdowns, model distribution, and session trends — all computed locally from your transcript data.

<p align="center">
  <img src="assets/showcase/02-analytics.png" alt="Session Analytics" width="720" />
</p>

---

## Usage Limits
See how much of your subscription you've used at a glance. Poirot surfaces the 5-hour and 7-day rate-limit windows as ring gauges with utilization percentages and reset countdowns — green, amber, and red as you approach the limit. The same gauges appear in the menu bar companion. There's no login: Poirot reuses the OAuth token Claude Code already stores on your Mac, so it stays true to "no login, no tracking."

<p align="center">
  <img src="assets/showcase/27-usage-limits.png" alt="Usage Limits" width="720" />
</p>

---

## Session History Browser
Browse all your Claude Code sessions grouped by project in a dedicated sessions tab. Timestamps, token counts, model info — everything at a glance with search, sort, and agent session filtering.

<p align="center">
  <img src="assets/showcase/03-session-browser.png" alt="Session History Browser" width="720" />
</p>

---

## Multi-Agent Session Grouping
Sub-agent sessions are automatically grouped under their parent session. Expand any parent to see its spawned agents — Explore, Plan, and others — with type badges, descriptions, and token counts. A timeline view shows all sessions as a Gantt chart, so you can see what ran in parallel.

<p align="center">
  <img src="assets/showcase/26-multi-agent-sessions.png" alt="Multi-Agent Session Grouping" width="720" />
</p>

---

## Rich Conversation View
Full conversation timeline with user messages, assistant responses, and collapsible tool blocks. Markdown rendering with syntax highlighting, because raw JSONL is not fun to read.

<p align="center">
  <img src="assets/showcase/04-conversation.png" alt="Rich Conversation View" width="720" />
</p>

---

## Tool Block Display
Every tool invocation — Read, Edit, Bash, Write — rendered with its name, icon, file path, and result. Collapsible, copyable, and with smart truncation for long outputs.

<p align="center">
  <img src="assets/showcase/05-tool-blocks.png" alt="Tool Blocks" width="720" />
</p>

---

## Extended Thinking
See Claude's thinking process with collapsible thinking blocks, styled with a distinct purple accent so you can tell reasoning from response.

<p align="center">
  <img src="assets/showcase/06-thinking.png" alt="Extended Thinking" width="720" />
</p>

---

## Fuzzy Search (&#x2318;K)
Search across all sessions, commands, and file paths. A spotlight-style overlay that gets you where you need to go.

<p align="center">
  <img src="assets/showcase/09-search.png" alt="Fuzzy Search" width="720" />
</p>

---

## Slash Commands
Browse and inspect all your slash commands — global ones from `~/.claude/commands/` and project-scoped ones from `.claude/commands/`. See descriptions, arguments, model assignments, and tool permissions at a glance.

<p align="center">
  <img src="assets/showcase/11-commands.png" alt="Slash Commands" width="720" />
</p>

---

## Skills
Explore reusable skill modules with their full documentation. Skills are rendered with markdown frontmatter parsed into structured cards showing descriptions and references.

<p align="center">
  <img src="assets/showcase/13-skills.png" alt="Skills" width="720" />
</p>

---

## MCP Servers
See all configured Model Context Protocol servers with their connection details, tool counts, and scope badges. Quickly check which servers are available globally vs. per-project. Each server displays a live connection status indicator — Connected, Needs Auth, Failed, Unreachable, Starting, or Unknown — with color-coded SF Symbols and animated effects. Status updates automatically by watching the config and auth cache files.

<p align="center">
  <img src="assets/showcase/12-mcp-servers.png" alt="MCP Servers" width="720" />
</p>

---

## Models
Browse all available models with their capabilities. See which model is set as the default and compare options across providers.

<p align="center">
  <img src="assets/showcase/15-models.png" alt="Models" width="720" />
</p>

---

## Sub-agents
Inspect built-in sub-agent configurations. See agent names, descriptions, and how they're wired into your workflow.

<p align="center">
  <img src="assets/showcase/16-sub-agents.png" alt="Sub-agents" width="720" />
</p>

---

## Plugins
View all installed Claude plugins with their metadata. Check what's active, discover available extensions, and see plugin details at a glance.

<p align="center">
  <img src="assets/showcase/17-plugins.png" alt="Plugins" width="720" />
</p>

---

## Output Styles
Browse and preview output formatting styles. See how each style shapes Claude's responses and which one is currently active.

<p align="center">
  <img src="assets/showcase/18-output-styles.png" alt="Output Styles" width="720" />
</p>

---

## Hooks
View and manage hooks that automate tasks during Claude Code events. See all configured hooks grouped by event type (PreToolUse, PostToolUse, Notification, etc.), with matcher patterns, handler types, and scope badges.

<p align="center">
  <img src="assets/showcase/24-hooks.png" alt="Hooks" width="720" />
</p>

---

## File History
Browse versioned file snapshots captured during Claude Code sessions. See all modified files with version timelines, and inspect diffs between each version to understand exactly what changed and when.

<p align="center">
  <img src="assets/showcase/25-file-history.png" alt="File History" width="720" />
</p>

---

## Session TODOs
See all Claude Code per-session todo lists at a glance. Cards show task status (pending, in progress, completed), and you can jump straight to the associated session or delete orphaned entries.

<p align="center">
  <img src="assets/showcase/19-todos.png" alt="Session TODOs" width="720" />
</p>

---

## Plans
Browse your `~/.claude/plans/` markdown files with rendered markdown or raw text views. Copy content, delete files, and search across all plans — with real-time file watching so new plans appear automatically.

<p align="center">
  <img src="assets/showcase/20-plans.png" alt="Plans" width="720" />
</p>

---

## Debug Log Viewer
Diagnose MCP server issues, permission failures, and startup problems with the per-session debug log viewer. Accessible from the session toolbar, it parses `~/.claude/debug/<sessionId>.txt` files with color-coded log levels (DEBUG in gray, WARN in amber, ERROR in red), full-text search, level filtering, and auto-scroll to the first error. Logs are lazily loaded with paginated fetching for smooth performance on large files. Toggle between absolute and relative timestamps, and copy the full log for sharing in bug reports. Searchable via the universal search overlay.

<p align="center">
  <img src="assets/showcase/21-debug-log.png" alt="Debug Log Viewer" width="720" />
</p>

---

## Prompt History
Browse your entire Claude Code input history from `~/.claude/history.jsonl`. Prompts are grouped by date (Today, Yesterday, This Week, etc.), filterable by project, and searchable with full-text fuzzy matching. Copy any prompt to clipboard for reuse. Live file watching keeps the view up to date.

<p align="center">
  <img src="assets/showcase/21-history.png" alt="Prompt History" width="720" />
</p>

---

## AI Session Summaries
See AI-generated session analysis at the top of each session detail. A collapsible card shows the brief summary, underlying goal, outcome badge, helpfulness rating, session type, goal categories as tags, and friction indicators — all parsed from `~/.claude/usage-data/facets/`. Facets are also searchable via the universal search overlay.

<p align="center">
  <img src="assets/showcase/22-ai-summaries.png" alt="AI Session Summaries" width="720" />
</p>

---

## Memory
Browse Claude Code's auto-memory files per project. MEMORY.md is the main entrypoint loaded into every conversation, and topic files contain detailed notes organized by subject. Filter by project, view rendered markdown, and search across all memories with live file watching.

<p align="center">
  <img src="assets/showcase/23-memory.png" alt="Memory" width="720" />
</p>
