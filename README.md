<p align="center">
  <img src="assets/hero.png" alt="Poirot — Investigating your Claude Code sessions" width="720" />
</p>

<h1 align="center">POIROT</h1>

<p align="center">
  <strong>Investigating your Claude Code sessions.</strong><br/>
  A native macOS companion that lets you browse sessions, explore diffs, and re-run commands — all from a polished SwiftUI interface.
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#capabilities">Capabilities</a> &bull;
  <a href="#getting-started">Getting Started</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#contributing">Contributing</a> &bull;
  <a href="#roadmap">Roadmap</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015%2B-black?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License" />
  <img src="https://img.shields.io/badge/PRs-welcome-E8A642?style=flat-square" alt="PRs Welcome" />
  <img src="https://img.shields.io/github/stars/a7t-ai/poirot?style=flat-square&color=E8A642&label=stars" alt="GitHub Stars" />
</p>

<p align="center">
  No login. No tracking. No analytics. No BYOK. No extra cost. Works offline. Less than 6 MB.
</p>

---

<p align="center">
  <a href="https://youtu.be/JLvNSRZrxdo">
    <img src="https://img.youtube.com/vi/JLvNSRZrxdo/maxresdefault.jpg" alt="Poirot Demo Video" width="720" />
  </a>
  <br/>
  <sub>Click to watch the demo on YouTube</sub>
</p>

---

## The Story

Poirot was **vibe-coded in a weekend**. The entire app — architecture, parser, UI, tests — was built in a single creative burst with Claude Code as the co-pilot. What started as "I wonder if I can build a companion app for Claude Code... using Claude Code" turned into a real, usable tool.

Named after **Hercule Poirot**, Agatha Christie's legendary detective. Because every great investigation needs the right tools — and Poirot helps you investigate exactly what your AI assistant has been up to.

---

## Features

<p align="center">
  <img src="assets/showcase/02-analytics.png" alt="Session Analytics" width="720" />
</p>

<p align="center">
  <img src="assets/showcase/04-conversation.png" alt="Rich Conversation View" width="720" />
</p>

