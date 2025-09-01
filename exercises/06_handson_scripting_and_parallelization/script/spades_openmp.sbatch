#!/bin/bash
#SBATCH --job-name=spades_omp
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=logs/spades_%j.out
#SBATCH --error=logs/spades_%j.err

module load SPAdes/3.15.2-GCC-10.2.0
R1=data/sample01_R1.fastq.gz
R2=data/sample01_R2.fastq.gz

spades.py -1 "$R1" -2 "$R2" -o results/spades_sample01 \
    --threads "$SLURM_CPUS_PER_TASK" \
    --mem 32