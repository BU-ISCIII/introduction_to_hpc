#!/bin/bash
#SBATCH --job-name=fastqc_demo
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=2                <<<<
#SBATCH --mem=530G                       <<<<
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

# Carga dependencias
module load FastQC/0.11.9-Java-11

# Info útil para el log
echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

mkdir -p fastqc_results
fastqc data/sample_R1.fastq.gz data/sample_R2.fastq.gz -o fastqc_results

echo "[INFO] Finished at $(date)"