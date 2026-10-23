# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 8: flujos científicos reproducibles con Nextflow y Slurm

En esta práctica ejecutarás `nf-core/demo` 1.0.2 con Nextflow. Nextflow organiza los pasos del análisis según sus datos de entrada y salida, y envía las tareas a Slurm. La opción `-resume` permite reutilizar las tareas ya completadas.

> Conéctate por **MobaXterm (SSH)** y ejecuta todo en el clúster.

## 1. Preparación

Reutiliza la carpeta creada en prácticas anteriores. Escribe la fecha que aparece en el nombre de tu carpeta; para esta edición es `20261021`.

```bash
export COURSE_NAME="20261021_HPC-COURSE_${USER}"
export DATA_DIR="/data/courses/hpc_course/${COURSE_NAME}"
export SCRATCH_DIR="/scratch/hpc_course/${COURSE_NAME}"
export ANALYSIS_DIR="${DATA_DIR}/ANALYSIS"

mkdir -p "$ANALYSIS_DIR/08-scientific-workflows-nextflow/logs"
ls -1 "$ANALYSIS_DIR/08-scientific-workflows-nextflow/"
```

Los archivos de esta práctica se copiaron junto con los de la práctica 7. Ahora sincroniza tu proyecto a `/scratch`, donde se realizará el análisis:

```bash
cd "$ANALYSIS_DIR/08-scientific-workflows-nextflow"

srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh "$DATA_DIR/" "$SCRATCH_DIR/"
```

Nos movemos de /data a /scratch:
```bash
cd "$SCRATCH_DIR/ANALYSIS/08-scientific-workflows-nextflow"
pwd
```

## 2. Revisar y lanzar el pipeline

Explora primero la configuración y el script:

```bash
more nextflow.config
more nextflow_demo.sbatch
```

En `nextflow.config`, fíjate en tres cosas: `executor = 'slurm'` envía las tareas del pipeline a Slurm; `cpus`, `memory` y `time` son los recursos de esas tareas; la caché de Singularity es compartida y ya está preparada por el docente.

El SBatch es el controlador de Nextflow. Envíalo:

```bash
sbatch --chdir="$PWD" nextflow_demo.sbatch
```

Guarda el `JOBID` que devuelve `sbatch`.

## 3. Seguimiento

En otra terminal de MobaXterm, mientras el pipeline esté activo:

```bash
watch squeue --me
```

Verás el controlador `nf_demo` y, a medida que Nextflow las necesite, los trabajos que crea para cada proceso. Nextflow espera a que estén disponibles las entradas de un paso antes de enviar el siguiente.

El progreso de Nextflow se escribe en el log de salida del controlador:

```bash
tail -f "logs/nf_demo-<JOBID>.out"
```

Pulsa `Ctrl+C` para salir de `tail`; el pipeline seguirá ejecutándose. Los errores se escriben en `logs/nf_demo-<JOBID>.err`.

Cuando termine:

```bash
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,ExitCode
less "logs/nf_demo-<JOBID>.out"
less "logs/nf_demo-<JOBID>.err"
tail -n 50 .nextflow.log
```

`.nextflow.log` es el registro técnico de Nextflow: resulta útil si el log de Slurm no explica un problema.

## 4. Explorar los resultados

Nextflow crea tres ubicaciones importantes:

- `01-nextflow-demo-results/`: resultados finales publicados por el pipeline.
- `work/`: resultados intermedios, comandos y logs de cada tarea. No lo edites ni lo borres si vas a usar `-resume`.
- `.nextflow.log`: registro del motor Nextflow.

Explora los resultados finales:

```bash
tree 01-nextflow-demo-results
ls 01-nextflow-demo-results/multiqc
ls 01-nextflow-demo-results/pipeline_info
```

- `multiqc/multiqc_report.html` resume las métricas de calidad. Descárgalo con el panel SFTP de MobaXterm y ábrelo en el navegador.
- `pipeline_info/` contiene informes de la ejecución: `execution_report_*.html`, `execution_timeline_*.html`, `pipeline_dag_*.html` y `execution_trace_*.txt`.

La traza es una tabla, con una fila por tarea:

```bash
less 01-nextflow-demo-results/pipeline_info/execution_trace_*.txt
```

Los HTML de `pipeline_info/` describen cómo se ejecutó el workflow; el informe de MultiQC describe los resultados de calidad de las lecturas.

Prueba a enviarlo una segunda vez:

```bash
sbatch --chdir="$PWD" nextflow_demo.sbatch
```

Con los mismos datos, parámetros y directorio `work/`, Nextflow mostrará tareas `cached` y no las repetirá.

## 5. Preguntas

1. ¿Qué diferencia hay entre el `JOBID` del controlador `nf_demo` y los trabajos que aparecen después en `squeue`?
2. En `execution_trace_*.txt`, ¿qué recursos solicitó una tarea?
3. ¿Qué información consultarías en `work/` y cuál en `01-nextflow-demo-results/`?
4. ¿Por qué la segunda ejecución reutiliza tareas?

## 6. Conservar los resultados

Copia a `/data` los resultados que quieras conservar. No copies `work/` ni `.nextflow/` salvo que el docente lo indique:

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh \
    --exclude='work/' --exclude='.nextflow/' \
    "$SCRATCH_DIR/ANALYSIS/08-scientific-workflows-nextflow/" \
    "$DATA_DIR/ANALYSIS/08-scientific-workflows-nextflow/"
```
