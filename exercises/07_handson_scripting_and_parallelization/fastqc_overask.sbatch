#!/bin/bash
#SBATCH --job-name=fastqc_overask
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=2
#SBATCH --mem=1T                         # Debe superar la RAM de cualquier nodo
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

module load FastQC/0.11.9-Java-11

echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

mkdir -p 01-fastqc-demo-results
fastqc \
  ../00-reads/virus1_R1.fastq.gz \
  ../00-reads/virus1_R2.fastq.gz \
  -o 01-fastqc-demo-results

echo "[INFO] Finished at $(date)"
