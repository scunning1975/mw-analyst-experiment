#!/usr/bin/env bash
# launch_experiment.sh — Run the minimum wage many-analyst experiment
#
# Usage (from a REGULAR terminal, not inside Claude Code):
#   cd /path/to/mw-analyst-experiment/scripts
#   ./launch_experiment.sh
#
# Monitor progress:
#   ls /tmp/mw_agent_*/results.csv 2>/dev/null | wc -l

set -euo pipefail

# ============================================================================
# CONFIGURATION — Change N_PER_ARM for pilot (3) vs. full run (50)
# ============================================================================
N_PER_ARM=50
ARMS=("null" "negative" "none")

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_FILE="$EXPERIMENT_DIR/data/agent_panel_essential.csv"
DICT_FILE="$EXPERIMENT_DIR/DATA_DICTIONARY.md"
METH_FILE="$EXPERIMENT_DIR/DID_METHODOLOGY.md"
INSTRUCTIONS_FILE="$EXPERIMENT_DIR/INSTRUCTIONS_SHARED.md"

# Validate files exist
for f in "$DATA_FILE" "$DICT_FILE" "$METH_FILE" "$INSTRUCTIONS_FILE"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: Required file not found: $f"
        exit 1
    fi
done

echo "============================================"
echo "Minimum Wage Many-Analyst Experiment"
echo "============================================"
echo "Arms:        ${ARMS[*]}"
echo "Per arm:     $N_PER_ARM"
echo "Total runs:  $((N_PER_ARM * ${#ARMS[@]}))"
echo "============================================"
echo ""

AGENT_NUM=1

for arm in "${ARMS[@]}"; do
    echo "--- ARM: $arm ---"

    for i in $(seq 1 "$N_PER_ARM"); do
        AGENT_ID="${arm}_$(printf '%03d' "$i")"
        WORK_DIR="/tmp/mw_agent_${AGENT_ID}"

        echo "  Launching agent $AGENT_ID (agent #$AGENT_NUM)..."

        # Create isolated workspace
        rm -rf "$WORK_DIR"
        mkdir -p "$WORK_DIR"

        # Copy shared files
        cp "$DATA_FILE" "$WORK_DIR/"
        cp "$DICT_FILE" "$WORK_DIR/"
        cp "$METH_FILE" "$WORK_DIR/"
        cp "$INSTRUCTIONS_FILE" "$WORK_DIR/"

        # Copy treatment-specific prime (skip for control arm)
        if [[ "$arm" == "null" ]]; then
            cp "$EXPERIMENT_DIR/PRIME_NULL.md" "$WORK_DIR/LITERATURE_CONTEXT.md"
        elif [[ "$arm" == "negative" ]]; then
            cp "$EXPERIMENT_DIR/PRIME_NEGATIVE.md" "$WORK_DIR/LITERATURE_CONTEXT.md"
        fi
        # arm "none" gets no literature context file

        # Build the prompt for this agent
        PROMPT="You are Agent $AGENT_ID. Your working directory is $WORK_DIR.

Read the following files in your working directory in this order:
1. INSTRUCTIONS_SHARED.md — your task and deliverables
2. DATA_DICTIONARY.md — variable descriptions
3. DID_METHODOLOGY.md — methodology reference"

        # Add literature context for primed arms
        if [[ "$arm" != "none" ]]; then
            PROMPT="$PROMPT
4. LITERATURE_CONTEXT.md — relevant empirical literature"
        fi

        PROMPT="$PROMPT

Then conduct your analysis and produce:
- results.csv (one row with your estimates)
- llms.txt (structured summary)

Your agent_id for results.csv is: $AGENT_ID

Write all output files to: $WORK_DIR"

        # Save prompt to file (avoids multi-line argument issues)
        echo "$PROMPT" > "$WORK_DIR/prompt.txt"

        # Launch Claude Code agent in background
        # - Pipe prompt via stdin (more reliable than positional arg for multi-line text)
        # - env -u CLAUDECODE: allows launching even from within another Claude session
        # - --dangerously-skip-permissions: agents run autonomously without permission prompts
        # - cd into WORK_DIR so claude treats it as the working directory
        (cd "$WORK_DIR" && cat prompt.txt | env -u CLAUDECODE claude -p \
            --dangerously-skip-permissions \
            --allowedTools "Read,Write,Bash" \
            > "$WORK_DIR/agent_log.txt" 2>&1) &

        AGENT_NUM=$((AGENT_NUM + 1))

        # Delay between launches to avoid rate limiting
        sleep 5
    done
done

echo ""
echo "============================================"
echo "All $((AGENT_NUM - 1)) agents launched."
echo "============================================"
echo ""
echo "Monitor progress:"
echo "  ls /tmp/mw_agent_*/results.csv 2>/dev/null | wc -l"
echo ""
echo "When all are done, collect results:"
echo "  ./collect_results.sh"
echo ""
echo "Waiting for all agents to finish..."
wait
echo "All agents complete!"
