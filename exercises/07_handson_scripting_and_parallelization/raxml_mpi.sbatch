#!/bin/bash
#SBATCH --job-name=raxml_mpi
#SBATCH --partition=short_idx
#SBATCH --nodes=2                 # <-- nº de nodos
#SBATCH --ntasks=8                # total procesos MPI
#SBATCH --ntasks-per-node=4       # <-- nº procesos MPI por nodo
#SBATCH --cpus-per-task=2         # dos hilos por proceso MPI híbrido
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

module load RAxML/8.2.12-gompi-2020a-hybrid-avx2  # el módulo puede traer varios binarios

RUNNAME="ML_searches"
mkdir -p 05-raxml_mpi-results
RESULTS_DIR="$PWD/05-raxml_mpi-results/raxml_${SLURM_JOB_ID}"
mkdir -p "$RESULTS_DIR"

# Pausa didáctica: permite observar la reserva multinodo con squeue.
echo "[INFO] Recursos MPI reservados; RAxML comenzará en 60 segundos."
sleep 60

# Ejecuta RAxML con MPI
mpirun -np "$SLURM_NTASKS" raxmlHPC-HYBRID-AVX2 \
  -T "$SLURM_CPUS_PER_TASK" \
  -s data/raxml_demo.phy \
  -m GTRCAT \
  -p 12345 \
  -# 8 \
  -n "$RUNNAME" \
  -w "$RESULTS_DIR"
