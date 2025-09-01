#!/bin/bash
#SBATCH --job-name=nf_bacass
#SBATCH --partition=short_idx
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=nextflow_bacass_stdout.log

module purge
module load Nextflow/23.10.0
module load singularity/3.7.1

nextflow run nf-core/bacass \
    -profile test,singularity \
    -c nextflow.config \
    --input samplesheet.csv \
    --outdir results/bacass_test \
    -resume