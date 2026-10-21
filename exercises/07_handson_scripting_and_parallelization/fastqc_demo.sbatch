#!/bin/bash
#SBATCH --job-name=fastqc_demo
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

# Carga dependencias
module load FastQC/0.11.9-Java-11

# Info útil para el log
echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

# Pausa didáctica: permite consultar el trabajo con squeue.
echo "[INFO] Waiting 60 seconds before starting FastQC."
sleep 60

# Crea la carpeta de resultados
mkdir -p 01-fastqc-demo-results

# Ejecuta FastQC con las CPU reservadas por Slurm.
fastqc \
  -t "$SLURM_CPUS_PER_TASK" \
  ../00-reads/virus1_R1.fastq.gz \
  ../00-reads/virus1_R2.fastq.gz \
  -o 01-fastqc-demo-results

echo "[INFO] Finished at $(date)"
