#!/bin/bash
#SBATCH --job-name=fastqc_from_ids
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err

set -euo pipefail

module load FastQC/0.11.9-Java-11

IDS_FILE="../samples_id.txt"
READS_DIR="../00-reads"

RESULTS_ROOT="03-fastqc-array-results"
mkdir -p "$RESULTS_ROOT"
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")
[[ -n "$SAMPLE" ]] || { echo "[ERROR] No sample for task ${SLURM_ARRAY_TASK_ID}" >&2; exit 2; }
R1="${READS_DIR}/${SAMPLE}_R1.fastq.gz"
R2="${READS_DIR}/${SAMPLE}_R2.fastq.gz"
[[ -r "$R1" && -r "$R2" ]] || { echo "[ERROR] Missing reads for ${SAMPLE}" >&2; exit 3; }
OUTDIR="${RESULTS_ROOT}/fastqc_from_ids_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_${SAMPLE}"
mkdir -p "$OUTDIR"

fastqc -o "$OUTDIR" "$R1" "$R2"
echo "[INFO] Sample=${SAMPLE} R1=${R1} R2=${R2}"
