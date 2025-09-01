# HandsOn: HPC Scripting and Parallelization SLURM

## 1. Envío de trabajos con `sbatch` (Slurm)

### Descripción

En esta práctica aprenderás a crear un script `sbatch` y a enviarlo al sistema de colas del HPC. Además, **monitorizarás** la ejecución con Slurm y diagnosticarás el resultado usando los ficheros de log (`slurm-<jobid>.out/.err`) y los comandos `squeue`, `scontrol` y `sacct`.
Partiremos de un **script base** que ejecuta **FastQC** sobre dos FASTQ pequeños y crearemos **3 variantes** para observar:

1. ejecución correcta,
2. fallo del comando por entrada inexistente,
3. trabajo atascado en **PD** por pedir **recursos imposibles**.

### Notas importantes

* **No** ejecutes trabajos pesados en el nodo de login. Usa siempre `sbatch` (o `srun`).
* Ajusta `--time`, `--cpus-per-task` y `--mem` a lo **mínimo razonable**.
* Los **JOBID** cambian en cada envío; **toma nota** del número que te devuelve `sbatch`.
* Si tu entorno no tiene FastQC o los FASTQ de prueba, pide al docente la ruta de datos del curso.
* Comandos clave: `sbatch`, `squeue`, `scontrol show job <jobid>`, `sacct -j <jobid> -o ...`, `less`, `tail -n +1`.

---

### Script base

Guarda como **`fastqc_demo.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_demo
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

# Carga dependencias
module load FastQC/0.11.9-Java-11

# Info útil para el log
echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

mkdir -p fastqc_results
fastqc data/sample_R1.fastq.gz data/sample_R2.fastq.gz -o fastqc_results

echo "[INFO] Finished at $(date)"
```

> Nota: los parámetros que introducimos en la cabecera con `#SBATCH` también los podemos pasar por CLI:

```bash
sbatch fastqc_demo.sbatch \
  --job-name=fastqc_demo \
  --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc \
  --partition=short_idx \
  --cpus-per-task=1 \
  --mem=4G \
  --time=00:05:00 \
  --output=slurm-%j.out \
  --error=slurm-%j.err
```

---

### Ejercicio 1 — Ejecución correcta

**Objetivo**
Ejecutar el script tal cual, comprobar el nodo, los logs y el estado final.

**Pasos**

1. Enviar el trabajo

```bash
sbatch fastqc_demo.sbatch
```

2. Monitorizar en cola

```bash
squeue --me
squeue -j <JOBID>
```

3. Ver detalles (nodo, recursos, razón si está en PD)

```bash
scontrol show job <JOBID> | grep 'JobName\|NumNodes\|NumCPUs\|TRES\|Nodes\|Reason\|Submit\|Start\|TimeLimit'
```

4. Al finalizar, revisar histórico y uso

```bash
sacct -j <JOBID> -o JobID,State,Elapsed,MaxRSS,TotalCPU,ExitCode
```

5. Leer logs

```bash
less slurm-<JOBID>.out
less slurm-<JOBID>.err
```

**PREGUNTA:**
¿En qué **nodo** se ejecutó el trabajo y cuánto **tiempo** tardó?
¿Qué **pico de RAM** muestra `MaxRSS` y qué **estado final** aparece en `sacct`?

> Estados típicos: **PD** (PENDING), **R** (RUNNING), **CG** (COMPLETING), **CD** (COMPLETED), **F** (FAILED), **TO** (TIMEOUT), **CA** (CANCELLED), **NF** (NODE\_FAIL).

---

### Ejercicio 2 — Fallo del comando (archivo inexistente)

**Objetivo**
Forzar un error de ejecución para explorar el `stderr` y el `ExitCode`.

En este caso modificamos el script, lo guardamos como **`fastqc_failcmd.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_fail
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

module load FastQC/0.11.9-Java-11

echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

mkdir -p fastqc_results
fastp data/sample_R1.fastq.gz data/sample_R2.fastq.gz -o fastqc_results   # <<<< comando incorrecto

echo "[INFO] Finished at $(date)"
```

