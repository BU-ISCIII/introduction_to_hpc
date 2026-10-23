# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 7: scripting y paralelización con Slurm

En esta práctica enviarás scripts al planificador Slurm, diagnosticarás un trabajo correcto y uno fallido, usarás *job arrays* y compararás OpenMP con MPI.

> Conéctate al clúster mediante **MobaXterm (SSH)**. Todos los comandos de esta guía se ejecutan ya en el clúster; no se utiliza un subsistema Linux local.

## Antes de empezar

- No ejecutes análisis en el nodo de acceso. Usa `sbatch` para trabajos por lotes y `srun` para comandos interactivos o transferencias que deban ejecutarse en un nodo de cálculo.
- Guarda y edita los scripts en `/data`; ejecuta y genera los ficheros temporales en `/scratch`.
- Anota el identificador que devuelve `sbatch`. Los identificadores cambian en cada envío.
- Sustituye `<JOBID>` por el identificador real, sin los signos `<` y `>`.

Las prácticas 4 y 5 ya crearon tu directorio de curso, con el formato `FECHA_HPC-COURSE_${USER}`, los FASTQ en `RAW/` y los enlaces de `ANALYSIS/00-reads`. No crees otro directorio ni vuelvas a copiar los FASTQ. Define las rutas de ese proyecto existente una vez por terminal:

```bash
# Escribe la fecha que aparece en el nombre de tu carpeta creada en la práctica 4.
# Para esta edición del curso es 20261021.
export COURSE_NAME="20261021_HPC-COURSE_${USER}"
export DATA_DIR="/data/courses/hpc_course/${COURSE_NAME}"
export SCRATCH_DIR="/scratch/hpc_course/${COURSE_NAME}"
export ANALYSIS_DIR="${DATA_DIR}/ANALYSIS"
export TEMPLATE_ANALYSIS_DIR="/data/courses/hpc_course/20261021_HPC-COURSE_profesor00/ANALYSIS"

# Crea las carpetas de las prácticas 7 y 8 y recibe sus scripts del docente.
mkdir -p "$ANALYSIS_DIR/07-scripting-and-parallelization/logs"
mkdir -p "$ANALYSIS_DIR/08-scientific-workflows-nextflow/logs"
rsync -rtlv \
  "$TEMPLATE_ANALYSIS_DIR/07-scripting-and-parallelization/" \
  "$ANALYSIS_DIR/07-scripting-and-parallelization/"
rsync -rtlv \
  "$TEMPLATE_ANALYSIS_DIR/08-scientific-workflows-nextflow/" \
  "$ANALYSIS_DIR/08-scientific-workflows-nextflow/"

# Comprueba que están la carpeta y los scripts de la práctica 7.
ls -ld "$ANALYSIS_DIR/07-scripting-and-parallelization"
ls -1 "$ANALYSIS_DIR/07-scripting-and-parallelization/"*.sbatch
```

> Deben aparecer los siete archivos `.sbatch` de la práctica 7. Si el docente actualiza algún script, repite los dos `rsync`: actualizan los ficheros de las prácticas 7 y 8 sin borrar resultados.

## 1. Sincronizar la práctica a `/scratch`

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh "$DATA_DIR/" "$SCRATCH_DIR/"

cd "$SCRATCH_DIR/ANALYSIS/07-scripting-and-parallelization"
pwd
```

## 2. Un trabajo correcto y dos diagnósticos

Los scripts usan rutas relativas desde `07-scripting-and-parallelization`; envíalos siempre con `--chdir="$PWD"`. Todos incluyen `set -euo pipefail` después de las directivas `#SBATCH`.

Hace que el script se detenga ante un comando fallido (`-e`), una variable inexistente (`-u`) o un error dentro de una tubería (`pipefail`).

> **Idea clave:** un mensaje de error no basta para que Slurm marque el trabajo como fallido; el programa debe devolver un código distinto de cero. `set -e` solo puede detener el script cuando el comando ya devuelve ese error.

### Monitorización

