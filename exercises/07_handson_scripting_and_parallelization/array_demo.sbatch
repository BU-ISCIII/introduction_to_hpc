#!/bin/bash
#SBATCH --job-name=array_demo
#SBATCH --partition=short_idx
#SBATCH --array=1-2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err

set -euo pipefail

module load FastQC/0.11.9-Java-11

mkdir -p 02-array-demo-results
OUTDIR="02-array-demo-results/demo_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$OUTDIR"

fastqc -o "$OUTDIR" \
  "../00-reads/virus${SLURM_ARRAY_TASK_ID}_R1.fastq.gz" \
  "../00-reads/virus${SLURM_ARRAY_TASK_ID}_R2.fastq.gz"

echo "[INFO] JobID=${SLURM_JOBID}; Task=${SLURM_ARRAY_TASK_ID}; End=$(date)"
