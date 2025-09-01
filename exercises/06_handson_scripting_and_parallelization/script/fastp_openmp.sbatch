#!/bin/bash
#SBATCH --job-name=fastp_omp
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=4           # <- nº hilos/threads OpenMP
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=logs/fastp_omp_%j.out
#SBATCH --error=logs/fastp_omp_%j.err

module load fastp/0.20.0-GCC-8.3.0
mkdir -p results/fastp logs

# Setup de variables
R1=data/sample01_R1.fastq.gz
R2=data/sample01_R2.fastq.gz
OUTR1=results/fastp/sample01.clean.R1.fastq.gz
OUTR2=results/fastp/sample01.clean.R2.fastq.gz

# Ejecutamos el comando
fastp -i "$R1" -I "$R2" -o "$OUTR1" -O "$OUTR2" \
    --thread="$SLURM_CPUS_PER_TASK" \
    --detect_adapter_for_pe