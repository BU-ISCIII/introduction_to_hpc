#!/bin/bash
#SBATCH --job-name=spades_openmp
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

module load SPAdes/3.15.2-GCC-10.2.0

mkdir -p 04-openmp-spades-results

R1=../00-reads/ERR2261314_R1.fastq.gz
R2=../00-reads/ERR2261314_R2.fastq.gz

spades.py -1 "$R1" -2 "$R2" -o 04-openmp-spades-results/spades_sample01 \
    --threads "$SLURM_CPUS_PER_TASK" \
    --mem "$SLURM_MEM_PER_NODE"
