# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 8: flujos científicos reproducibles con Nextflow y Slurm

Nextflow describe un análisis como procesos conectados por sus datos de entrada y salida. En lugar de capturar manualmente varios `JOBID` y encadenarlos con `--dependency`, el *workflow manager* calcula dependencias, envía tareas a Slurm y permite reanudar una ejecución con `-resume`.

> Conéctate mediante **MobaXterm (SSH)**. La práctica se ejecuta en el clúster: no se utiliza un subsistema Linux local.

En esta sesión se ejecutará un único caso, pequeño y reproducible: `nf-core/demo` **1.0.2**. Se ha fijado esa versión porque requiere Nextflow `>=24.04.2`, igual que el módulo indicado. `nf-core/bacass` no forma parte de la práctica del alumnado: se incluye únicamente el ejemplo docente `bacass_dev_shortreads_professor.sbatch` para validarlo de forma independiente en Portutatis.

## 1. Preparación

### 1.1 Reutilizar el proyecto de las prácticas anteriores

Reutiliza el directorio `FECHA_HPC-COURSE_${USER}` creado en la práctica 4 y utilizado en las prácticas 5 a 7. No crees otra carpeta de curso ni copies de nuevo los FASTQ. Si has abierto una terminal nueva, vuelve a definir las rutas y recibe únicamente el material de la práctica 8:

```bash
# Escribe la fecha que aparece en el nombre de tu carpeta creada en la práctica 4.
# Para esta edición del curso es 20261021.
export COURSE_NAME="20261021_HPC-COURSE_${USER}"
export DATA_DIR="/data/courses/hpc_course/${COURSE_NAME}"
export SCRATCH_DIR="/scratch/hpc_course/${COURSE_NAME}"
export ANALYSIS_DIR="${DATA_DIR}/ANALYSIS"
export TEMPLATE_ANALYSIS_DIR="/data/courses/hpc_course/20261021_HPC-COURSE_profesor00/ANALYSIS"

mkdir -p "$ANALYSIS_DIR/08-scientific-workflows-nextflow/logs"
rsync -rtlv \
  "$TEMPLATE_ANALYSIS_DIR/08-scientific-workflows-nextflow/" \
  "$ANALYSIS_DIR/08-scientific-workflows-nextflow/"

cd "$DATA_DIR" && pwd
```

El `rsync` actualiza los scripts y la configuración de la práctica 8 sin borrar tus resultados anteriores. El análisis se ejecutará desde `/scratch`; las imágenes de Singularity se leen de la caché compartida preparada por el docente. No ejecutes el workflow en el nodo de acceso.

### 1.2 Sincronizar la práctica

La configuración y el script validados ya se han copiado desde la plantilla. Entra en el directorio de la práctica y sincronízalo a `/scratch`.

```bash
cd "$ANALYSIS_DIR/08-scientific-workflows-nextflow"
ls -l

srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh "$DATA_DIR/" "$SCRATCH_DIR/"

cd "$SCRATCH_DIR/ANALYSIS/08-scientific-workflows-nextflow"
pwd
```

## 2. Ejemplo conceptual: encadenar `sbatch` frente a un pipeline Nextflow

El siguiente bloque es **solo un ejemplo conceptual**: los scripts `preprocesamiento.sbatch`, `alineamiento.sbatch` y `resumen.sbatch` no forman parte de esta práctica y no debes ejecutarlos. Ilustra cómo habría que capturar identificadores y declarar dependencias manualmente en Slurm:

```bash
sbatch preprocesamiento.sbatch              # devuelve, por ejemplo, el JOBID 31001
sbatch --dependency=afterok:31001 alineamiento.sbatch  # devuelve el JOBID 31002
sbatch --dependency=afterok:31002 resumen.sbatch
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
  cacheDir   = '/data/courses/hpc_course/references/singularity-cache'
}

process {
  executor      = 'slurm'
  queue         = 'middle_idx'
  cpus          = 2
  memory        = '6 GB'
  time          = '2h'
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
- `singularity.cacheDir` apunta a la caché común de imágenes, que el docente ha descargado antes de la sesión. Todos los alumnos reutilizan la misma imagen en lugar de descargar una copia cada uno.
- `errorStrategy` sólo reintenta los códigos de salida enumerados; no convierte cualquier error lógico en un reintento infinito.

## 4. Lanzar `nf-core/demo`

Revisa el script antes de enviarlo. El proceso controlador pide recursos modestos; las tareas del pipeline reciben los que define `nextflow.config`.

```bash
more nextflow_demo.sbatch
```

El script carga los módulos, fija la versión del pipeline y guarda todos los ficheros temporales dentro del directorio actual:

```bash
module purge
module load Nextflow/24.04.2
module load singularity/3.7.1

nextflow run nf-core/demo -r 1.0.2 \
  -profile test,singularity \
  -c nextflow.config \
  --outdir 01-nextflow-demo-results \
  -resume
