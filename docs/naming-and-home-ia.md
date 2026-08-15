# L!bra naming & home IA guide

Reference for renaming tools and simplifying the home grid.
Human-facing brand stays **L!bra**; machine IDs stay `Libra`.

This is a product copy / information-architecture guide — not an implementation plan.

---

## 1. Problem

The current names are product codes, not tasks:

| Current | Why it fails |
| --- | --- |
| ProVid | “Pro” is empty marketing; doesn’t say rename |
| VidRes | Abbreviation soup |
| KeepName | CamelCase feature flag, not a tool name |
| ProMax | Sounds like a phone tier |
| MaxVid | Unclear what is “max” |
| 1MinVid | Reads like a format, not an action |
| Slo-Mo | OK-ish, still slangy |
| iPhone Sorter / GPS Sorter | Clearer; “Sorter” is fine |

Five of nine home cards are the same job with different folder/rename knobs. Users must decode brand names *and* compare five blurbs to pick a mode.

**Rule:** a first-time user should name every home control correctly without reading the description.

---

## 2. Naming principles

1. **Task first** — verb or clear outcome (“Sort by resolution”), not a coined product.
2. **One idea per label** — don’t pack resolution + orientation + FPS into a mystery name; put that in options or a subtitle.
3. **Same word = same meaning** — don’t say Photo on Home and Photos on the tool page for the same idea (pick one).
4. **Plain over clever** — Prefer “Preview only” next to a toggle labeled clearly; “Dry Run” is jargon (keep as secondary if needed).
5. **Honest** — Live copy must match what the tool actually does (move / rename / copy).
6. **Machine IDs can stay ugly** — Swift enums (`provid`, `vidres`) and folder names like `SloMo` can remain for compatibility; only UI strings must be plain.

---

## 3. Two shapes for the five sort cards

### Option A — Keep five cards, rename only (smallest change)

Home still shows five Sort & rename cards. Only titles/descriptions/categories change.

| Current title | New title | New short description |
| --- | --- | --- |
| ProVid | Rename in place | Rename files with the L!bra filename format. Optional prefix. |
| VidRes | Sort by resolution | Rename and put files into resolution folders (4K, 1080p, …). |
| KeepName | Sort by resolution (keep names) | Same folders as above; leave original filenames alone. |
| ProMax | Sort by resolution & orientation | Rename into resolution, then landscape / portrait folders. |
| MaxVid | Sort by resolution, orientation & FPS | Rename into resolution, orientation, and frame-rate folders. |

**Category label:** `Sort / Rename` → **`Organize`** (or keep `Sort & rename`).

**When to pick A:** You want clearer copy without touching `Tool` cases or pipelines yet.

---

### Option B — One card + options (recommended)

Replace the five cards with a single home card:

| Title | Description |
| --- | --- |
| **Sort & rename** | Choose how to name files and how deep to nest folders. |

Inside the tool page, controls (not five destinations):

#### Filename

| Control label | Values | Maps from |
| --- | --- | --- |
| **Filename** | Keep original names | KeepName |
| | Use L!bra format | ProVid / VidRes / ProMax / MaxVid |

Help under field when L!bra format is on:

> Example: `katie 720p W30 002.mp4` (prefix optional)

#### Prefix

| Control label | Notes |
| --- | --- |
| **Prefix** | Optional. Same behavior as today’s Prefix field. Hide or disable when “Keep original names” is selected. |

#### Folders

| Control label | Values | Maps from |
| --- | --- | --- |
| **Folders** | None (rename only) | ProVid |
| | Resolution | VidRes / KeepName |
| | Resolution + orientation | ProMax |
| | Resolution + orientation + FPS | MaxVid |

#### Extra folders (existing toggles — rename for clarity)

| Current | New |
| --- | --- |
| Date folders | Also sort by date |
| Camera folders | Also sort by camera |

**When to pick B:** You want fewer home decisions and one honest place for “how deep do folders go?”

---

## 4. Full home grid (after Option B)

