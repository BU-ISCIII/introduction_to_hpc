# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 8: flujos científicos reproducibles con Nextflow y Slurm

Nextflow describe un análisis como procesos conectados por sus datos de entrada y salida. En lugar de capturar manualmente varios `JOBID` y encadenarlos con `--dependency`, el *workflow manager* calcula dependencias, envía tareas a Slurm y permite reanudar una ejecución con `-resume`.

> Conéctate mediante **MobaXterm (SSH)**. La práctica se ejecuta en el clúster: no se utiliza un subsistema Linux local.

En esta sesión se ejecutará un único caso, pequeño y reproducible: `nf-core/demo` **1.0.2**. Se ha fijado esa versión porque requiere Nextflow `>=24.04.2`, igual que el módulo indicado. No se incluye `nf-core/bacass`: se añadirá como una práctica independiente sólo después de disponer de datos, recursos y una prueba completa en Portutatis.

## 1. Preparación

### 1.1 Rutas y comprobaciones

Define las rutas de esta edición del curso una vez por terminal:

```bash
export COURSE_NAME="20261015_HPC-COURSE_${USER}"
export DATA_DIR="/data/courses/hpc_course/${COURSE_NAME}"
export SCRATCH_DIR="/scratch/hpc_course/${COURSE_NAME}"
export ANALYSIS_DIR="${DATA_DIR}/ANALYSIS"

ls -ld "$DATA_DIR" "$ANALYSIS_DIR"
module spider Nextflow
module spider singularity
```

La configuración y el script se editan en `/data`; tanto `work/` como la caché de Nextflow y las imágenes de Singularity se crean en `/scratch`. No ejecutes el workflow en el nodo de acceso.

### 1.2 Crear y sincronizar la práctica

```bash
mkdir -p "$ANALYSIS_DIR/08-scientific-workflows-nextflow/logs"
cd "$ANALYSIS_DIR/08-scientific-workflows-nextflow"

BASE_URL='https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/main/exercises/08_handson_scientific_workflows_nextflow'
wget -O nextflow.config "$BASE_URL/nextflow.config"
wget -O nextflow_demo.sbatch "$BASE_URL/nextflow_demo.sbatch"

srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh "$DATA_DIR/" "$SCRATCH_DIR/"

cd "$SCRATCH_DIR/ANALYSIS/08-scientific-workflows-nextflow"
pwd
```

## 2. Del encadenamiento manual al workflow

Un análisis convencional con Slurm podría requerir capturar manualmente identificadores y declarar dependencias:

```bash
sbatch fastqc_array.sbatch                 # por ejemplo: 31001
sbatch --dependency=afterok:31001 fastp_array.sbatch
sbatch --dependency=afterok:31002 bowtie2_array.sbatch
```

Esto es aceptable para tres pasos sencillos, pero se vuelve frágil si una tarea falla, hay decenas de muestras o se quiere repetir sólo una parte. En Nextflow declaras los procesos y el flujo de datos. Su ejecutor Slurm crea los trabajos necesarios y mantiene una caché de las tareas completadas.

## 3. Configuración mínima de Nextflow

Abre `nextflow.config`:

```bash
less nextflow.config
```

Su contenido es:

```groovy
singularity {
  enabled    = true
  autoMounts = true
}

process {
  executor      = 'slurm'
  queue         = 'middle_idx'
  cpus          = 2
  memory        = '6 GB'
  time          = '1h'
  jobName       = { "${task.process} (${task.name})" }
  errorStrategy = { task.exitStatus in [140,143,137,138,104,134,139] ? 'retry' : 'finish' }
  maxRetries    = 1
  maxErrors     = -1
}
```

Qué hay que observar:

- `executor = 'slurm'` hace que las tareas del pipeline se envíen a Slurm, en vez de ejecutarse dentro del proceso controlador.
- `queue`, `cpus`, `memory` y `time` son valores por defecto para cada proceso del workflow, no para el controlador.
- `singularity.enabled` permite usar las dependencias encapsuladas por el pipeline sin instalar cada herramienta a mano.
- `errorStrategy` sólo reintenta los códigos de salida enumerados; no convierte cualquier error lógico en un reintento infinito.

