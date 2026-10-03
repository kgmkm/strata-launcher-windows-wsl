# Strata one-click launcher (Windows + WSL)

Start a [Strata](https://github.com/Niko1221/Strata) LLM server that lives **inside WSL**
from a **Windows double-click**, with live load progress — then point any OpenAI- or
Anthropic-compatible client (Hermes, llama.cpp-style tools, your own scripts) at it.

The launcher never hardcodes anything about your machine: every setting comes from a
`.env` file next to the scripts.

## Files

| File | Purpose |
|---|---|
| `Start-Strata.bat` | Double-click entry point (optional profile argument) |
| `Stop-Strata.bat` | Stops the server and frees RAM/VRAM. Closing the start window does **not** |
| `Start-Strata.ps1` | Does the work: reads `.env`, starts WSL, polls progress |
| `Stop-Strata.ps1` | Stops the matching profile's server inside WSL (does not shut WSL down) |
| `start-strata.sh` | Starts the server detached inside WSL |
| `stop-strata.sh` | Stops that server by port. Never calls `wsl --shutdown` |
| `load-progress.sh` | Health check + live load progress (RSS / % / VRAM / stage) |
| `.env.example` | Lean template of all settings — copy to `.env` and fill in |
| `README.md` | This file. The **whole documentation**, including the AI guide below |

## Requirements

- Windows 10/11 with **WSL 2 or newer** and an Ubuntu-class distro
  (GPU compute inside a distro needs WSL 2 — WSL 1 has no GPU support. The launcher
  itself uses no WSL-3-only feature: `wsl.exe -d`, `/mnt` DrvFs, `setsid`, `/proc` and
  `curl` are all WSL 2 basics, so it runs on any WSL 2.x with a working NVIDIA driver.)
- An NVIDIA GPU whose driver works inside WSL (`nvidia-smi` runs in the distro)
- **Strata installed and built inside the WSL distro** (a folder with `serve/server.py`,
  `engine/strata`, `.venv/`, and a `strata-<model>.json` config) — the launcher does
  **not** install Strata itself

> **How this relates to Strata's own `START-HERE.bat`:** none — they solve different
> steps. `START-HERE.bat` (in the [Strata repo](https://github.com/Niko1221/Strata)) is
> the **first-run installer**: it sets up Python, downloads the model (70-111 GB) and
> builds the engine, and it targets **Windows native**. This launcher is the opposite
> end: it assumes Strata is already installed **inside WSL** (the Linux stack, which can
> be noticeably faster than the Windows driver stack at decode) and gives you a Windows
> double-click to start it with live load progress. To install Strata in WSL in the
> first place, see the pre-flight check below. If you run both side by side on one
> machine, give one a different `PORT` (both default to 8080).

## Setup

1. Put these files in one Windows folder (`Start-Strata.bat`, `Stop-Strata.bat`, and the scripts next to them).
2. Copy `.env.example` to `.env` and fill it in — by hand, or just ask your AI
   assistant to read this README and set it up (guide below).
3. Double-click `Start-Strata.bat`. First start loads the model (several minutes);
   the window shows RAM, GPU VRAM and the engine's current stage until it is ready.

## Daily use

- **Double-click** `Start-Strata.bat` → starts the server, waits until ready, opens the web UI.
- **Already running?** It just opens the browser — no double start, no port conflicts.
- **To stop:** double-click `Stop-Strata.bat` (or `Stop-Strata.bat orca` for that profile).
  Closing the start window only closes the launcher. The server is detached on purpose,
  so a stray click during the 5-10 minute load does not kill a half-loaded model.
- Web UI: `http://127.0.0.1:<PORT>/` — API: `http://127.0.0.1:<PORT>/v1`
  (OpenAI-compatible `/v1/chat/completions`, Anthropic-compatible `/v1/messages`).

## Running more than one model (profiles)

Give a profile name as the argument and keep a matching env file:

```
Start-Strata.bat          -> uses .env          (default model)
Start-Strata.bat orca     -> uses .env-orca     (second model)
```

A profile env file only needs the settings that differ: `MODEL`, `STRATA_DIR`, `PORT`,
`GPU_IDS`, ... plus the same `API_KEY`. This is how one machine serves a big model on
GPU 1 / port 8082 and a small one on GPU 0 / port 8081.

---

## For AI assistants

You are asked to set up this Strata launcher for the user. Work through this section
in order; `.env.example` only lists the keys — everything you need is here.

### 0. Pre-flight check: is Strata installed?

This launcher **only starts** a Strata server that is already installed inside WSL.
It installs nothing. Verify first (the default install folder is `~/Strata`):

```
wsl -d Ubuntu -- ls ~/Strata/serve/server.py
```

- **Found** → continue to step 1.
- **Not found** (no such file / empty) → STOP. Do not create a `.env`. Tell the user,
  in these words:

  > "Strata is not installed on this PC yet. Two ways to get it:
  > - Ask me: 'set up Strata on this PC for me: https://github.com/Niko1221/Strata -
  >   follow docs/AI_SETUP.md in that repository.'
  > - Or do it yourself: download Strata and unzip it (or git clone it).
  >   Windows: double-click START-HERE.bat. Linux: run ./setup.sh in the Strata folder.
  >
  > Note: this launcher talks to Strata inside WSL, so for it the install must happen
  > in the distro (git clone the repo there, then run ./setup.sh from it)."

Also confirm the model config exists (the tag is the `MODEL` setting):

```
wsl -d Ubuntu -- ls ~/Strata/strata-*.json
```

### 1. Interview the user

Ask only what the defaults cannot answer. Use the questions below; validate each
answer against the "Valid" line before writing it. When the user is unsure, offer the
default. Write the results into `.env` (copy `.env.example` first). Never echo the
API key back into the chat.

### 2. Settings reference

Required:

| Key | Meaning | Interview question / valid values |
|---|---|---|
| `API_KEY` | The secret clients must send (`Authorization: Bearer <key>`) | "Choose an API key for the server (any string; every client must send it)." Any non-empty string. If `HOST=0.0.0.0`, insist on something long and random. |
| `MODEL` | The model's profile tag. The launcher loads `<STRATA_DIR>/strata-<MODEL>.json` and logs to `serve-<MODEL>.out` | "Which model did you install?" = the tag of its `strata-*.json` (check the pre-flight `ls` output). E.g. `ud`, `orca`, `q2_0`. |

Optional (defaults in bold — only write lines you change):

| Key | Default | Meaning | Interview question / valid values |
|---|---|---|---|
| `STRATA_DIR` | **`~/Strata`** | Strata checkout inside WSL (folder with `serve/`, `engine/`, `.venv/`) | "Where is Strata installed inside WSL?" Any path. |
| `WSL_DISTRO` | **`Ubuntu`** | The distro that runs Strata (`wsl -l -v` lists them) | "Which WSL distro runs Strata?" A distro name. |
| `PORT` | **`8080`** | Port to serve on | "Which port?" 1024-65535; must be free. |
| `HOST` | **`127.0.0.1`** | Listen address | "Should other devices (LAN / Tailscale / VPN) reach this server?" `127.0.0.1` = this PC only (safest); `0.0.0.0` = also LAN/VPN — **requires a strong API_KEY**. |
| `GPU_IDS` | **`0`** | GPU(s) to run on, numbered as nvidia-smi prints them | "Which GPU should run the model?" Run `nvidia-smi --query-gpu=index,name --format=csv` and let the user pick. One index like `0` or `1`; `"0,1"` = a two-GPU layer split (advanced — also needs `--layer-split` tuning in the model config; start with a single GPU). |
| `USE_ESP` | **`0`** | `1` = keep the speed-projection control vector configured in the model's `strata-*.json`; `0` = strip it into a derived config (original untouched) | Only if the config has `--control-vector-*` args: "Enable the experimental speed-projection vector?" `0` or `1`. |
| `STRATA_PF_FUSED` | **`1`** | Fused prompt experts (engine 0.1.36+; 7-19% faster prefill on native-IQ packs) | "Is your engine 0.1.36 or newer?" (`engine/BUILD.json` shows the version) `0` or `1`; `0` for older engines. |
| `FIT_MAX_TOKENS` | **`1`** | `1` = clamp a client's too-large `max_tokens` to the room left (friendly to LLM clients; recommended); `0` = reject with HTTP 400 like llama.cpp | `0` or `1`. Rarely needs asking. |
| `OPEN_BROWSER` | **`1`** | Open the web UI in the browser when ready | `0` or `1`. |
| `TIMEOUT_MINUTES` | **`20`** | How long to wait for the model to load before giving up | Any number of minutes; big models on slow disks may need more. |
| `RESIDENT_TOTAL_GIB` | **`76`** | Denominator of the load progress % (the model's resident expert budget in GiB) | Any number; match the model config's `--resident-budget-gib` if the user wants accurate %. |
| `EXTRA_URLS` | *(empty)* | Extra URLs printed at startup (LAN / Tailscale API addresses), comma-separated. Display only — nothing is exposed by this setting. | "Any extra URLs to show for reaching the API?" Comma-separated URLs. |
| `CONFIG_NAME` | `strata-<MODEL>.json` | Advanced: explicit config file name (overrides the `<MODEL>` derivation) | Only when the config file does not match `strata-<MODEL>.json`. |

### 3. Verify and start

1. Dry-run the resolution inside WSL (prints every setting, masks the key):
   `wsl -d <distro> -- bash <folder>/start-strata.sh --print`
2. Start from Windows: double-click `Start-Strata.bat` (or run the ps1).
3. Readiness = the launcher prints `[OK] Strata is up`; the server itself answers
   `GET /health` with `max_context > 0` (key-less probe — use this, not an auth-gated
   one). First loads take minutes; the progress line (RAM / % / VRAM / stage) moving
   means it is loading, not stuck.

## Troubleshooting

- **Nothing starts / wrong distro**: check `WSL_DISTRO` against `wsl -l -v`.
- **Port in use**: the server refuses to start if the port is taken — the launcher's
  already-running check usually catches a running instance first; for a second model use
  a different `PORT` and profile.
- **Wrong GPU / CUDA error**: `GPU_IDS` follows **nvidia-smi** numbering, which is not
  guaranteed to match CUDA's order — the launcher sets `CUDA_DEVICE_ORDER=PCI_BUS_ID`
  via Strata itself; verify with `nvidia-smi --query-gpu=index,name --format=csv`.
- **Two-GPU split (`0,1`) OOMs or dies**: a layer split also needs a tuned
  `--layer-split` value in the model config; start with a single GPU.
- **A load takes forever**: the progress line prints engine RSS, % of the resident
  budget and the engine's stage — if those still move, it is loading, not stuck.
- **`WSAETIMEDOUT` on a new `wsl.exe` while the API still answers**: the VM is alive,
  host commit is exhausted — do NOT `wsl --shutdown`; close memory-hungry apps instead.
- **Never hard-kill `wsl.exe`** (e.g. from a task manager): it takes the whole distro
  down and looks like a reboot inside WSL. Stop the server with `Stop-Strata.bat`
  instead — that kills only `serve/server.py` and its engine.

## Notes for API clients (Hermes and friends)

- Strata reports its context at `/v1/models` under a **nested** `data[0].meta.n_ctx`
  field. Some clients (including Hermes Agent) only read top-level fields, so they
  cannot discover the window size automatically — **pin it in the client's config**
  (Hermes: `context_length` in the provider entry) to the model's real context
  (the `--max-context` of the Strata config, e.g. `65536`). A wrong window makes the
  client either over- or under-compress conversations.
- With `FIT_MAX_TOKENS=1` the server clamps a client's too-large `max_tokens` to the
  room left, so clients that request a huge output cap keep working instead of
  getting HTTP 400.
- Set `API_KEY` before exposing the server with `HOST=0.0.0.0`.

## License

MIT — do whatever you like; no warranty.