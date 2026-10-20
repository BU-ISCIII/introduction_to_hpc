# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 8: flujos científicos reproducibles con Nextflow y Slurm

Nextflow describe un análisis como procesos conectados por sus datos de entrada y salida. En lugar de capturar manualmente varios `JOBID` y encadenarlos con `--dependency`, el *workflow manager* calcula dependencias, envía tareas a Slurm y permite reanudar una ejecución con `-resume`.

> Conéctate mediante **MobaXterm (SSH)**. La práctica se ejecuta en el clúster: no se utiliza un subsistema Linux local.

En esta sesión se ejecutará un único caso, pequeño y reproducible: `nf-core/demo` **1.0.2**. Se ha fijado esa versión porque requiere Nextflow `>=24.04.2`, igual que el módulo indicado. No se incluye `nf-core/bacass`: se añadirá como una práctica independiente sólo después de disponer de datos, recursos y una prueba completa en Portutatis.

## 1. Preparación

### 1.1 Rutas y comprobaciones

Define las rutas una vez por terminal. Cada participante trabaja en una carpeta propia, construida automáticamente a partir de su usuario: por ejemplo, el usuario `alumno01` usa `alumno01_workdir`. Así los resultados y ficheros temporales de distintos alumnos no se mezclan.

```bash
export COURSE_NAME="${USER}_workdir"
export DATA_DIR="/data/courses/hpc_course/${COURSE_NAME}"
export SCRATCH_DIR="/scratch/hpc_course/${COURSE_NAME}"
export ANALYSIS_DIR="${DATA_DIR}/ANALYSIS"
export TEMPLATE_DATA_DIR="/data/courses/hpc_course/20261015_HPC-COURSE_profesor00"

# Copia toda la plantilla a tu carpeta personal. El directorio destino se crea
# automáticamente si no existe; repite el comando si el docente actualiza un script.
rsync -rtlv "$TEMPLATE_DATA_DIR/" "$DATA_DIR/"
mkdir -p "$ANALYSIS_DIR/08-scientific-workflows-nextflow/logs"

# Comprueba que la carpeta personal existe y que puedes entrar en ella.
ls -ld "$DATA_DIR" "$ANALYSIS_DIR"
cd "$DATA_DIR" && pwd
module spider Nextflow
module spider singularity
```

Ejecuta el bloque completo en cada terminal nueva: cambiar solo `COURSE_NAME` no actualiza las variables derivadas. Comprueba que `pwd` muestra tu directorio personal antes de continuar. Si el docente actualiza un script durante la sesión, repite el `rsync`: actualizará los ficheros presentes en la plantilla, pero no elimina los resultados que hayas creado en carpetas que no existan en ella. La configuración y el script se editan en `/data`; tanto `work/` como la caché de Nextflow y las imágenes de Singularity se crean en `/scratch`. No ejecutes el workflow en el nodo de acceso.

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
watch squeue --me
```

El trabajo `nf_demo` que enviaste con `sbatch` es el **controlador**: ejecuta Nextflow, interpreta el pipeline y envía a Slurm las tareas que ya tienen disponibles sus datos de entrada. No ejecuta necesariamente el análisis en sí. A medida que terminan tareas, Nextflow detecta sus salidas, desbloquea los procesos dependientes y envía los siguientes trabajos. Así se respeta el orden definido por los datos, sin construir a mano dependencias `afterok`.

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
- `work/` (el valor de `-work-dir`) contiene un subdirectorio por tarea, identificado por un *hash*. Ahí Nextflow prepara enlaces o copias de las entradas, ejecuta el comando y guarda sus salidas y sus logs. Es su caché: no se edita manualmente y debe conservarse para que `-resume` pueda reutilizar tareas completadas.
- `.nextflow.log` es el registro detallado del propio motor Nextflow: decisiones de planificación, tareas enviadas, caché y errores. Es especialmente útil cuando el `.err` del controlador no basta para diagnosticar un problema.

Puedes comprobar esa estructura con:

```bash
find work -maxdepth 2 -type f \( -name '.command.sh' -o -name '.command.out' -o -name '.command.err' \) | head
tail -n 50 .nextflow.log
```

Después explora los productos del workflow:

```bash
find 01-nextflow-demo-results -maxdepth 3 -type f | sort
ls -lh trace.txt report.html timeline.html
```

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