## 4. Lanzar `nf-core/demo`

Revisa el script antes de enviarlo. El proceso controlador pide recursos modestos; las tareas del pipeline reciben los que define `nextflow.config`.

```bash
less nextflow_demo.sbatch
sbatch --chdir="$PWD" nextflow_demo.sbatch
```

El script carga los módulos, fija la versión del pipeline y guarda todos los ficheros temporales dentro del directorio actual:

```bash
module purge
module load Nextflow/24.04.2
module load singularity/3.7.1

export NXF_HOME="$PWD/.nextflow"
export NXF_SINGULARITY_CACHEDIR="$PWD/.singularity"

nextflow run nf-core/demo -r 1.0.2 \
  -profile test,singularity \
  -c nextflow.config \
  -work-dir "$PWD/work" \
  --outdir 01-nextflow-demo-results \
  -with-trace trace.txt \
  -with-report report.html \
  -with-timeline timeline.html \
  -resume
```

> En la primera ejecución Nextflow puede tener que descargar el pipeline y Singularity una o varias imágenes. Esto requiere conectividad saliente desde los nodos de cálculo. El docente debe probar este primer arranque antes de la clase; si el centro no permite esas descargas, hay que precargar el pipeline y las imágenes en una caché compartida.

## 5. Seguimiento y resultados

En otra terminal de MobaXterm puedes observar tanto el controlador como las tareas que crea:

```bash
watch -n 2 'squeue --me'
```

Cuando el trabajo finalice, revisa primero el estado de Slurm y el log del controlador:

```bash
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,ExitCode
less "logs/nf_demo-<JOBID>.out"
less "logs/nf_demo-<JOBID>.err"
tail -n 50 .nextflow.log
```

Después explora los productos del workflow:

```bash
find 01-nextflow-demo-results -maxdepth 3 -type f | sort
ls -lh trace.txt report.html timeline.html
```

- `01-nextflow-demo-results/` contiene los resultados publicados por el pipeline.
- `work/` es la caché de tareas; no la edites a mano.
- `trace.txt` relaciona procesos, recursos y estado.
- `report.html` y `timeline.html` permiten revisar gráficamente la ejecución.

Preguntas:

1. ¿Cuántas tareas lanza el pipeline y qué nombres aparecen en `squeue`?
2. ¿Qué diferencia hay entre el `JOBID` del controlador `nf_demo` y los trabajos creados por el ejecutor Slurm?
3. Busca una tarea completada en `trace.txt`: ¿qué CPU, memoria y tiempo solicitó?
4. Ejecuta de nuevo el mismo script. ¿Qué tareas muestra Nextflow como `cached` y por qué?

## 6. Errores frecuentes

| Síntoma | Primera comprobación |
| --- | --- |
| El controlador falla antes de crear tareas | `logs/nf_demo-<JOBID>.err`, `module spider Nextflow`, `nextflow -version`. |
| Una tarea queda pendiente | `squeue --me` y `scontrol show job <JOBID>` para ver `Reason` y recursos solicitados. |
| Falla al descargar el pipeline o una imagen | Revisa conectividad desde nodo de cálculo y la política de caché del centro. |
| `-resume` no reutiliza tareas | Confirma que se conserva `work/`, que se usa el mismo directorio y que no se cambiaron inputs, parámetros o versión del pipeline. |
| Faltan resultados | Revisa `.nextflow.log`, el directorio `work/` de la tarea y `trace.txt`; no te limites al log del controlador. |

## 7. Cierre

Devuelve a `/data` los resultados que deben conservarse. Para ahorrar espacio, no copies `work/`, `.nextflow/` ni `.singularity/` salvo que el docente indique lo contrario:

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh \
    --exclude='work/' --exclude='.nextflow/' --exclude='.singularity/' \
    "$SCRATCH_DIR/ANALYSIS/08-scientific-workflows-nextflow/" \
    "$DATA_DIR/ANALYSIS/08-scientific-workflows-nextflow/"
```
