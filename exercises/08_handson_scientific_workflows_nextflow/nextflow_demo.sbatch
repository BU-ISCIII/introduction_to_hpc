#!/bin/bash
#SBATCH --job-name=nf_demo
#SBATCH --partition=middle_idx
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=2                 # Recursos SOLO para el controlador de Nextflow
#SBATCH --mem=2G
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

# Carga las dependencias para ejecutar Nextflow
module purge
module load Nextflow/24.04.2
module load singularity/3.7.1

mkdir -p 01-nextflow-demo-results

# Ejecuta nf-core/demo (workflow preparado)
# Importante: le indicamos que lea el archivo de configuración
nextflow run nf-core/demo -r 1.0.2 \
  -profile test,singularity \
  -c nextflow.config \
  --outdir 01-nextflow-demo-results \
  -resume
