# Full Experiment Run Instructions

## What This Does

Launches 150 autonomous Claude Code agents (50 per arm) to analyze the effect of minimum wage on employment. Each agent gets the same data and methodology reference, but different literature priming:

- **null** (50 agents): Primed with Card & Krueger, Dube, Cengiz — "little to no effect" literature
- **negative** (50 agents): Primed with Neumark & Wascher, Clemens, Jardim — "negative effect" literature
- **none** (50 agents): No literature priming (control)

Each agent produces `results.csv` (ATT estimate) and `llms.txt` (analysis writeup).

## Desktop Machine Setup (One-Time)

Follow these steps to prepare a fresh machine before running the experiment.

### 1. Install R

If R is not installed:
```bash
# macOS (via Homebrew)
brew install r

# Or download from https://cran.r-project.org/
```

Verify: `Rscript --version`

### 2. Install R packages

```bash
Rscript -e 'install.packages(c("did", "contdid", "ggplot2", "dplyr", "tidyr", "fixest"), repos="https://cran.r-project.org")'
```

Verify they load:
```bash
Rscript -e 'library(did); library(contdid); library(ggplot2); library(dplyr); library(tidyr); cat("All packages OK\n")'
```

### 3. Install and authenticate Claude Code CLI

```bash
# Install via npm
npm install -g @anthropic-ai/claude-code

# Or if already installed, verify:
claude --version

# Authenticate (follow the prompts):
claude
```

You must be logged in to the same Anthropic account (Max plan). Verify:
```bash
echo "Say hello" | claude -p
```

This should return a response, not an auth error.

### 4. Clone the experiment repo (ONLY this repo, NOT the pre-reg repo)

```bash
cd ~
git clone https://github.com/scunning1975/mw-analyst-experiment.git
```

**IMPORTANT:** Do NOT clone `mw-analyst-prereg` onto this machine. Agents must not be able to find the hypotheses or analysis plan.

### 5. Make scripts executable

```bash
chmod +x ~/mw-analyst-experiment/scripts/launch_experiment.sh
chmod +x ~/mw-analyst-experiment/scripts/collect_results.sh
```

### 6. Verify everything works (optional dry run)

Edit `launch_experiment.sh` temporarily to set `N_PER_ARM=1`, run it, check that one agent per arm produces a `results.csv`, then set it back to `N_PER_ARM=50`.

---

## Running the Experiment

### Step 1: Launch

Open a **regular terminal** (not inside Claude Code). Run:

```bash
cd ~/mw-analyst-experiment/scripts
./launch_experiment.sh
```

This will:
- Create 150 isolated workspaces in `/tmp/mw_agent_*`
- Copy data and instructions to each workspace
- Launch agents with 5-second delays between each (total launch time: ~12.5 minutes)
- Wait for all agents to finish

**Expected total runtime:** 1-3 hours (agents run in parallel, ~5-15 minutes each).

## Step 4: Monitor Progress

In a **separate terminal**, check how many agents have finished:

```bash
# Count completed agents
ls /tmp/mw_agent_*/results.csv 2>/dev/null | wc -l

# Should eventually reach 150
```

You can also check for failed agents:

```bash
# Check for error logs (short logs usually mean failure)
for d in /tmp/mw_agent_*/; do
    if [ ! -f "$d/results.csv" ]; then
        echo "INCOMPLETE: $(basename $d)"
    fi
done
```

## Step 5: Collect Results

Once all 150 agents are done (or the launch script says "All agents complete!"):

```bash
cd /path/to/mw-analyst-experiment/scripts
./collect_results.sh
```

This produces:
- `results/results_all.csv` — combined results from all agents
- `results/llms/` — all llms.txt files
- `results/scripts/` — all R scripts agents wrote

## Step 6: Analyze Results

```bash
cd /path/to/mw-analyst-experiment/scripts
Rscript analyze_results.R
```

This runs the Fisher randomization test and produces plots.

## Troubleshooting

**"Error: Input must be provided"** — The prompt wasn't piped correctly. This was fixed; make sure you have the latest `launch_experiment.sh`.

**Rate limiting** — If many agents fail or produce empty results, you may be hitting API rate limits. Fix: edit `launch_experiment.sh` and increase `sleep 5` to `sleep 15`. Then re-run (the script cleans up old directories automatically).

**Agent produced no results.csv** — Check the agent log: `cat /tmp/mw_agent_<id>/agent_log.txt`. Common causes: R package not installed, estimation failure the agent couldn't recover from, or rate limiting.

**Want to re-run specific failed agents** — You can re-run individual agents manually:
```bash
AGENT_ID="null_042"
WORK_DIR="/tmp/mw_agent_${AGENT_ID}"
cd "$WORK_DIR"
cat prompt.txt | claude -p --dangerously-skip-permissions --allowedTools "Read,Write,Bash" > agent_log.txt 2>&1
```

## Configuration

In `launch_experiment.sh`:
- `N_PER_ARM=50` — currently set for full run (change to 3 for pilot)
- `sleep 5` — delay between agent launches (increase if hitting rate limits)
