#!/usr/bin/env bash
# collect_results.sh — Gather results from all agent runs
#
# Copies each agent's results.csv, llms.txt, and log into
# output/arm_{null,negative,none}/agent_NNN/
#
# Also produces a combined results_all.csv with all agents' one-row results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$EXPERIMENT_DIR/output"

ARMS=("null" "negative" "none")

echo "Collecting results..."
echo ""

COMBINED_CSV="$OUTPUT_DIR/results_all.csv"
HEADER_WRITTEN=false

TOTAL=0
SUCCESSFUL=0

for arm in "${ARMS[@]}"; do
    ARM_DIR="$OUTPUT_DIR/arm_${arm}"
    mkdir -p "$ARM_DIR"

    # Find all agent directories for this arm
    for agent_dir in /tmp/mw_agent_${arm}_*; do
        [[ -d "$agent_dir" ]] || continue

        AGENT_ID=$(basename "$agent_dir" | sed 's/mw_agent_//')
        DEST="$ARM_DIR/$AGENT_ID"
        mkdir -p "$DEST"

        TOTAL=$((TOTAL + 1))

        # Copy outputs
        for f in results.csv llms.txt agent_log.txt; do
            if [[ -f "$agent_dir/$f" ]]; then
                cp "$agent_dir/$f" "$DEST/"
            fi
        done

        # Copy any R scripts the agent created
        for f in "$agent_dir"/*.R; do
            [[ -f "$f" ]] && cp "$f" "$DEST/"
        done

        # Append to combined CSV
        if [[ -f "$agent_dir/results.csv" ]]; then
            SUCCESSFUL=$((SUCCESSFUL + 1))
            if [[ "$HEADER_WRITTEN" == false ]]; then
                # First file: include header
                head -1 "$agent_dir/results.csv" > "$COMBINED_CSV"
                HEADER_WRITTEN=true
            fi
            # Append data row (skip header)
            tail -n +2 "$agent_dir/results.csv" >> "$COMBINED_CSV"
            echo "  ✓ $AGENT_ID"
        else
            echo "  ✗ $AGENT_ID (no results.csv)"
        fi
    done
done

echo ""
echo "============================================"
echo "Collection complete"
echo "  Total agents:      $TOTAL"
echo "  Successful:        $SUCCESSFUL"
echo "  Failed/incomplete: $((TOTAL - SUCCESSFUL))"
echo ""
echo "Combined results: $COMBINED_CSV"
echo "Individual results: $OUTPUT_DIR/arm_*/agent_*/results.csv"
echo "============================================"
