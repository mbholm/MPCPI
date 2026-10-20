# =============================================================================
# run_all.ps1 -- end-to-end driver for the replication package
# (Windows PowerShell). Runs R (fetch + data prep) -> Stata -> MATLAB.
#
# Override the executable names via -StataBin / -MatlabBin if needed. Note that
# Stata's Windows batch mode (/e) opens a Stata window while it runs; if that is
# a nuisance, run code/stata/run_all.do from an interactive Stata session
# started in the replication/ directory instead.
#
# Offline (no internet):  $env:REPL_USE_FALLBACK=1 ; ./run_all.ps1
# =============================================================================
param(
    [string]$StataBin  = "StataSE-64",   # e.g. StataMP-64, StataSE-64, Stata-64
    [string]$MatlabBin = "matlab"
)
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "[1/3] R stage: fetch data (SSB + Norges Bank) and build .dta files ..."
Rscript run_all.R
if ($LASTEXITCODE -ne 0) { throw "R stage failed (exit $LASTEXITCODE)" }

Write-Host "[2/3] Stata stage: regressions -> output/coeffs_*.xlsx ..."
$stata = Start-Process -FilePath $StataBin -ArgumentList '/e','do','"code\stata\run_all.do"' -WorkingDirectory $PSScriptRoot -Wait -PassThru
if ($stata.ExitCode -ne 0) { throw "Stata stage failed (exit $($stata.ExitCode)); see run_all.log" }

Write-Host "[3/3] MATLAB stage: figures -> output/FIG_*.eps ..."
& $MatlabBin -batch "run('$PSScriptRoot\code\matlab\plot_figures.m')"
if ($LASTEXITCODE -ne 0) { throw "MATLAB stage failed" }

Write-Host "Done. Coefficients in output/coeffs_*.xlsx, figures in output/FIG_*.eps"
