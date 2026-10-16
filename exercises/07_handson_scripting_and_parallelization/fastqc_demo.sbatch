#!/bin/bash
#SBATCH --job-name=fastqc_demo
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
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

# Crea la carpeta de resultados
mkdir -p 01-fastqc-demo-results

# Ejecuta fastqc
fastqc \
  ../00-reads/virus1_R1.fastq.gz \
  ../00-reads/virus1_R2.fastq.gz \
  -o 01-fastqc-demo-results

echo "[INFO] Finished at $(date)"