```

ejecuta el pipeline:

```bash
sbatch --chdir="$PWD" nextflow_demo.sbatch
```

## 5. Seguimiento y resultados

En otra terminal de MobaXterm puedes observar tanto el controlador como las tareas que crea:

```bash
watch squeue --me
```

El trabajo `nf_demo` que enviaste con `sbatch` es el **controlador/master**: ejecuta Nextflow, interpreta el pipeline y envía a Slurm las tareas que ya tienen disponibles sus datos de entrada. No ejecuta necesariamente el análisis en sí. A medida que terminan tareas, Nextflow detecta sus salidas, desbloquea los procesos dependientes y envía los siguientes trabajos. Así se respeta el orden definido por los datos, sin construir a mano dependencias `afterok`.

Mientras está en marcha, el `stdout` que va escribiendo Nextflow se encuentra en el fichero `.out` del trabajo controlador. Sustituye `<JOBID>` por el identificador que devolvió `sbatch` y sigue el progreso con:

```bash
tail -f "logs/nf_demo-<JOBID>.out"
```

Pulsa `Ctrl+C` para dejar de seguir el fichero; el trabajo continúa ejecutándose. Los avisos y errores enviados a `stderr` quedan en `logs/nf_demo-<JOBID>.err`.

Cuando el trabajo finalice, revisa el estado de Slurm y los registros:

```bash
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,ExitCode
less "logs/nf_demo-<JOBID>.out"
less "logs/nf_demo-<JOBID>.err"
tail -n 50 .nextflow.log
```

Nextflow crea varios directorios y ficheros de control dentro del directorio de ejecución:

- `01-nextflow-demo-results/` (el valor de `--outdir`) contiene los resultados finales que el pipeline publica para consultar o conservar. Es el directorio de salida útil del análisis.
- `work/` (el directorio de trabajo predeterminado de Nextflow) contiene un subdirectorio por tarea, identificado por un *hash*. Ahí Nextflow prepara enlaces o copias de las entradas, ejecuta el comando y guarda sus salidas y sus logs. Es su caché: no se edita manualmente y debe conservarse para que `-resume` pueda reutilizar tareas completadas.
- `.nextflow.log` es el registro detallado del propio motor Nextflow: decisiones de planificación, tareas enviadas, caché y errores. Es especialmente útil cuando el `.err` del controlador no basta para diagnosticar un problema.


Explora ahora los productos finales del workflow. `work/` contiene los resultados intermedios, los scripts y los logs de cada tarea; `01-nextflow-demo-results/` contiene solamente los resultados que el pipeline publica para consultar o conservar:

```bash
ls 01-nextflow-demo-results
```

Deberías ver tres directorios:

- `fq/`: lecturas FASTQ resultantes del paso de procesado con `seqtk`.
- `multiqc/`: informe de control de calidad agregado.
- `pipeline_info/`: informes técnicos de la ejecución de Nextflow.

El informe final que resume las métricas relevantes de las lecturas y el control de calidad es el de MultiQC:

```bash
ls 01-nextflow-demo-results/multiqc
```

El fichero `multiqc_report.html` es el informe que puedes descargar con el panel SFTP de MobaXterm y abrir en tu navegador. Las carpetas `multiqc_data/` y `multiqc_plots/` contienen, respectivamente, las tablas usadas por el informe y sus gráficas estáticas.

Los informes técnicos de Nextflow están en `pipeline_info/`:

```bash
ls 01-nextflow-demo-results/pipeline_info/
```

Los nombres incluyen la fecha y hora de la ejecución. Explora los informes disponibles:

```bash
less 01-nextflow-demo-results/pipeline_info/execution_trace_*.txt
```

- `execution_report_*.html`: informe gráfico de cada tarea, incluyendo duración y recursos usados.
- `execution_timeline_*.html`: línea temporal que muestra qué tareas coincidieron en el tiempo.
- `execution_trace_*.txt`: tabla de texto con una fila por tarea; permite relacionar el nombre de proceso, su estado, su duración y sus recursos.
- `pipeline_dag_*.html`: diagrama de dependencias entre los procesos del workflow.
- `params.json` y `samplesheet.valid.csv`: parámetros efectivos y hoja de muestras validada que utilizó el pipeline.

Puedes descargar los ficheros HTML de `pipeline_info/` con MobaXterm y abrirlos localmente. No confundas `execution_report_*.html`, que describe cómo se ejecutó el workflow, con `multiqc_report.html`, que resume los resultados biológicos y de control de calidad.

Preguntas:

1. ¿Cuántas tareas lanza el pipeline y qué nombres aparecen en `squeue`?
2. ¿Qué diferencia hay entre el `JOBID` del controlador `nf_demo` y los trabajos creados por el ejecutor Slurm?
3. Busca una tarea completada en `pipeline_info/execution_trace_*.txt`: ¿qué CPU, memoria y tiempo solicitó?
4. Ejecuta de nuevo el mismo script. ¿Qué tareas muestra Nextflow como `cached` y por qué?

## 6. Errores frecuentes

| Síntoma | Primera comprobación |
| --- | --- |
| El controlador falla antes de crear tareas | `logs/nf_demo-<JOBID>.err`, `module spider Nextflow`, `nextflow -version`. |
| Una tarea queda pendiente | `squeue --me` y `scontrol show job <JOBID>` para ver `Reason` y recursos solicitados. |
| No se encuentra una imagen de Singularity | Revisa que la caché compartida sea accesible y avisa al docente; no la descargues individualmente. |
| `-resume` no reutiliza tareas | Confirma que se conserva `work/`, que se usa el mismo directorio y que no se cambiaron inputs, parámetros o versión del pipeline. |
| Faltan resultados | Revisa `.nextflow.log`, el directorio `work/` de la tarea y `trace.txt`; no te limites al log del controlador. |

## 7. Cierre

Devuelve a `/data` los resultados que deben conservarse. Para ahorrar espacio, no copies `work/` ni `.nextflow/` salvo que el docente indique lo contrario. Las imágenes de Singularity ya están en la caché compartida:

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh \
    --exclude='work/' --exclude='.nextflow/' \
    "$SCRATCH_DIR/ANALYSIS/08-scientific-workflows-nextflow/" \
    "$DATA_DIR/ANALYSIS/08-scientific-workflows-nextflow/"
```
