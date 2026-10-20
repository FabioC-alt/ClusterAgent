#!/bin/bash
# Submits the vLLM server job. Works from any folder.
# Usage:  bash scripts/start.sh [extra sbatch options, e.g. --time=02:00:00]
set -euo pipefail

# Repository root, derived from this script's location (as in install.sh).
# This works because this script is run directly with bash, not copied by Slurm.
D=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Slurm cannot create the log if its folder is missing (the job would fail
# silently), and logs/ is not stored in git: create it first.
mkdir -p "$D/logs"

# Options given on the sbatch command line override the #SBATCH lines in the script:
#   --chdir     the job runs in the repository root (llm.sbatch uses it as $PWD)
#   --output    absolute log path, independent of the current folder
#   --parsable  sbatch prints only the job ID, so we can show the log path
#   "$@"        any extra options passed to this script (they also override #SBATCH)
JOB=$(sbatch --parsable --chdir="$D" --output="$D/logs/llm-%j.log" "$@" "$D/scripts/llm.sbatch")
JOB=${JOB%%;*}   # on multi-cluster setups sbatch prints "ID;cluster": keep the ID

echo "Submitted job $JOB"
echo "Log: $D/logs/llm-$JOB.log"
echo "Follow it with:  tail -f $D/logs/llm-$JOB.log"
