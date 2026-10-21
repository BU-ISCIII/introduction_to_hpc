#!/bin/bash
# Ejemplo exclusivo para el docente: nf-core/bacass en la rama de desarrollo.
# El perfil `test` de bacass utiliza el conjunto mínimo de lecturas cortas.
#SBATCH --job-name=nf_bacass_dev
#SBATCH --partition=middle_idx
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail
module purge
module load Nextflow/26.04.3
module load singularity/3.7.1

# El controlador usa estos recursos; las tareas del pipeline se envían a Slurm
# con los recursos definidos por etiquetas en bacass_portutatis.config.
# Run test
nextflow run nf-core/bacass -r dev \
  -profile test,singularity \
  -c "$PWD/bacass_portutatis.config" \
  --outdir "02-bacass-results" \
  -resume

