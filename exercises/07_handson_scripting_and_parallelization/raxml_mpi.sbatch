#!/bin/bash
#SBATCH --job-name=raxml_mpi
#SBATCH --partition=short_idx
#SBATCH --nodes=2                 # <-- nº de nodos
#SBATCH --ntasks=8                # total procesos MPI
#SBATCH --ntasks-per-node=4       # <-- nº procesos MPI por nodo
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

module load RAxML/8.2.12-gompi-2020a-hybrid-avx2  # el módulo puede traer varios binarios

RUNNAME="ML_bootstrap"
mkdir -p 05-raxml_mpi-results
RESULTS_DIR="$PWD/05-raxml_mpi-results/raxml_${SLURM_JOB_ID}"
mkdir -p "$RESULTS_DIR"

RAXML_BIN=""
for candidate in raxmlHPC-MPI-AVX2 raxmlHPC-MPI-AVX raxmlHPC-MPI; do
  if command -v "$candidate" >/dev/null 2>&1; then
    RAXML_BIN="$candidate"
    break
  fi
done
[[ -n "$RAXML_BIN" ]] || { echo "[ERROR] No MPI-enabled RAxML executable found." >&2; exit 127; }

srun "$RAXML_BIN" \
  -s data/datos.phy \
  -m GTRGAMMA \
  -p 12345 \
  -# 20 \
  -n "$RUNNAME" \
  -w "$RESULTS_DIR"