Ejecuta y monitoriza:

```bash
sbatch fastqc_failcmd.sbatch
sacct -j <JOBID> -o JobID,State,Elapsed,ExitCode
tail slurm-<JOBID>.err
```

*Ejemplo de error esperado en `.err`:*

```
Failed to execute: command not found
```

**PREGUNTA:**
¿Qué **mensaje de error** aparece en `slurm-<jobid>.err` y qué **ExitCode** ves en `sacct`?
¿Qué **cambio mínimo** haría que el trabajo funcione?

---

### Ejercicio 3 — Pendiente por recursos imposibles (over-ask)

**Objetivo**
Ver qué pasa cuando pedimos más recursos de los que el nodo puede ofrecer. El trabajo se queda en **PD (Pending)**.

Script: **`fastqc_overask.sbatch`**

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_overask
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=2
#SBATCH --mem=530G                       # << imposible en este nodo
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

module load FastQC/0.11.9-Java-11

echo "[INFO] Node: $(hostname)"
echo "[INFO] Starting FastQC at $(date)"

mkdir -p fastqc_results
fastqc data/sample_R1.fastq.gz data/sample_R2.fastq.gz -o fastqc_results

echo "[INFO] Finished at $(date)"
```

Monitoriza:

```bash
sbatch fastqc_overask.sbatch
squeue -j <JOBID> -o "%.18i %.10P %.20j %.2t %.10M %.6D %R"
scontrol show job <JOBID> | egrep 'Reason|Req|MinCPUs|TRES|Nodes|Partition|QOS'
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

Usaremos archivos tipo `sample01.fastq.gz`, `sample02.fastq.gz`, … en `data/`.
Cada tarea del array procesará un par R1/R2.

Script: **`array_intro.sbatch`**

```bash
#!/bin/bash
#SBATCH --job-name=array_intro
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --array=1-9%3
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:05:00
#SBATCH --output=logs/intro_%A_%a.out
#SBATCH --error=logs/intro_%A_%a.err

module load FastQC/0.11.9-Java-11

mkdir -p logs results/intro
OUTDIR="results/intro"

fastqc -o "$OUTDIR" "data/sample0${SLURM_ARRAY_TASK_ID}_R1.fastq.gz" \
                 "data/sample0${SLURM_ARRAY_TASK_ID}_R2.fastq.gz"

echo "[INFO] JobID=${SLURM_ARRAY_JOBID}; Task=${SLURM_ARRAY_TASK_ID}; End=$(date)"
```

**PREGUNTAS**

* ¿Qué valores de ArrayID y TaskID ves en los logs?
* ¿Qué fichero procesa la tarea 7?
* ¿Cuántas tareas corren en paralelo (pista: `%3`)?
* ¿Qué `MaxRSS` observas en `sacct`?

---

### Ejercicio 2 — Job Array real (QC con lista)

Aquí los ficheros no tienen numeración clara → usamos una lista (`filelist`).

```bash
ls data/*R1.fastq.gz | sort > data/filelist_R1.txt
```

Script: **`fastqc_array.sbatch`**

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_array
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --array=1-10
#SBATCH --output=logs/array_%A_%a.out
#SBATCH --error=logs/array_%A_%a.err

module load FastQC/0.11.9-Java-11

INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" data/filelist_R1.txt)
OUTDIR="results/fastqc_array_${SLURM_ARRAY_JOB_ID}"
mkdir -p "$OUTDIR" logs

