# Full Experiment Run Instructions

## What This Does

Launches 150 autonomous Claude Code agents (50 per arm) to analyze the effect of minimum wage on employment. Each agent gets the same data and methodology reference, but different literature priming:

- **null** (50 agents): Primed with Card & Krueger, Dube, Cengiz — "little to no effect" literature
- **negative** (50 agents): Primed with Neumark & Wascher, Clemens, Jardim — "negative effect" literature
- **none** (50 agents): No literature priming (control)

Each agent produces `results.csv` (ATT estimate) and `llms.txt` (analysis writeup).

## Prerequisites

1. **Claude Code CLI installed** and authenticated (run `claude --version` to check)
2. **R packages pre-installed:** `did`, `contdid`, `ggplot2`, `dplyr`, `tidyr`
   ```bash
   Rscript -e 'install.packages(c("did", "contdid", "ggplot2", "dplyr", "tidyr"), repos="https://cran.r-project.org")'
   ```
3. **The experiment repo** copied to the desktop machine (this entire `mw-analyst-experiment/` folder)

## Step 1: Copy the Experiment Repo to the Desktop

Copy the entire `mw-analyst-experiment/` folder to the desktop. It should contain:

```
mw-analyst-experiment/
  data/agent_panel_essential.csv
  scripts/launch_experiment.sh
  scripts/collect_results.sh
  scripts/analyze_results.R
  INSTRUCTIONS_SHARED.md
  DATA_DICTIONARY.md
  DID_METHODOLOGY.md
  PRIME_NULL.md
  PRIME_NEGATIVE.md
```

**Do NOT copy the pre-registration repo.** Agents must not be able to find it.

## Step 2: Make Scripts Executable

```bash
chmod +x /path/to/mw-analyst-experiment/scripts/launch_experiment.sh
chmod +x /path/to/mw-analyst-experiment/scripts/collect_results.sh
```

## Step 3: Launch the Experiment

Open a **regular terminal** (not inside Claude Code). Run:

```bash
cd /path/to/mw-analyst-experiment/scripts
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
