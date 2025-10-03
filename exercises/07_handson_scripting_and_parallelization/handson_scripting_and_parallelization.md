# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 7: Scripting and Parallelization on HPC (Slurm)

Bienvenido a la sesión práctica sobre scripting y paralelización en nuestro HPC. En esta práctica aprenderás a lanzar scripts `sbatch` al sistema de colas, escalarás cargas de trabajo pesadas y repetitivas usando Job Arrays y finalmente compararás estrategias de parallelización en HPC con OpenMP vs MPI.

- [Curso Práctico de Iniciación al uso del Entorno de Alta Computación](#curso-práctico-de-iniciación-al-uso-del-entorno-de-alta-computación)
  - [Práctica 7: Scripting and Parallelization on HPC (Slurm)](#práctica-7-scripting-and-parallelization-on-hpc-slurm)
  - [1. Envío de trabajos con `sbatch` (Slurm)](#1-envío-de-trabajos-con-sbatch-slurm)
    - [Descripción](#descripción)
    - [Notas importantes](#notas-importantes)
    - [Flujo de trabajo con `/data` y `/scratch`](#flujo-de-trabajo-con-data-y-scratch)
    - [Preparación inicial](#preparación-inicial)
    - [Ejercicio 1 — Ejecución correcta](#ejercicio-1--ejecución-correcta)
    - [Ejercicio 2 — Fallo del comando (archivo inexistente)](#ejercicio-2--fallo-del-comando-archivo-inexistente)
    - [Ejercicio 3 — Pendiente por recursos imposibles (over-ask)](#ejercicio-3--pendiente-por-recursos-imposibles-over-ask)
  - [2. Job Arrays (Slurm)](#2-job-arrays-slurm)
    - [Descripción](#descripción-1)
    - [Ejercicio 1 — Intro con Job Arrays](#ejercicio-1--intro-con-job-arrays)
    - [Ejercicio 2 — Job Array con lista de IDs (samples\_id.txt)](#ejercicio-2--job-array-con-lista-de-ids-samples_idtxt)
  - [3. OpenMP vs MPI](#3-openmp-vs-mpi)
    - [Descripción](#descripción-2)
    - [Notas importantes](#notas-importantes-1)
    - [Ejercicio 1 — OpenMP en software de ensamblado (**SPAdes**)](#ejercicio-1--openmp-en-software-de-ensamblado-spades)
    - [Ejercicio 2 — MPI con **RAxML**](#ejercicio-2--mpi-con-raxml)
      - [Objetivo](#objetivo)
      - [Pasos](#pasos)
      - [Consejos rápidos para interpretar resultados](#consejos-rápidos-para-interpretar-resultados)
    - [Sincronización final](#sincronización-final)
    - [Mini-decisión “qué uso”](#mini-decisión-qué-uso)

## 1. Envío de trabajos con `sbatch` (Slurm)

### Descripción

En esta práctica aprenderás a crear un script `sbatch` y a enviarlo al sistema de colas del HPC. Además, **monitorizarás** la ejecución con Slurm y diagnosticarás el resultado usando los ficheros de log (`%x-%j.out/.err`) y los comandos `squeue`, `scontrol` y `sacct`.
Partiremos de un **script base** que ejecuta **FastQC** sobre dos FASTQ pequeños y crearemos **3 variantes** para observar:

1. ejecución correcta,
2. fallo del comando por entrada inexistente,
3. trabajo atascado en **PD** por pedir **recursos imposibles**.

### Notas importantes

- **No** ejecutes trabajos pesados en el nodo de login. Usa siempre `sbatch` (o `srun`).
- Ajusta `--time`, `--cpus-per-task` y `--mem` a lo **mínimo razonable**.
- Los **JOBID** cambian en cada envío; **toma nota** del número que te devuelve `sbatch`.
- Si tu entorno no tiene FastQC o los FASTQ de prueba, pide al docente la ruta de datos del curso.
- Comandos clave: `sbatch`, `squeue`, `scontrol show job <jobid>`, `sacct -j <jobid> -o ...`, `less`, `tail -n +1`.

> Recurso adicional: <http://ganglia.isciii.es/> ofrece una interfaz web para visualizar el estado de nodos y trabajos en tiempo real. Úsalo como apoyo mientras monitorizas con `squeue`/`sacct`.

### Flujo de trabajo con `/data` y `/scratch`

El clúster separa los espacios de trabajo en dos zonas con permisos distintos:

- `/data`: almacenamiento persistente, con permisos de escritura. Úsalo para mantener la copia de referencia y guardar los resultados finales.
- `/scratch`: almacenamiento temporal y de alto rendimiento, sin permisos de escritura directa desde el nodo de login. Los trabajos de Slurm **deben** ejecutarse desde aquí.

Pasos recomendados para organizar la práctica:

1. **Edita** todos los scripts `sbatch` en `/data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization`.
2. **Sincroniza** esa carpeta a `/scratch` cuando vayas a lanzar trabajos (y repite al final para devolver los resultados a `/data`).
3. **Ejecuta** siempre `sbatch`/`srun` desde la ruta equivalente en `/scratch/hpc_course/...`.

> Los esqueletos de los scripts están publicados en <https://github.com/BU-ISCIII/introduction_to_hpc/tree/main/exercises/07_handson_scripting_and_parallelization>. Copia su contenido fielmente y respeta los nombres de archivo.

### Preparación inicial

1. **Crea (si hace falta) la carpeta de trabajo en `/data`** y entra en ella:

   ```bash
   mkdir -p /data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/logs
   cd /data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization
   ```

2. **Prepara el fichero auxiliar que usaremos más adelante `samples_id.txt`** (si todavía no existe) en `ANALYSIS/`:

Nos movemos a la carpeta en nuestra carpeta compartida dentro del hpc

```bash
cd /data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS
```

Creamos las carpetas que vamos a necesitar:

```bash
mkdir -p 00-reads
```

Vamos a crear un archivo con los nombres de los muestras

```bash
ls ../RAW/*.fastq.gz | cut -d "/" -f 3 | cut -d "_" -f 1 | sort -u > samples_id.txt
```

Por último creamos enlaces simbólicos para cada muestra de forma homogéne en 00-reads para tenerlo a mano

```bash
cd 00-reads 
cat ../samples_id.txt | xargs -I % echo "ln -s ../../RAW/%_*1*.fastq.gz %_R1.fastq.gz" | bash
cat ../samples_id.txt | xargs -I % echo "ln -s ../../RAW/%_*2*.fastq.gz %_R2.fastq.gz" | bash
```

> Nota: Puedes modificar la lista si quieres procesar otros identificadores.

3. **Descarga o crea los scripts `sbatch`** usando la versión RAW de GitHub (o abre `nano` y pega el contenido). Ejemplo con `wget` para cada archivo:

  Dirígete a la carpeta de la práctica:

   ```bash
  cd /data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization
   ```

  Descarga los scripts sbatch:

   ```bash
   wget -O fastqc_demo.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/fastqc_demo.sbatch
   wget -O fastqc_failcmd.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/fastqc_failcmd.sbatch
   wget -O fastqc_overask.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/fastqc_overask.sbatch
   wget -O array_demo.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/array_demo.sbatch
   wget -O fastqc_array_samplesid.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/fastqc_array_samplesid.sbatch
   wget -O spades_openmp.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/spades_openmp.sbatch
   wget -O raxml_mpi.sbatch https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/refs/heads/main/exercises/07_handson_scripting_and_parallelization/raxml_mpi.sbatch
   ```

   Revisa cada archivo y adapta rutas o recursos si el docente te lo indica.

4. **Sincroniza con `/scratch`** antes de ejecutar nada:

   ```bash
   srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
     rsync -avh /data/courses/hpc_course/*HPC-COURSE_${USER} \
     /scratch/hpc_course/
   ```

A partir de ahora trabaja desde `/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization` y mantén los nombres de archivo tal como figuran en el repositorio original.

---

### Ejercicio 1 — Ejecución correcta

**Objetivo**
Ejecutar el script tal cual, comprobar el nodo, los logs y el estado final.

**Pasos**

1. Sitúate en `/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization` (compruébalo con `pwd` o `ls`).

```bash
cd /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization
pwd
```

2. **Enviar** el trabajo

Descargado como **`fastqc_demo.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_demo
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

# Carga dependencias
module load FastQC/0.11.9-Java-11

# Info útil para el log
echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

# Crea la carpeta de resultados
mkdir -p 01-fastqc-demo-results

# Ejecuta fastqc
fastqc \
  /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus1_R1.fastq.gz \
  /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus1_R2.fastq.gz \
  -o 01-fastqc-demo-results
```

Envía el trabajo:

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization fastqc_demo.sbatch
```

> Nota: ejecutamos la directiva `--chdir` desde la línea de comandos, en lugar de dejarla en el script, para que bash expanda correctamente el patrón `*HPC-COURSE_${USER}`. Si lo prefieres, puedes volver a incluirla en el script de `sbatch` y sustituir `*HPC-COURSE_${USER}` por el nombre exacto de tu carpeta de trabajo.

3. Monitorizar en cola

```bash
squeue -u $USER -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
```

> Los `squeue -u $USER -o "…"` que verás a lo largo de la práctica muestran varias columnas útiles: `%i` (JobID), `%j` (JobName), `%t` (State), `%P` (Partition), `%R` (Reason/NodeList), `%C` (CPUs asignadas) y `%c` (CPUs por tarea), entre otras.

4. Ver detalles (nodo, recursos, razón si está en PD)

```bash
scontrol show job <JOBID> | grep 'JobName\|NumNodes\|NumCPUs\|TRES\|Nodes\|Reason\|Submit\|Start\|TimeLimit'
```

5. Al finalizar, revisar histórico y uso

```bash
sacct -j <JOBID> -o JobID,State,Elapsed,MaxRSS,TotalCPU,ExitCode
```

> Nota rápida sobre `sacct -j <JOBID> -o JobID,State,Elapsed,ExitCode`:
> `-j <JOBID>` filtra el informe para ese identificador. `-o` elige las columnas a mostrar. Con este formato verás:
> • `JobID`: identificador del trabajo o la tarea del array.
> • `State`: estado final (COMPLETED, FAILED, TIMEOUT, etc.).
> • `Elapsed`: tiempo transcurrido real.
> • `ExitCode`: código de salida devuelto por el script (0 indica éxito).

6. Leer logs y resultados:

```bash
# Resultados disponibles en: 01-fastqc-demo-results/
ll /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/01-fastqc-demo-results

# Logs y errores disponibles en logs/
less /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/logs/fastqc_demo-<JOBID>.out

less /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/logs/fastqc_demo-<JOBID>.err
```

**PREGUNTA:**

¿En qué **partición** se ejecutó el trabajo y cuánto **tiempo** tardó?

¿En qué estado se encuentra el trabajo?

> Estados típicos: **PD** (PENDING), **R** (RUNNING), **CG** (COMPLETING), **CD** (COMPLETED), **F** (FAILED), **TO** (TIMEOUT), **CA** (CANCELLED), **NF** (NODE\_FAIL).

---

### Ejercicio 2 — Fallo del comando (archivo inexistente)

**Objetivo**
Forzar un error de ejecución para explorar el `stderr` y el `ExitCode`.

En este caso modificamos el script, lo guardamos como **`fastqc_failcmd.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_fail
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

# Carga dependencias
module load FastQC/0.11.9-Java-11

mkdir -p 01-fastqc-demo-results
fastp \
  /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus1_R1.fastq.gz \
  /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus1_R2.fastq.gz \
  -o 01-fastqc-demo-results
```

Lanza el trabajo y monitoriza:

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization fastqc_failcmd.sbatch

sacct -j <JOBID> -o JobID,State,Elapsed,ExitCode

tail /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/logs/fastqc_fail-<JOBID>.err
```

*Ejemplo de error esperado en `.err`:*

```
/var/spool/slurmd/job4906011/slurm_script: line 21: fastp: command not found
```

**PREGUNTA:**

¿Qué **mensaje de error** aparece en `fastqc_fail-<jobid>.err` y qué **ExitCode** ves en `sacct`?

¿Qué **cambio mínimo** haría que el trabajo funcione?

---

### Ejercicio 3 — Pendiente por recursos imposibles (over-ask)

**Objetivo**
Ver qué pasa cuando pedimos más recursos de los que el nodo puede ofrecer. El trabajo se queda en **PD (Pending)**.

Script: **`fastqc_overask.sbatch`**

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_overask
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=2
#SBATCH --mem=530G                       # << imposible en este nodo
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

module load FastQC/0.11.9-Java-11

echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

mkdir -p 01-fastqc-demo-results
fastqc \
  /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus1_R1.fastq.gz \
  /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus1_R2.fastq.gz \
  -o 01-fastqc-demo-results
```

Lanza el trabajo y monitoriza:

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization fastqc_overask.sbatch
squeue -u $USER -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
scontrol show job <JOBID> | egrep 'Reason|Req|MinCPUs|TRES|Nodes|Partition|QOS'
```

Cuando los recursos no pueden ser asignados, por ejemplo, por una solicitud de recursos fuera de los límites, la tarea se queda en estado "PD" (Pending). Cuando esto ocurre, tenemos que cancelar la el trabajo utilizando el comando:

```
scancel <JOBID>
```

**PREGUNTA:**
¿Qué **Reason** muestra el trabajo en **PD**?
¿Qué parámetro ajustarías para que **empiece**?

---

## 2. Job Arrays (Slurm)

### Descripción

En este apartado veremos cómo **automatizar ejecuciones repetitivas**.
Si tienes más de 20 FASTQ y necesitas correr siempre el mismo comando (`fastqc`), un bucle `for` sería lento y poco eficiente.

Los **Job Arrays** permiten enviar un solo trabajo que se divide en **N tareas** (una por muestra), cada una con su índice (`$SLURM_ARRAY_TASK_ID`). Así puedes paralelizar, reservar recursos por tarea y obtener logs separados.

---

### Ejercicio 1 — Intro con Job Arrays

Trabajaremos con archivos que siguen el patrón `virus1_R1.fastq.gz`, `virus1_R2.fastq.gz`, `virus2_R1.fastq.gz`, y `virus2_R2.fastq.gz`. En este ejemplo solo hay dos muestras (`virus1` y `virus2`), de modo que el array necesita dos tareas. Por ello, en la directiva de `sbatch` declaramos `--array=1-2`, lo que hace que Slurm genere los índices 1 y 2 para recorrer ambas muestras (ver más abajo).

Cada tarea del array procesará un par R1/R2.

Script: **`array_demo.sbatch`**

```bash
#!/bin/bash
#SBATCH --job-name=array_demo
#SBATCH --partition=short_idx
#SBATCH --array=1-2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err

module load FastQC/0.11.9-Java-11

mkdir -p 02-array-demo-results
OUTDIR="02-array-demo-results/demo_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$OUTDIR"

fastqc -o "$OUTDIR" /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus${SLURM_ARRAY_TASK_ID}_R1.fastq.gz /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/00-reads/virus${SLURM_ARRAY_TASK_ID}_R2.fastq.gz

echo "[INFO] JobID=${SLURM_JOBID}; Task=${SLURM_ARRAY_TASK_ID}; End=$(date)"
```

Ejecuta el job:

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization array_demo.sbatch
```

**PREGUNTAS**

- ¿Cuántas muestras se procesan en el array?
- ¿Qué valores de ArrayID y TaskID ves en los logs?
- ¿Qué `MaxRSS` observas en `sacct`?

---

### Ejercicio 2 — Job Array con lista de IDs (samples_id.txt)

En esta variante partimos de un fichero `samples_id.txt` ubicado en la raíz de `ANALYSIS/` que contiene, una por línea, los identificadores de muestra (por ejemplo, `sample01`, `sample02`, …). Cada tarea del array leerá el ID de muestra correspondiente y ejecutará FastQC sobre el par `R1/R2` de `00-reads/`.

Ejemplo de contenido de `samples_id.txt`:

```text
ERR2261314
ERR2261315
ERR2261318
virus1
virus2
```

A continuación, vamos a crear el script sbatch **`fastqc_array_samplesid.sbatch`** dentro de la carpeta `ANALYSIS/07-scripting-and-parallelization`

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_from_ids
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err

module load FastQC/0.11.9-Java-11

IDS_FILE="../samples_id.txt"
READS_DIR="../00-reads"

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")
R1="${READS_DIR}/${SAMPLE}_R1.fastq.gz"
R2="${READS_DIR}/${SAMPLE}_R2.fastq.gz"

RESULTS_ROOT="03-fastqc-array-results"
mkdir -p "$RESULTS_ROOT"
OUTDIR="${RESULTS_ROOT}/fastqc_from_ids_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_${SAMPLE}"
mkdir -p "$OUTDIR/logs"


fastqc -o "$OUTDIR" "$R1" "$R2"
echo "[INFO] Sample=${SAMPLE} R1=${R1} R2=${R2}"
```

Lanza el array ajustando el rango al número de líneas de `samples_id.txt`:

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization \
       --array=1-$(wc -l < /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/samples_id.txt) fastqc_array_samplesid.sbatch
```

Los resultados se guardan en `/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/03-fastqc-array-results/fastqc_from_ids_<ArrayJobID>_<ArrayTaskID>_<SampleName>/`

Mientras que los logs por tarea se guardan en `/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/03-fastqc-array-results/fastqc_from_ids_<ArrayJobID>_<ArrayTaskID>_<SampleName>/logs/`.

---

## 3. OpenMP vs MPI

### Descripción

En esta sesión vamos a profundizar en las estrategias de paralelización de tareas que podemos hacer en nuestro HPC. Según nuestras necesidades y, sobre todo, según las características del programa que vayamos a ejecutar en el sistema de colas, tendremos que configurar el script **sbatch** de acuerdo a si queremos:

- Ejecutar tareas en un **único nodo**, explotando sus **CPUs/hilos** y **memoria** → **OpenMP**.
- Ejecutar tareas en **varios nodos**, explotando las **CPUs** y la **memoria** de cada nodo → **MPI**.

- **OpenMP (memoria compartida)**: varios **hilos** dentro de **un proceso** en **un nodo** → la mayoría de bioinformática (fastp, Bowtie2, BWA, SPAdes, Minimap2…).
  *Traducción a Slurm:* `--cpus-per-task`, `--mem`, `--time` + pasar `--threads/$SLURM_CPUS_PER_TASK` al programa.

- **MPI (memoria distribuida)**: varios **procesos** (posible **multi-nodo**) que **se comunican** por mensajes → típico en **filogenia**, **simulaciones**, **modelos grandes**.
  *Traducción a Slurm:* `--nodes`, `--ntasks` (y/o `--ntasks-per-node`), `--time`, `--mem` + `mpirun -np $SLURM_NTASKS`.

La idea es: **probar OpenMP y MPI** con comandos reales, ver en `squeue/sacct` cómo se reparten los recursos y qué métricas mirar (**AllocCPUS**, **NodeList**, **Elapsed**, **MaxRSS**, **TotalCPU**).

### Notas importantes

- OpenMP en Slurm: pide **`--cpus-per-task`**, **`--mem`**, **`--time`** y pasa el nº de hilos al programa (suele ser `-t/--threads/-p/-w` o `OMP_NUM_THREADS`).

- MPI en Slurm: pide **`--nodes`**, **`--ntasks`** (y opcional **`--ntasks-per-node`**) y **lanza con `mpirun -np $SLURM_NTASKS`**.

- Comandos útiles:
  `squeue -u $USER -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"`,
  `scontrol show job <jobid> | egrep 'Nodes|NumCPUs|TRES|Reason|Start|RunTime'`,
  `sacct -j <jobid> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,NodeList,TotalCPU`.

---

### Ejercicio 1 — OpenMP en software de ensamblado (**SPAdes**)

Vamos a utilizar la estrategia OpenMP con el software de ensamblado [**SPAdes**](https://github.com/ablab/spades). Este software se utiliza para la **reconstrucción** de un genoma a partir de las lecturas procesadas. Es una etapa que demanda **bastantes más recursos**.

Guarda como **`spades_openmp.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=spades_openmp
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

module load SPAdes/3.15.2-GCC-10.2.0

mkdir -p 04-openmp-spades-results

R1=../00-reads/ERR2261314_R1.fastq.gz
R2=../00-reads/ERR2261314_R2.fastq.gz

spades.py -1 "$R1" -2 "$R2" -o 04-openmp-spades-results/spades_sample01 \
    --threads "$SLURM_CPUS_PER_TASK" \
    --mem $SLURM_MEM_PER_NODE
```

**Lanza y monitoriza**

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization spades_openmp.sbatch
squeue -u $USER -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
sacct -j <JOBID> -o JobID,AllocCPUS,State,Elapsed,MaxRSS,TotalCPU,NodeList
scontrol show jobid <JOBID> 
```

**PREGUNTAS**

- Explora la carpeta de resultados del análisis.
- ¿Cuántos nodos ha reservado tu tarea y por qué? ¿Podrías indicar el nombre del nodo?
- ¿Qué observas si aumentas `--cpus-per-task=32` y `--mem=64G`?

---

### Ejercicio 2 — MPI con **RAxML**

#### Objetivo

En este ejercicio vamos a trabajar con la estrategia **MPI**, que a diferencia de OpenMP reparte **procesos** entre varios nodos y los hace **comunicarse** entre sí mediante el paso de mensajes. Esto es clave cuando el problema **no cabe en la memoria de un único nodo** o cuando el software está pensado para aprovechar múltiples nodos de manera eficiente.

El software que vamos a usar es [**RAxML**](https://cme.h-its.org/exelixis/web/software/raxml/), una herramienta muy utilizada para **filogenia**. Construye árboles evolutivos a partir de alineamientos de secuencias. RAxML tiene versión compilada con soporte **MPI**, lo que nos permitirá repartir el cómputo entre varios procesos y, si procede, entre múltiples nodos del clúster.

> Cada proceso MPI es un ejecutable independiente que se **coordina** con el resto vía bibliotecas MPI. Slurm reserva los recursos; **`mpirun -np $SLURM_NTASKS`** se encarga de lanzar los procesos.

#### Pasos

1) Preparar el input (alineamiento PHYLIP)

Vamos a crear un alineamiento pequeño (12 taxones × 60 sitios) en formato PHYLIP secuencial, suficiente para testear el paralelismo:

```bash
srun --partition=short_idx --time=00:30:00 --cpus-per-task=2 --mem=4G --chdir /scratch/hpc_course/*_HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization --pty bash -l
mkdir -p data
cat > data/datos.phy << 'EOF'
12 60
Taxon_0001  ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT
Taxon_0002  TGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCA
Taxon_0003  AAAAAAAAAAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTT
Taxon_0004  ATATATATATATATATATATATATATATATATATATATATATATATATATATATATATAT
Taxon_0005  CGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCG
Taxon_0006  AGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCT
Taxon_0007  AACCAACCAACCAACCAACCAACCAACCAACCAACCAACCAACCAACCAACCAACCAACC
Taxon_0008  GGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTTGGTT
Taxon_0009  ACACACACACACACACACACACACACACACACACACACACACACACACACACACACACAC
Taxon_0010  GAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGAGA
Taxon_0011  CTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCTCT
Taxon_0012  TTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAA
EOF
exit
```

Explicación del formato PHYLIP

- 1ª línea: Ntaxa Nsitios (aquí 12 60).
- Luego, una línea por taxón: nombre (≤10 chars), un espacio y la secuencia (todas del mismo largo).

2) Crea el script Sbatch que ejecutará Ramxlm

Guarda como **`raxml_mpi.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=raxml_mpi
#SBATCH --partition=short_idx
#SBATCH --nodes=2                 # <-- nº de nodos
#SBATCH --ntasks=8                # total procesos MPI
#SBATCH --ntasks-per-node=4       # <-- nº procesos MPI por nodo
#SBATCH --mem-per-cpu=12G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

module load RAxML/8.2.12-gompi-2020a-hybrid-avx2  # el módulo puede traer varios binarios

RUNNAME="ML_bootstrap"
mkdir -p 05-raxml_mpi-results
RESULTS_DIR="/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization/05-raxml_mpi-results/raxml_${SLURM_JOB_ID}"
mkdir -p "$RESULTS_DIR"

mpirun -np "$SLURM_NTASKS" raxmlHPC \
  -s data/datos.phy \
  -m GTRGAMMA \
  -p 12345 \
  -# 20 \
  -n "$RUNNAME" \
  -w "$RESULTS_DIR"
```

> Se han definido 8 procesos MPI (`--ntasks=8`). Con `--nodes=2` y `--ntasks-per-node=4`, Slurm colocará 4 procesos en cada nodo. Los resultados se guardan **ordenados** en `05-raxml_mpi-results/raxml_<JobID>`.

**Parámetros clave de RAxML**
`-s` (alineamiento PHYLIP), `-m` (modelo, p.ej. GTRGAMMA), `-p` (semilla), `-#` (nº de réplicas/árboles), `-n` (prefijo de salida), `-w` (directorio de trabajo/salida).

Lanza y monitoriza los trabajos que se ejecutan.

```bash
sbatch --chdir=/scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization raxml_mpi.sbatch
watch -n 2 "squeue -u $USER -o \"%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c\""
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,AllocCPUS,NodeList
```

**PREGUNTAS**

- Observa la columna **NodeList**.
- ¿Se han usado realmente **2 nodos**? ¿Cuántas **tareas (ntasks)** ves por nodo?
- Si cambias a `--nodes=1 --ntasks=4`, ¿qué cambia en `NodeList` y en **Elapsed**?

---

#### Consejos rápidos para interpretar resultados

- **OpenMP**: espera ver **`AllocCPUS`** igual a los hilos que pides, **`TotalCPU ≈ Elapsed × hilos`** (si el programa escala), y **`MaxRSS`** coherente con la memoria reservada.
- **MPI**: fíjate en **`NodeList`** y **`AllocCPUS`** (suma de procesos). El **Elapsed** depende del reparto de trabajo entre procesos y la comunicación entre nodos.
- Si algo tarda **más** al subir hilos o procesos: puede haber **cuellos de E/S**, **sincronización** entre procesos, **over-subscription** o **modelo de paralelización** del propio software que no escale en ese rango.

---

### Sincronización final

Cuando termines todos los ejercicios, devuelve los resultados a `/data`:

```bash
rsync -avh /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/07-scripting-and-parallelization \
          /data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/
```

### Mini-decisión “qué uso”

- **OpenMP**: “**mismo** proceso, **multi-hilo**, **un nodo**” → casi todo lo bio.
- **MPI**: “**muchos** procesos, **varios nodos**” → filogenia grande, simulaciones, matrices gigantes.