fastqc -o "$OUTDIR" "$INPUT"
echo "[INFO] Task ${SLURM_ARRAY_TASK_ID} End: $(date)"
```

**PREGUNTAS**

* ¿Qué JOBID y TaskID aparecen?
* ¿Puedes encontrar sus logs y resultados?
* ¿Qué `Elapsed` y `MaxRSS` muestra `sacct`?

**Tip**: automatiza el rango del array con:

```bash
sbatch --array=1-$(wc -l < data/filelist_R1.txt) fastqc_array.sbatch
```

---

## 3. OpenMP vs MPI

### Descripción

En esta sesión vamos a profundizar en las estrategias de paralelización de tareas que podemos hacer en nuestro HPC. Según nuestras necesidades y, sobre todo, según las características del programa que vayamos a ejecutar en el sistema de colas, tendremos que configurar el script **sbatch** de acuerdo a si queremos:

* Ejecutar tareas en un **único nodo**, explotando sus **CPUs/hilos** y **memoria** → **OpenMP**.
* Ejecutar tareas en **varios nodos**, explotando las **CPUs** y la **memoria** de cada nodo → **MPI**.

- **OpenMP (memoria compartida)**: varios **hilos** dentro de **un proceso** en **un nodo** → la mayoría de bioinformática (fastp, Bowtie2, BWA, SPAdes, Minimap2…).
  *Traducción a Slurm:* `--cpus-per-task`, `--mem`, `--time` + pasar `--threads/$SLURM_CPUS_PER_TASK` al programa.

- **MPI (memoria distribuida)**: varios **procesos** (posible **multi-nodo**) que **se comunican** por mensajes → típico en **filogenia**, **simulaciones**, **modelos grandes**.
  *Traducción a Slurm:* `--nodes`, `--ntasks` (y/o `--ntasks-per-node`), `--time`, `--mem` + `mpirun -np $SLURM_NTASKS`.

La idea es: **probar OpenMP y MPI** con comandos reales, ver en `squeue/sacct` cómo se reparten los recursos y qué métricas mirar (**AllocCPUS**, **NodeList**, **Elapsed**, **MaxRSS**, **TotalCPU**).

### Notas importantes

* OpenMP en Slurm: pide **`--cpus-per-task`**, **`--mem`**, **`--time`** y pasa el nº de hilos al programa (suele ser `-t/--threads/-p/-w` o `OMP_NUM_THREADS`).

* MPI en Slurm: pide **`--nodes`**, **`--ntasks`** (y opcional **`--ntasks-per-node`**) y **lanza con `mpirun -np $SLURM_NTASKS`**.

* Comandos útiles:
  `squeue --me`,
  `scontrol show job <jobid> | egrep 'Nodes|NumCPUs|TRES|Reason|Start|RunTime'`,
  `sacct -j <jobid> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,NodeList,TotalCPU`.

* ¿Cómo decidir entre uno y otro?:
  Si **cabe en un nodo** y el programa admite hilos/threads → **OpenMP**.
  Si **no cabe en la RAM** de un nodo o el programa escala a multi-nodo → **MPI**.

---

### Ejercicio 1 — OpenMP básico con **fastp** (multi-hilo/thread en un nodo)

#### Objetivo

Vamos a exprimir la estrategia **OpenMP**. Para ello utilizaremos un programa bioinformático que se encarga de eliminar las secuencias **adaptadoras** generadas durante el proceso de secuenciación (plataforma Illumina). Es decir, recorta estos adaptadores dejando la lectura de cada secuencia **limpia**. Es una etapa de pre-procesado de archivos FASTQ antes del análisis en sí. Para este caso usaremos el programa [**fastp**](https://github.com/OpenGene/fastp), que permite usar varios threads/hilos en un único nodo.

Como hemos mencionado anteriormente, para poder utilizar la estrategia **OpenMP** debemos configurar en nuestro script `sbatch` los parámetros de Slurm: **`--cpus-per-task`**, `--mem`, `--time`.

Veamos cómo construir el script. Se muestra **`fastp_openmp.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=fastp_omp
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=4           # <- nº hilos/threads OpenMP
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=logs/fastp_omp_%j.out
#SBATCH --error=logs/fastp_omp_%j.err

module load fastp/0.20.0-GCC-8.3.0
mkdir -p results/fastp logs