- **Session Analytics** — Token consumption, cost breakdowns, model distribution, and session trends
- **Usage Limits** — Live subscription rate-limit gauges (5-hour and 7-day windows) with utilization and reset countdowns, in the dashboard and menu bar — no login, reusing the token Claude Code already stores
- **Session History Browser** — Sessions grouped by project with timestamps, model info, and token counts
- **Rich Conversation View** — Full timeline with markdown rendering, syntax highlighting, and collapsible tool blocks
- **Tool Block Display** — Every tool invocation rendered with name, icon, file path, and result
- **Extended Thinking** — Collapsible thinking blocks with distinct purple accent
- **Fuzzy Search (&#x2318;K)** — Spotlight-style search across sessions, commands, file paths, and more
- **Slash Commands** — Browse global and per-project commands with descriptions and permissions
- **Skills** — Explore reusable skill modules with parsed frontmatter
- **MCP Servers** — Live connection status indicators with color-coded SF Symbols
- **Models** — Browse available models and their capabilities
- **Sub-agents** — Create, edit, and manage custom sub-agents with tools, model, memory, and system prompt
- **Plugins** — View installed plugins and their metadata
- **Output Styles** — Preview output formatting styles
- **Hooks** — Event hooks grouped by type with matcher patterns and handler details
- **Session TODOs** — Per-session todo lists with status tracking
- **Plans** — Browse `~/.claude/plans/` with rendered markdown and file watching
- **Debug Log Viewer** — Color-coded log levels, search, filtering, and paginated loading
- **Prompt History** — Browse input history with date grouping and project filtering
- **AI Session Summaries** — Goal, outcome, helpfulness, and friction indicators from facets
- **Memory** — Per-project auto-memory files with rendered markdown and live watching

> **See all features with screenshots in the [Feature Showcase](SHOWCASE.md).**

---

## Capabilities

| Category | Feature | Description |
|----------|---------|-------------|
| **Analytics** | Session Analytics Dashboard | Token consumption, cost breakdowns, model distribution, and session trends |
| | Usage Limits | Subscription 5-hour / 7-day rate-limit gauges with reset countdowns; reads Claude Code's existing OAuth token (no login), shown in the dashboard and menu bar |
| **Sessions** | JSONL Transcript Parser | Parses `~/.claude/projects/` transcripts into structured models |
| | Session History Browser | Sessions grouped by project with timestamps, model, token counts |
| | Real-time File Watching | Auto-updates via GCD dispatch sources with 1s debounce |
| | Per-Project Configuration | Supports global (`~/.claude/`) and per-project (`.claude/`) scopes |
| | Session Detail View | Full conversation timeline with collapsible blocks and scroll-to-bottom |
| **Conversation** | Markdown Rendering | Rich text with syntax highlighting via MarkdownUI + HighlightSwift |
| | Code Diff Viewer | Syntax-highlighted inline diffs for Edit tool blocks |
| | Bash Output Renderer | Terminal command output with monospace styling and exit status |
| | Extended Thinking | Collapsible thinking blocks with distinct purple accent |
| | Tool Blocks | Every tool invocation rendered with name, icon, file path, and result |
| | In-Session Search | &#x2318;F to search within the current conversation |
| **Diagnostics** | Debug Log Viewer | Parse and browse `~/.claude/debug/` logs with color-coded levels, search, filtering, and paginated lazy loading |
| | Auto-scroll to Error | Opens directly at the first error entry for quick triage |
| | Relative Timestamps | Toggle between absolute (HH:mm:ss.SSS) and relative (+offset) time display |
| **History** | Prompt History Browser | Browse `~/.claude/history.jsonl` with date grouping, project filtering, full-text search, and copy-to-clipboard |
| **AI Summaries** | Session Facets | AI-generated analysis (goal, outcome, helpfulness) from `~/.claude/usage-data/facets/` |
| | Outcome & Helpfulness Badges | Color-coded badges for success/partial/failure and helpfulness rating |
| | Goal Categories | Tag chips showing categorized session goals with counts |
| | Friction Indicators | Subtle indicators for tool failures, misunderstandings, and other friction |
| | Live File Watching | Auto-updates when new facets appear via GCD dispatch sources |
| **Search** | Universal Search (&#x2318;K) | Fuzzy search across sessions, AI summaries, history, commands, skills, memory, MCP servers, plugins, output styles, models, sub-agents, plans, TODOs, and debug logs |
| | Grouped Results | Results organized by category with counts |
| | Quick Access | Empty state shows shortcuts, counts, and recent sessions |
| **Configuration** | Commands | Browse and manage slash commands (global and per-project) |
| | Skills | Browse and manage reusable skill modules |
| | MCP Servers | Browse configured Model Context Protocol servers with live connection status |
| | Models | Browse available models and capabilities |
| | Sub-agents | Create, edit, duplicate, and delete custom sub-agents with categorized tool selection and memory configuration |
| | Plugins | Browse installed plugins |
| | Output Styles | Browse and manage output style configurations |
| | Hooks | View and manage event hooks grouped by type with matcher patterns and handler details |
| | TODOs | Browse per-session todo lists with status tracking and session navigation |
| | Plans | Browse `~/.claude/plans/` markdown files with rendered/raw toggle, copy, delete, and file watching |
| | Memory | Browse per-project auto-memory files with rendered markdown, project filtering, and file watching |
| | Grid & List Views | Toggle between card grid and compact list layouts |
| | Scope Badges | Visual distinction between Global and Project-scoped items |
| **Integrations** | IDE/Editor | One-click open files in VS Code, Cursor, Xcode, or Zed |
| | Terminal Selection | Pick your terminal: Terminal, iTerm2, Warp, Ghostty, Kitty, Alacritty |
| | Quick Command Re-run | Click any Bash command to copy or open in your terminal |
| **Export** | Session Export | Export sessions as Markdown or PDF with configurable options |
| | Copy Markdown | One-click copy of session content as Markdown to clipboard |
| | Share Sheet | Native macOS share sheet integration for exported files |
| **Sub-agents** | Custom Agent Creation | Full form with name, description, system prompt, model, color, categorized tools, and persistent memory |
| | Auto File Naming | File path auto-derived from agent name (lowercase, dashes); file renamed on edit |
| | Tool Categories | Select tools by category (Read-only, Edit, Execution, Other) or individually |
| | Agent Memory | Configure persistent memory per agent (global or none) |
| | Import/Export | Share agents as JSON files between users |
| | Duplicate | Clone built-in or custom agents as starting points |
| **Navigation** | Font Scaling | ⌘+ / ⌘- / ⌘0 to zoom the entire UI |
| | Keyboard Shortcuts | Full keyboard navigation with discoverable shortcut hints |
| | Help Book (⌘?) | Keyboard reference, feature overview, and getting started guide |
| **App** | Onboarding Flow | First-run welcome with CLI detection, session discovery, and feature tour |
| | Homebrew Distribution | `brew install --cask poirot` with automated release workflow |
| **Design** | Dark Theme | Warm golden accent (`#E8A642`) on near-black backgrounds |
| | SF Symbols | All icons are SF Symbols with bounce, pulse, and replace animations |
| | Design Tokens | Centralized `PoirotTheme` for colors, spacing, radii, and typography |
| **Architecture** | Swift 6 | Strict concurrency with `@MainActor` default isolation |
| | Observation | `@Observable` with `@State` — no `ObservableObject` |
| | Protocol-Driven DI | Services injected via SwiftUI `EnvironmentValues` |
| | Provider System | Extensible `ProviderDescribing` protocol for multi-LLM support |
| | Swift Testing | `@Test`, `#expect`, `#require` with hand-written mocks |

---

## Getting Started

### Install with Homebrew

```bash
brew tap a7t-ai/poirot
brew install --cask poirot
```

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| macOS | 15.0+ | — |
| Xcode | 16.0+ | Mac App Store |

Install SwiftLint and SwiftFormat via Homebrew: `brew install swiftlint swiftformat`.

### Build & Run

```bash
git clone https://github.com/a7t-ai/poirot.git
cd Poirot
brew install swiftlint swiftformat
open Poirot.xcodeproj
```

Hit **&#x2318;R** in Xcode and you're up. Or build from the command line:

```bash
xcodebuild -scheme Poirot -destination 'platform=macOS' -skipMacroValidation build
```

### Run Tests

```bash
xcodebuild test -scheme Poirot -destination 'platform=macOS' -skipMacroValidation
```

Tests use [Swift Testing](https://developer.apple.com/documentation/testing/) (`@Test`, `#expect`, `#require`) — not XCTest.

---

## Architecture

```
Poirot/Sources/
├── App/           # Entry point, ContentView, AppState, Settings
├── Models/        # Value-type structs — Project, Session, Message, ContentBlock
├── Protocols/     # Service protocols (SessionLoading, ProviderDescribing)
├── Services/      # Concrete implementations + SwiftUI Environment DI
│   └── Providers/ # LLM provider configs (ClaudeCodeProvider)
├── Theme/         # Design tokens (PoirotTheme) + Markdown theme
├── Utilities/     # Parsers, terminal launcher
└── Views/         # SwiftUI views organized by feature
    ├── Components/    # Sidebar, StatusBar, Shimmer
    ├── Configuration/ # Config dashboard
    ├── History/       # Prompt history browser
    ├── Home/          # Welcome / empty state
    ├── Memory/        # Memory file browser
    ├── Project/       # Project sessions list
    ├── Plans/         # Plans browser
    ├── Search/        # &#x2318;K overlay
    ├── Session/       # Conversation detail, tool blocks, thinking
    └── Todos/         # Per-session todo overview
```

### Tech Stack

| Layer | Choice |
|-------|--------|
| Language | Swift 6 with strict concurrency |
| UI | SwiftUI + Observation (`@Observable`) |
| Concurrency | `MainActor` default isolation |
| DI | Protocol-driven services via `EnvironmentValues` |
| Markdown | [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) |
| Syntax Highlighting | [HighlightSwift](https://github.com/nicklawls/HighlightSwift) |
| Linting | SwiftLint (strict profile) |
| Formatting | SwiftFormat |
| Testing | Swift Testing with hand-written mocks |

### Design System

Poirot uses a custom dark theme built around a warm golden accent (`#E8A642`) on near-black backgrounds (`#0D0D0F`). All icons are **SF Symbols** with symbol effects (bounce, pulse, replace transitions). Typography scales dynamically with user preference (&#x2318;+/&#x2318;-).

Design tokens live in [`PoirotTheme.swift`](Poirot/Sources/Theme/PoirotTheme.swift) — colors, spacing, radii, and typography all in one place.

### How It Works

```
~/.claude/projects/          Poirot reads JSONL transcripts
        │                    from Claude Code's local storage
        ▼
┌─────────────────┐
│  SessionLoader   │──▶ Discovers projects & session files
└────────┬────────┘
         ▼
┌─────────────────┐
│ TranscriptParser │──▶ Parses JSONL into Session/Message models
└────────┬────────┘
         ▼
┌─────────────────┐
│    AppState      │──▶ Observable state with in-memory caching
└────────┬────────┘
         ▼
┌─────────────────┐
│   SwiftUI Views  │──▶ Sidebar → Session Detail → Tool Blocks
└─────────────────┘
```

---

## Contributing

We welcome contributions of all sizes — bug fixes, new features, documentation, or just fixing a typo.

### Quick Start

1. Fork the repo
2. Create a feature branch from `main`
3. Make your changes with tests
4. Ensure the build passes with zero warnings
5. Ensure all tests pass
6. Ensure SwiftLint passes
7. Open a PR against `main`

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide on code style, architecture conventions, and testing expectations.

### Code Style at a Glance

- **Swift 6** — All types are implicitly `@MainActor` (no manual annotations needed)
- **`@Observable`** with `@State` — not `ObservableObject`
- **SF Symbols only** — No custom icon assets
- **Swift Testing** — `@Test`, `#expect`, `#require` for all new tests
- **Hand-written mocks** — In `PoirotTests/Mocks/`, no mocking frameworks

---

## Roadmap

Poirot is early. There's a lot to build and we'd love your help. Track what's planned and in progress on the [issues page](../../issues).

---

## Community

- **Found a bug?** [Open an issue](../../issues)
- **Have an idea?** [Start a discussion](../../discussions)
- **Want to contribute?** [Read the guide](CONTRIBUTING.md) and send a PR

---

## Acknowledgments

- Built with [Claude Code](https://claude.ai/code) — the tool this app is built to complement
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) for rich text rendering
- [HighlightSwift](https://github.com/nicklawls/HighlightSwift) for code syntax highlighting
- Every SF Symbol that made the UI feel native

---

## License

MIT — see [LICENSE](LICENSE) for details.

No tracking. No analytics. Analyze the code yourself, or ask your Claude to do it. :)

Made with coffee and Claude Code in a weekend.

<p align="center">
  <sub>If you find Poirot useful, consider giving it a star. It helps others discover the project.</sub>
</p>