- `squeue --me`: trabajos que aún están en cola (`PD`) o ejecutándose (`R`).
- `sacct -j <JOBID> ...`: resultado final, tiempo, memoria, CPU y `ExitCode`. Puede tardar unos segundos en aparecer tras terminar.

### Ejercicio 1 — FastQC correcto (`fastqc_demo.sbatch`)

Explora el script:
```bash
more fastqc_demo.sbatch
```

El script reserva cuatro CPU con `--cpus-per-task=4` y pasa exactamente ese valor a FastQC mediante `-t "$SLURM_CPUS_PER_TASK"`. Solicitar CPU a Slurm no paraleliza por sí solo el programa: el parámetro `-t` es el que comunica a FastQC cuántos hilos puede utilizar.

Ejecuta el trabajo:
```bash
sbatch --chdir="$PWD" fastqc_demo.sbatch
```

En una segunda pestaña de MobaXterm, monitoriza el trabajo mientras está activo. Se actualizará cada segundo; termina con `Ctrl+C` cuando el trabajo desaparezca de la cola:

```bash
watch squeue --me
```

Cuando termine, consulta el historial y los logs:

```bash
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,TotalCPU,ExitCode
less "logs/fastqc_demo-<JOBID>.out"
less "logs/fastqc_demo-<JOBID>.err"
ls -lh 01-fastqc-demo-results/
```

Preguntas:

1. ¿En qué partición y nodo se ejecutó?
2. ¿Qué estado y `ExitCode` tiene el trabajo?
3. ¿Cuánto tardó y qué `MaxRSS` alcanzó?

### Ejercicio 2 — Entrada inexistente (`fastqc_failcmd.sbatch`)

Explora el script:

```bash
more fastqc_failcmd.sbatch
```

`fastqc_failcmd.sbatch` referencia deliberadamente un FASTQ inexistente (`does_not_exist_R1.fastq.gz`). No cambies el script antes de enviarlo.

Ejecuta el trabajo:

```bash
sbatch --chdir="$PWD" fastqc_failcmd.sbatch
```

El trabajo es muy corto, pero puedes intentar observarlo mientras está activo:

```bash
watch squeue --me
```

Cuando termine, consulta el historial y el error:

```bash
sacct -j <JOBID> -o JobID,State,Elapsed,ExitCode
tail -n 20 "logs/fastqc_fail-<JOBID>.err"
```

Preguntas:

1. ¿Qué fichero indica FastQC que no puede leer?
2. ¿Qué `ExitCode` aparece? En esta versión de FastQC, ¿el aviso sobre el fichero ausente hace que el trabajo termine como `FAILED` o como `COMPLETED`?
3. Aunque el script use `set -euo pipefail`, ¿por qué Bash no puede detenerlo por este aviso? Pista: `set -e` sólo actúa si el comando devuelve un código distinto de cero.
4. ¿Cuál sería el cambio mínimo para corregir la ruta de entrada?

### Ejercicio 3 — Solicitud de memoria imposible (`fastqc_overask.sbatch`)

Explora el script:

```bash
more fastqc_overask.sbatch
```

El script `fastqc_overask.sbatch` pide `2T` de RAM. En Portutatis, el nodo con más memoria tiene `2.031.000 MB` (aproximadamente 1,94 TiB), por lo que esta solicitud supera la capacidad de cualquier nodo. En una futura edición del curso, comprueba el máximo con `sinfo` y ajusta `--mem` si cambia el hardware.

Intenta enviarlo:

```bash
sbatch --chdir="$PWD" fastqc_overask.sbatch
```

Slurm rechaza la solicitud antes de crear el trabajo, con un mensaje similar a:

```text
sbatch: error: Memory specification can not be satisfied
sbatch: error: Batch job submission failed: Requested node configuration is not available
```

No habrá `JOBID`, no aparecerá nada en `squeue` y no hay que usar `scancel`: el trabajo nunca ha entrado en la cola.

