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

module load RAxML/8.2.12-gompi-2020a-hybrid-avx2

# Cada ejecución usa su propio directorio, identificado con el ID de Slurm.
mkdir -p "05-raxml_mpi-results/raxml_${SLURM_JOB_ID}"

# Pausa didáctica: permite observar la reserva multinodo con squeue.
echo "[INFO] Recursos MPI reservados; RAxML comenzará en 60 segundos."
sleep 60

# Ejecuta 8 procesos MPI; cada uno usa 2 hilos (igual que las directivas #SBATCH).
mpirun -np 8 raxmlHPC-HYBRID-AVX2 \
  -T 2 \
  -s data/raxml_demo.phy \
  -m GTRCAT \
  -p 12345 \
  -# 8 \
  -n ML_searches \
  -w "$PWD/05-raxml_mpi-results/raxml_${SLURM_JOB_ID}"