# Setup de variables
R1=data/sample01_R1.fastq.gz
R2=data/sample01_R2.fastq.gz
OUTR1=results/fastp/sample01.clean.R1.fastq.gz
OUTR2=results/fastp/sample01.clean.R2.fastq.gz

# Ejecutamos el comando
fastp -i "$R1" -I "$R2" -o "$OUTR1" -O "$OUTR2" \
    --thread="$SLURM_CPUS_PER_TASK" \
    --detect_adapter_for_pe
```

**Lanza y monitoriza**

```bash
sbatch fastp_openmp.sbatch
squeue --me
sacct -j <JOBID> -o JobID,AllocCPUS,State,Elapsed,MaxRSS,TotalCPU,NodeList
```

**PREGUNTAS**

* ¿Ves **AllocCPUS=4** en `sacct` y un **TotalCPU** acorde (aprox. `Elapsed × hilos` si paraleliza bien)?
* Cambia **`--cpus-per-task=1`** y relanza con otro nombre de reporte. ¿Qué cambia en **Elapsed**?
* Vuelve a lanzar la tarea usando `--cpus-per-task 12` y `--cpus-per-task 32` → compara **Elapsed**.

> Nota: algunos programas **no** aceleran por encima de cierto nº de hilos. Puede ser porque el propio software **limite** los threads efectivos en tu dataset, o por cuellos de botella de **E/S** (lectura/escritura).

---

### Ejercicio 2 — OpenMP en software de ensamblado (**SPAdes**)

Vamos a volver a utilizar la estrategia OpenMP, pero esta vez con el software de ensamblado [**SPAdes**](https://github.com/ablab/spades). Este software se utiliza para la **reconstrucción** de un genoma a partir de las lecturas procesadas. Es una etapa que demanda **bastantes más recursos** computacionales que fastp.

Guarda como **`spades_openmp.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=spades_omp
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=logs/spades_%j.out
#SBATCH --error=logs/spades_%j.err

module load SPAdes/3.15.2-GCC-10.2.0
R1=data/sample01_R1.fastq.gz
R2=data/sample01_R2.fastq.gz

spades.py -1 "$R1" -2 "$R2" -o results/spades_sample01 \
    --threads "$SLURM_CPUS_PER_TASK" \
    --mem 32
```

**PREGUNTAS**

* Explora la carpeta de resultados del análisis.
* ¿Qué observas si aumentas `--cpus-per-task=32` y `--mem=64G`?

---

### Ejercicio 3 — MPI con **RAxML**

#### Objetivo

En este ejercicio vamos a trabajar con la estrategia **MPI**, que a diferencia de OpenMP reparte **procesos** entre varios nodos y los hace **comunicarse** entre sí mediante el paso de mensajes. Esto es clave cuando el problema **no cabe en la memoria de un único nodo** o cuando el software está pensado para aprovechar múltiples nodos de manera eficiente.

El software que vamos a usar es [**RAxML**](https://cme.h-its.org/exelixis/web/software/raxml/), una herramienta muy utilizada para **filogenia**. Construye árboles evolutivos a partir de alineamientos de secuencias. RAxML tiene versión compilada con soporte **MPI**, lo que nos permitirá repartir el cómputo entre varios procesos y, si procede, entre múltiples nodos del clúster.

> Cada proceso MPI es un ejecutable independiente que se **coordina** con el resto vía bibliotecas MPI. Slurm reserva los recursos; **`mpirun -np $SLURM_NTASKS`** se encarga de lanzar los procesos.

#### Script de ejemplo

Guarda como **`raxml_mpi.sbatch`**:

```bash
#!/bin/bash
#SBATCH --job-name=raxml_mpi
#SBATCH --chdir=/scratch/bi/TESTS/daniel_vm/intro_to_hpc
#SBATCH --partition=short_idx
#SBATCH --nodes=2                 # <-- nº de nodos
#SBATCH --ntasks=8                # total procesos MPI
#SBATCH --ntasks-per-node=4       # <-- nº procesos MPI por nodo
#SBATCH --cpus-per-task=1         # (MPI puro: 1 CPU por proceso)
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=logs/raxml_%j.out
#SBATCH --error=logs/raxml_%j.err