En cambio, una solicitud que **sí puede satisfacerse** pero para la que todos los nodos adecuados están ocupados quedará en estado `PD` con un `Reason` como `Resources`. En ese caso sí existe un `JOBID` y se puede inspeccionar y cancelar si se envió por error:

```bash
squeue --me
scancel <JOBID>
sacct -j <JOBID> -o JobID,State,Elapsed,ExitCode
```

Tras `scancel`, el trabajo desaparece de `squeue` y normalmente queda registrado como `CANCELLED` en `sacct`. No ejecutes `scancel` sobre trabajos de otros usuarios.

Preguntas:

1. ¿Qué recurso solicitado no puede satisfacer el clúster?
2. ¿En qué momento detecta Slurm el problema: al enviar el trabajo o cuando ya está en cola?
3. ¿Qué valor de `--mem` deberías solicitar como máximo para que al menos un nodo pueda aceptarlo?

## 3. Job arrays

Un *job array* envía muchas tareas con el mismo script. Cada tarea tiene el mismo `SLURM_ARRAY_JOB_ID` y un `SLURM_ARRAY_TASK_ID` distinto. El patrón `%A_%a` en los logs evita que se mezclen sus salidas.

### Ejercicio 1 — Dos muestras con índices consecutivos (`array_demo.sbatch`)

Explora primero el script:

```bash
more array_demo.sbatch
```

Un *job array* no es un único trabajo que recorre muestras con un bucle. Al enviar un array, Slurm crea varias **tareas independientes** a partir del mismo script. Cada tarea puede empezar, esperar o terminar en un momento distinto, pero todas comparten la misma configuración de recursos.

En este ejemplo, `array_demo.sbatch` procesa `virus1` y `virus2`.

Identifica estas líneas:

| Línea del script | Qué significa |
| --- | --- |
| `#SBATCH --array=1-2` | Slurm creará dos tareas, con índices 1 y 2. |
| `#SBATCH --cpus-per-task=1` y `--mem=2G` | Cada tarea pide sus propios 1 CPU y 2 GB; no se reparten entre las dos. |
| `virus${SLURM_ARRAY_TASK_ID}_R1.fastq.gz` | En la tarea 1 la variable vale `1` y usa `virus1`; en la tarea 2 vale `2` y usa `virus2`. |
| `demo_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}` | Cada tarea escribe en su propio directorio de resultados. |
| `logs/%x-%A_%a.out` | Slurm genera un log por tarea: `%A` es el identificador base del array y `%a` es su índice. |

Por tanto, una misma plantilla produce esta correspondencia:

| Tarea | `SLURM_ARRAY_TASK_ID` | FASTQ procesados |
| --- | --- | --- |
| 1 | `1` | `virus1_R1.fastq.gz` y `virus1_R2.fastq.gz` |
| 2 | `2` | `virus2_R1.fastq.gz` y `virus2_R2.fastq.gz` |

Envía el array:

```bash
sbatch --chdir="$PWD" array_demo.sbatch
```

Monitoriza las dos tareas mientras esperan o se ejecutan. El script espera 60 segundos antes de iniciar FastQC, para que dé tiempo a observarlas:

```bash
watch squeue --me
```

Cuando finalice el array, consulta el historial y los resultados:

```bash
sacct -j <ARRAY_JOBID> -o JobID,JobName%20,State,Elapsed,MaxRSS,ExitCode
find 02-array-demo-results -maxdepth 2 -type f -name '*.html'
```

`sbatch` devolverá un único identificador base, por ejemplo `6500000`. En `squeue` y `sacct` verás las tareas como `6500000_1` y `6500000_2` (el formato exacto puede variar ligeramente). No asumas que la tarea 1 termina antes que la 2: Slurm las planifica de forma independiente.

Preguntas:

1. ¿Qué `ArrayJobID` comparten las tareas y qué `TaskID` tiene cada una?
2. ¿Qué archivos de log corresponden a cada tarea?
3. ¿Cuál fue el `MaxRSS` de cada tarea?

