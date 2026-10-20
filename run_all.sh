#!/usr/bin/env bash
# =============================================================================
# run_all.sh -- end-to-end driver for the replication package
# (macOS/Linux). Runs R (fetch + data prep) -> Stata -> MATLAB.
#
# Edit STATA_BIN / MATLAB_BIN if needed. The canonical contract is the run order
# documented in README.md, with each engine launched from the replication/ directory.
#
# Offline (no internet): REPL_USE_FALLBACK=1 ./run_all.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

STATA_BIN="${STATA_BIN:-stata-mp}"     # e.g. StataMP, StataSE, stata-mp, stata
MATLAB_BIN="${MATLAB_BIN:-matlab}"

echo "[1/3] R stage: fetch data (SSB + Norges Bank) and build .dta files ..."
Rscript run_all.R

echo "[2/3] Stata stage: regressions -> output/coeffs_*.xlsx ..."
"$STATA_BIN" -b do code/stata/run_all.do

echo "[3/3] MATLAB stage: figures -> output/FIG_*.eps ..."
"$MATLAB_BIN" -batch "run('$(pwd)/code/matlab/plot_figures.m')"

echo "Done. Coefficients in output/coeffs_*.xlsx, figures in output/FIG_*.eps"