module load RAxML/8.2.12-gompi-2020a-hybrid-avx2  # el módulo puede traer varios binarios

RUNNAME="ML_bootstrap"
RESULTS_DIR="$(pwd)/results/raxml_${SLURM_JOB_ID}"
mkdir -p "$RESULTS_DIR"

mpirun -np "$SLURM_NTASKS" raxmlHPC-MPI \
  -s data/datos.phy \
  -m GTRGAMMA \
  -p 12345 \
  -# 20 \
  -n "$RUNNAME" \
  -w "$RESULTS_DIR"
```

> Se han definido 8 procesos MPI (`--ntasks=8`). Con `--nodes=2` y `--ntasks-per-node=4`, Slurm colocará 4 procesos en cada nodo. Los resultados se guardan **ordenados** en `results/raxml_<JobID>`.

**Parámetros clave de RAxML**
`-s` (alineamiento PHYLIP), `-m` (modelo, p.ej. GTRGAMMA), `-p` (semilla), `-#` (nº de réplicas/árboles), `-n` (prefijo de salida), `-w` (directorio de trabajo/salida).

Lanza y monitoriza los trabajos que se ejecutan. 

```bash
sbatch raxml_mpi.sbatch
watch squeue --me
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,AllocCPUS,NodeList
```

**PREGUNTAS**

* Observa la columna **NodeList**.
* ¿Se han usado realmente **2 nodos**? ¿Cuántas **tareas (ntasks)** ves por nodo?
* Si cambias a `--nodes=1 --ntasks=4`, ¿qué cambia en `NodeList` y en **Elapsed**?
* ¿Qué ocurre si ejecutas el binario **sin** `mpirun` aunque hayas pedido `--ntasks` en Slurm?

---

#### Consejos rápidos para interpretar resultados

* **OpenMP**: espera ver **`AllocCPUS`** igual a los hilos que pides, **`TotalCPU ≈ Elapsed × hilos`** (si el programa escala), y **`MaxRSS`** coherente con la memoria reservada.
* **MPI**: fíjate en **`NodeList`** y **`AllocCPUS`** (suma de procesos). El **Elapsed** depende del reparto de trabajo entre procesos y la comunicación entre nodos.
* Si algo tarda **más** al subir hilos o procesos: puede haber **cuellos de E/S**, **sincronización** entre procesos, **over-subscription** o **modelo de paralelización** del propio software que no escale en ese rango.


---

### Errores típicos y cómo detectarlos

**OpenMP**

* **Olvidar pasar hilos** al programa (p. ej. `-w/--threads/-p`).
  *Síntoma:* `AllocCPUS>1` pero **`AveCPU`** baja y no hay aceleración.
  *Solución:* usa `"$SLURM_CPUS_PER_TASK"` en el flag correcto del programa.
* **RAM insuficiente** al subir hilos.
  *Síntoma:* `.err` con “Killed”/OOM; `State=OUT_OF_MEM` o `FAILED`.
  *Solución:* aumenta `--mem`, o baja hilos, o revisa parámetros del programa.

**MPI**

* **Sin `mpirun`** (o ejecutable no MPI).
  *Síntoma:* 1 proceso efectivo; mensajes de error/advertencia; uso de CPU bajo.
  *Solución:* `mpirun -np $SLURM_NTASKS <binario-MPI>`.
* **Demasiadas tareas por nodo**.
  *Síntoma:* `PD (Resources)` largo o `Reason=ReqNodeNotAvail`, o contención.
  *Solución:* ajusta `--ntasks-per-node` acorde al hardware/límites de la partición.

---

### Mini-decisión “qué uso”

* **OpenMP**: “**mismo** proceso, **multi-hilo**, **un nodo**” → casi todo lo bio.
* **MPI**: “**muchos** procesos, **varios nodos**” → filogenia grande, simulaciones, matrices gigantes.