### Ejercicio 2 — Array a partir de `samples_id.txt` (`fastqc_array_samplesid.sbatch`)

Explora el script:

```bash
more fastqc_array_samplesid.sbatch
```

Este array obtiene la muestra de la línea que corresponde a su índice. El rango se calcula desde el fichero para que no haya que modificar el script cuando cambie la lista. Todas las tareas del array se envían sin limitar su concurrencia.

En el script, la asignación siguiente realiza el emparejamiento entre tarea y muestra:

```bash
# NO EJECUTAR!!
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")
```

`$(...)` guarda en `SAMPLE` la salida del comando interno. `sed -n` no imprime las líneas por defecto y la orden `p` imprime solo la línea indicada: para la tarea 1, la expresión se convierte en `1p` y se lee la primera línea de `samples_id.txt`; para la tarea 2, `2p` y la segunda. Por tanto, cada tarea recibe un identificador de muestra distinto sin que haya un bucle que lance FastQC manualmente.

Calcula el número de muestras:

```bash
N_SAMPLES=$(wc -l < "$SCRATCH_DIR/ANALYSIS/samples_id.txt")
echo "$N_SAMPLES"
```

Envía el array:

```bash
sbatch --chdir="$PWD" --array="1-${N_SAMPLES}" fastqc_array_samplesid.sbatch
```

Monitoriza las tareas mientras están activas:

```bash
watch squeue --me
```

Cuando termine el array, consulta el historial y los resultados:

```bash
sacct -j <ARRAY_JOBID> -o JobID,State,Elapsed,MaxRSS,ExitCode
tree 03-fastqc-array-results
```

El script valida que exista un identificador y los dos FASTQ antes de ejecutar FastQC. Los logs de Slurm están en `logs/`; los resultados de cada tarea quedan en un directorio que incluye `ArrayJobID`, `TaskID` y nombre de muestra.

Preguntas:

1. ¿Por qué el rango se calcula con `wc -l` y no se escribe a mano?
2. ¿Cuántas tareas se enviarán si `samples_id.txt` contiene cinco muestras?
3. ¿Cómo reenviarías únicamente la tarea 3 si hubiese fallado?

## 4. OpenMP frente a MPI

| Modelo | Slurm | Idea |
| --- | --- | --- |
| OpenMP | `--cpus-per-task` | Un proceso con varios hilos en un nodo. |
| MPI | `--nodes`, `--ntasks`, `--ntasks-per-node` | Varios procesos que pueden repartirse entre nodos. |

Pedir recursos no paraleliza un programa por sí solo: hay que comunicar el número de hilos o procesos al ejecutable.

### Ejercicio 1 — OpenMP con SPAdes (`spades_openmp.sbatch`)

Explora el script:

```bash
more spades_openmp.sbatch
```

El script solicita 16 CPU para un único proceso y pasa ese valor a `spades.py` mediante `--threads "$SLURM_CPUS_PER_TASK"`.

Envía el trabajo:

```bash
sbatch --chdir="$PWD" spades_openmp.sbatch
```

Monitoriza el trabajo mientras está activo:

```bash
watch squeue --me
```

Cuando termine, consulta el historial:

```bash
sacct -j <JOBID> -o JobID,State,Elapsed,MaxRSS,AllocCPUS,TotalCPU,NodeList,ExitCode
```

Cuando termine, revisa `04-openmp-spades-results/spades_sample01/`.

```bash
ls -l 04-openmp-spades-results/spades_sample01/
```

Preguntas:

1. ¿Cuántos nodos reservó y por qué?
2. ¿Qué parámetro de SPAdes recibe el número de CPU que concede Slurm?
3. ¿Qué inconveniente tendría pedir 32 CPU y 64 GB si el análisis no los utiliza?

### Ejercicio 2 — MPI con RAxML (`raxml_mpi.sbatch`)

Explora el script:

```bash
more raxml_mpi.sbatch
```