Target home (Video tab) — six cards, not nine:

| # | Title | Category | One-line description |
| --- | --- | --- | --- |
| 1 | Sort & rename | Organize | Name files and nest folders by resolution, orientation, FPS. |
| 2 | iPhone sort | Organize | Split into iPhone and Not iPhone folders. |
| 3 | GPS sort | Organize | City folders from location; No-GPS when missing. |
| 4 | Slow motion | Transform | Write slowed copies into a SloMo folder. Needs ffmpeg. |
| 5 | 1-minute stamps | Transform | Stamp sequential 60-second creation times. Needs ffmpeg. |
| 6 | *(optional seventh later)* | — | Only add when a real new job appears. |

Photo tab stays a section, not a “tool code”:

| Current | New |
| --- | --- |
| Photo (tab) | **Photos** (same word everywhere) |
| Pull stills out… | Move photos out of video folders |

---

## 5. Complete string map (current → proposed)

### Tools (`Models.Tool` UI strings)

| Enum / current `title` | Proposed title | Proposed category | Proposed description |
| --- | --- | --- | --- |
| `provid` / ProVid | *(fold into Sort & rename)* or Rename in place | Organize | Rename files in place with the L!bra filename format. Optional prefix. |
| `vidres` / VidRes | *(fold)* or Sort by resolution | Organize | Rename and sort into resolution folders. |
| `keepName` / KeepName | *(fold)* or Sort by resolution (keep names) | Organize | Sort into resolution folders; keep original filenames. |
| `promax` / ProMax | *(fold)* or Sort by resolution & orientation | Organize | Rename into resolution and orientation folders. |
| `maxvid` / MaxVid | *(fold)* or Sort by resolution, orientation & FPS | Organize | Rename into resolution, orientation, and FPS folders. |
| `iphoneSorter` / iPhone Sorter | iPhone sort | Organize | Split videos into iPhone / Not iPhone folders. |
| `gps` / GPS Sorter | GPS sort | Organize | Sort into city folders from GPS, or No-GPS when missing. |
| `slomo` / Slo-Mo | Slow motion | Transform | Write slow-motion copies into a SloMo folder. |
| `oneMin` / 1MinVid | 1-minute stamps | Transform | Stamp sequential 60-second creation times (copies or replace originals). |

**Drop category `Analyze`** for iPhone/GPS — those tools move files; calling them Analyze is dishonest.

### Tool page chrome

| Current | Proposed |
| --- | --- |
| Dry Run | **Preview only** (toggle label). Keep “Dry Run” only in Settings if you must, or rename Settings too. |
| Preview only — nothing will be moved. | Preview only — nothing will be changed. |
| Live — files will be renamed or moved. | **Live — files will be renamed, moved, or copied** (or tool-specific: Slow motion → “Live — new slowed copies will be written.”) |
| Factor | Slow-down speed |
| 0.5x / 0.25x | Half speed / Quarter speed (keep `0.5x` as secondary) |
| Mode → Copies / In place | Output → New copies / Change originals |
| Start time | First timestamp |
| Prefix | Prefix (unchanged) |
| Date folders / Camera folders | Also sort by date / Also sort by camera |
| Back | Back |
| Undo last run | Undo last run |
| Move photos out… | Move photos out… |
| Drop videos here | Drop videos here |
| Dependencies missing. | Can’t scan yet — media tools missing. |
| Install | Install ffmpeg… (and confirm what Homebrew will install) |

### Count pills

| Current pill | Proposed | Why |
| --- | --- | --- |
| Files | Files | OK |
| GPS | Has location | “GPS” is jargon for some users |
| iPhone (on general tools) | Apple device | Filter is Apple make **or** iPhone model — “iPhone” overclaims |
| Apple | Apple make | Clearer on iPhone sort |
| iPhone (model pill) | iPhone model | Disambiguate from Apple make |
| Both | Apple make + iPhone model | “Both” is opaque |
| Duplicates | Likely duplicates | Matches heuristic honesty |
| FHD **and** 1080p | Pick **one** label (prefer `1080p`) | Two names for one class confuse filters |

