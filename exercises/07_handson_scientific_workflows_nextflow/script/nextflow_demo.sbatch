#!/bin/bash
#SBATCH --job-name=nf_demo
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc/
#SBATCH --partition=short_idx
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=1                 # Recursos SOLO para el controlador de Nextflow
#SBATCH --mem=2G
#SBATCH --output=nextflow_stdout.log

# Carga las dependencias para ejecutar Nextflow
module purge
module load Nextflow/25.04.6
module load singularity/3.7.1

# Ejecuta nf-core/demo (workflow preparado)
# Importante: le indicamos que lea el archivo de configuración
nextflow run nf-core/demo \
  -profile test,singularity \
  -c nextflow.config \
  --outdir results \
  -resume