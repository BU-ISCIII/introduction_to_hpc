#!/bin/bash
#SBATCH --job-name=fastqc_array
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --array=1-10
#SBATCH --output=logs/array_%A_%a.out  # %A JobID array, %a índice
#SBATCH --error=logs/array_%A_%a.err

module load FastQC/0.11.9-Java-11

# Definimos 1 linea de filelist por tarea utilizando la variable de entorno SLURM_ARRAY_TASK_ID
INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" data/filelist_R1.txt)
OUTDIR="results/fastqc_array_${SLURM_ARRAY_JOB_ID}"
echo $INPUT
mkdir -p "$OUTDIR"
mkdir -p "logs"

# Ejecutamos el comando
fastqc -o "$OUTDIR" "$INPUT"
echo "[INFO] Task ${SLURM_ARRAY_TASK_ID}  End:   $(date)"