### Settings

| Current | Proposed |
| --- | --- |
| ffmpeg / ffprobe | Media tools (ffmpeg / ffprobe) |
| Dry-run by default | Preview only by default |
| Default prefix | Default prefix |
| Date folders / Camera folders | Also sort by date / Also sort by camera (defaults) |
| File Extensions | Video extensions |
| Auto-detect from Homebrew | Find Homebrew installs |

### Home chrome

| Current | Proposed |
| --- | --- |
| L!bra | L!bra (keep) |
| Video organization toolkit | Organize videos on your Mac (optional clearer subtitle) |
| Video / Photo | Video / Photos |
| ffprobe missing — … Install | Can’t scan — install ffmpeg (includes ffprobe). |

---

## 6. Old tool → new mode (migration cheat sheet)

For Option B, keep enum cases internally if you want; expose one UI tool with mode flags:

| Old tool | Filename | Folders |
| --- | --- | --- |
| ProVid | L!bra format | None |
| VidRes | L!bra format | Resolution |
| KeepName | Keep original | Resolution |
| ProMax | L!bra format | Resolution + orientation |
| MaxVid | L!bra format | Resolution + orientation + FPS |

Dry-run reports and any “L!bra ProVid Dry Run 1.txt” style names can keep a **machine mode id** (`provid`, etc.) while the UI shows **Sort & rename**.

---

## 7. Homebrew vs Swift-only (related product clarity)

Naming “Install” without explaining Homebrew is part of the honesty problem. Product stance options:

| Stance | What users see | Fits naming how |
| --- | --- | --- |
| **Swift-first scan** (AVFoundation / ImageIO) | No install banner for Sort / iPhone / GPS | Home stays about organizing, not package managers |
| **ffmpeg optional** | Slow motion & 1-minute stamps show “Needs ffmpeg” in the description | Transform cards stay honest |
| **Brew required for all** | Every scan blocked on ffprobe | Worst first-run; avoid if you care about plain Home |

Recommended pairing with this guide:

- Organize tools (Sort & rename, iPhone, GPS, Photos): **no Homebrew required** long-term.
- Transform tools: say **Needs ffmpeg** in the card description; Install confirms `brew install ffmpeg`.

---

## 8. What not to rename (yet)

Leave alone unless packaging/docs require it:

- `Brand.displayName` = `L!bra`
- GitHub repo `Libra`, `appId`, executable `Libra`
- On-disk folder names produced by tools (`SloMo`, `No-GPS`, resolution folder names) — changing these is a behavior break, not a label tweak
- Swift type / enum case names (`Tool.provid`) — internal

---

## 9. Acceptance checks

Before shipping the rename:

1. Cover the home titles; can a stranger match each card to a job?  
2. No home title contains Pro / Max / Vid as decoration.  
3. Live/Preview sentences match move vs rename vs copy per tool.  
4. Photo/Photos wording is singular-or-plural consistently.  
5. iPhone pill labels match the actual filter (make vs model vs either).  
6. One resolution label for 1920×1080 (`1080p` **or** `FHD`, not both).  
7. Settings and Home use the same words for Preview / date / camera.

---

## 10. Suggested decision

| Topic | Suggestion |
| --- | --- |
| Five sort cards | **Option B** — one **Sort & rename** + Filename / Folders / Prefix |
| Other tools | Plain titles in §4–5 |
| Dry Run | UI: **Preview only**; optional Settings synonym |
| Categories | **Organize** + **Transform** (drop Analyze) |
| Dependencies | Swift-first for organize; ffmpeg called out only on Transform |

When you’re ready to implement, start from `Sources/Libra/Models.swift` (`title` / `description` / `category`) and the home grid in `Sources/Libra/Views/HomeView.swift`, then align `ToolPage`, `CountPills`, and `SettingsView` strings to this map.