El ejemplo es deliberadamente pequeño: su propósito es observar la distribución de procesos, no medir rendimiento. El archivo `data/raxml_demo.phy` es un alineamiento de ADN de ejemplo procedente de IQ-TREE, fijo y versionado con la práctica. Ya se copió al directorio de trabajo al sincronizar la práctica. Compruébalo:

```bash
head -n 3 data/raxml_demo.phy
```

El fichero está en formato **PHYLIP**, uno de los formatos que acepta RAxML. La primera línea indica `17 1998`: contiene 17 secuencias (taxones) y cada una tiene 1.998 posiciones. Cada línea posterior tiene un identificador, por ejemplo `LngfishAu`, seguido de su secuencia de nucleótidos. Todas las secuencias tienen la misma longitud y sus posiciones están alineadas: la posición 1 de una secuencia se compara con la posición 1 de todas las demás. Es el alineamiento de entrada a partir del cual RAxML busca árboles filogenéticos.

`raxml_mpi.sbatch` solicita dos nodos con cuatro procesos MPI en cada uno. El módulo disponible proporciona el binario híbrido `raxmlHPC-HYBRID-AVX2`: cada proceso MPI usa dos hilos compartiendo memoria. Por eso el script reserva `--cpus-per-task=2` y RAxML recibe `-T 2`. En total reserva 2 nodos × 4 procesos MPI × 2 CPU = 16 CPU. `mpirun -np 8` inicia los ocho procesos MPI, igual que `--ntasks=8`. Estos números deben mantenerse coordinados con las directivas `#SBATCH`. `mpirun` es el lanzador de OpenMPI incluido en el módulo `gompi`; Slurm ya ha reservado y asignado los nodos.

RAxML ejecuta ocho búsquedas independientes (`-# 8`) y conserva el árbol con mejor puntuación en `RAxML_bestTree.ML_searches`. El objetivo del ejercicio es observar cómo se reparten los procesos MPI, no interpretar ese árbol. Con este input el cálculo termina muy rápido; por ello, el script espera deliberadamente 60 segundos antes de lanzar RAxML. No es parte del análisis: permite abrir antes otra terminal de MobaXterm con `watch squeue --me` y observar la reserva de los dos nodos.

> **Nota técnica opcional:** `-m GTRCAT` es el modelo indicado en el script. CAT es una aproximación rápida para tener en cuenta que las posiciones de un alineamiento no evolucionan todas a la misma velocidad. Al finalizar, RAxML puede mostrar en el log una evaluación más exhaustiva bajo GAMMA. No es necesario conocer esos modelos para comprender la paralelización MPI.

Envía el trabajo:

```bash
sbatch --chdir="$PWD" raxml_mpi.sbatch
```

Monitoriza la reserva de los dos nodos mientras está activa:

```bash
watch squeue --me
```

Cuando termine, consulta el historial:

```bash
sacct -j <JOBID> -o JobID,JobName%20,State,Elapsed,AllocCPUS,NodeList,ExitCode
```

Preguntas:

1. ¿Aparecen realmente dos nodos en `NodeList`?
2. ¿Cuántos procesos MPI y cuántos hilos usa cada nodo? ¿Cuántas CPU se reservan en total?
3. ¿Qué ficheros `RAxML_result.ML_searches.RUN.*` aparecen y cuál es el árbol final elegido?
4. Si cambias a `--nodes=1 --ntasks=4 --ntasks-per-node=4`, ¿qué cambia en `NodeList`? ¿Por qué este input no sirve para comparar tiempos de escalado?

## 5. Cierre

Sincroniza los resultados finales a `/data` desde un nodo de cálculo:

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh "$SCRATCH_DIR/ANALYSIS/07-scripting-and-parallelization/" \
             "$DATA_DIR/ANALYSIS/07-scripting-and-parallelization/"
```

Regla práctica:

- **OpenMP**: un proceso, varios hilos, un nodo.
- **MPI**: varios procesos que se comunican, potencialmente en varios nodos.
- **Job array**: muchas tareas independientes con el mismo patrón de ejecución.
