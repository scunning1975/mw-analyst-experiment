# Minimum Wage Many-Analyst Experiment

An experiment testing whether AI agents' prompted priors about the minimum wage causally affect their empirical findings.

## Design

150 autonomous Claude Code agents analyze the same state-level panel data on minimum wages and employment using difference-in-differences methods. Agents are randomly assigned to one of three treatment arms:

- **Null prime** (50 agents): Provided with literature finding "little to no effect" (Card & Krueger 1994, Dube 2019, Cengiz et al. 2019, Doucouliagos & Stanley 2009)
- **Negative prime** (50 agents): Provided with literature finding "negative effects" (Neumark & Wascher 2007/2008, Clemens & Wither 2019, Jardim et al. 2022, Meer & West 2016)
- **Control** (50 agents): No literature provided

Each agent receives identical data, methodology documentation, and task instructions. The only variation is the literature prime. Agents have full discretion over outcome variable, sample period, treatment definition, control group, and estimator.

## Inspired By

Borjas & Breznau (2026, *Science Advances*), which found that immigration researchers' prior beliefs predicted their empirical estimates through specification choices. Our design adds a critical advantage: we can **randomize the prior via prompt**, making this a true experiment.

## Data

Pre-aggregated CPS and QCEW state-level annual panel (51 states, 1990-2022). Includes teen employment, young adult employment, low-education employment, and food services employment outcomes alongside minimum wage histories.

## Running the Experiment

See [RUN_INSTRUCTIONS.md](RUN_INSTRUCTIONS.md) for step-by-step instructions.

```bash
cd scripts
chmod +x launch_experiment.sh collect_results.sh
./launch_experiment.sh
```

## Pre-Registration

The pre-registration, hypotheses, and design decisions are documented in a separate repository: [mw-analyst-prereg](https://github.com/scunning1975/mw-analyst-prereg)

## Repository Structure

```
├── data/                       # Panel dataset
│   └── agent_panel_essential.csv
├── scripts/
│   ├── launch_experiment.sh    # Launches 150 agents
│   ├── collect_results.sh      # Collects results
│   └── analyze_results.R       # Fisher randomization test
├── INSTRUCTIONS_SHARED.md      # Task instructions (all agents)
├── DATA_DICTIONARY.md          # Variable descriptions
├── DID_METHODOLOGY.md          # DiD methodology reference
├── PRIME_NULL.md               # Null-effect literature prime
├── PRIME_NEGATIVE.md           # Negative-effect literature prime
└── RUN_INSTRUCTIONS.md         # How to run the experiment
```

## Author

Scott Cunningham, Baylor University
