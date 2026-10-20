#!/bin/bash
#SBATCH --job-name=fastqc_from_ids
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err

set -euo pipefail

module load FastQC/0.11.9-Java-11

# Lista ordenada de identificadores de muestra, una muestra por línea.
IDS_FILE="../samples_id.txt"
# Directorio que contiene los pares de lecturas enlazados.
READS_DIR="../00-reads"

# Directorio común donde se guardarán los resultados del array.
RESULTS_ROOT="03-fastqc-array-results"
mkdir -p "$RESULTS_ROOT"

# SLURM_ARRAY_TASK_ID es el índice de esta tarea del array: 1, 2, 3, ...
# La expresión, por ejemplo "2p", hace que sed imprima solo la línea 2.
# La muestra leída de esa línea se guarda en SAMPLE.
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")

# Detiene el script si el índice no tiene una muestra asociada.
[[ -n "$SAMPLE" ]] || { echo "[ERROR] No sample for task ${SLURM_ARRAY_TASK_ID}" >&2; exit 2; }

# Construye los nombres de los archivos R1 y R2 de esa muestra.
R1="${READS_DIR}/${SAMPLE}_R1.fastq.gz"
R2="${READS_DIR}/${SAMPLE}_R2.fastq.gz"

# Comprueba que las dos lecturas existen y se pueden leer antes de ejecutar FastQC.
[[ -r "$R1" && -r "$R2" ]] || { echo "[ERROR] Missing reads for ${SAMPLE}" >&2; exit 3; }

# Cada tarea escribe en su propia carpeta: array, tarea e identificador de muestra.
OUTDIR="${RESULTS_ROOT}/fastqc_from_ids_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_${SAMPLE}"
mkdir -p "$OUTDIR"

# Analiza el par de lecturas y deposita los informes en la carpeta de esta tarea.
fastqc -o "$OUTDIR" "$R1" "$R2"

# Deja en el log la muestra y los archivos procesados por esta tarea.
echo "[INFO] Sample=${SAMPLE} R1=${R1} R2=${R2}"
