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

Define las rutas una vez por terminal. El nombre de carpeta corresponde a esta edición del curso:

```bash
export COURSE_NAME="20261015_HPC-COURSE_${USER}"
export DATA_DIR="/data/courses/hpc_course/${COURSE_NAME}"
export SCRATCH_DIR="/scratch/hpc_course/${COURSE_NAME}"
export ANALYSIS_DIR="${DATA_DIR}/ANALYSIS"

ls -ld "$DATA_DIR" "$DATA_DIR/RAW" "$ANALYSIS_DIR"
```

Comprueba también los recursos reales antes del ejercicio de memoria y los módulos antes de comenzar. Si alguno de estos módulos no aparece, avisa al docente: las versiones de los scripts son parte del material que se debe validar en Portutatis.

```bash
sinfo -N -h -o '%N  %P  %c CPUs  %m MB'
module spider FastQC
module spider SPAdes
module spider RAxML
```

## 1. Preparación de datos y scripts

### 1.1 Crear la zona de trabajo en `/data`

Los FASTQ de esta edición ya están en `RAW/`. Vamos a generar una lista de muestras y enlaces simbólicos homogéneos en `ANALYSIS/00-reads`. Así los scripts no dependen de si los datos originales se llaman `_1/_2` o `_R1/_R2`.

```bash
mkdir -p "$ANALYSIS_DIR/07-scripting-and-parallelization/logs"
mkdir -p "$ANALYSIS_DIR/00-reads"
cd "$ANALYSIS_DIR"

{
  find ../RAW -maxdepth 1 -type f -name '*_1.fastq.gz' -printf '%f\n' | sed 's/_1\.fastq\.gz$//'
  find ../RAW -maxdepth 1 -type f -name '*_R1.fastq.gz' -printf '%f\n' | sed 's/_R1\.fastq\.gz$//'
} | sort -u > samples_id.txt

cat samples_id.txt
```

Ahora crea los enlaces. El bucle detecta los dos esquemas de nombres presentes en `RAW/`.

```bash
cd "$ANALYSIS_DIR/00-reads"
while read -r sample; do
  if [[ -f "../../RAW/${sample}_1.fastq.gz" ]]; then
    ln -sfn "../../RAW/${sample}_1.fastq.gz" "${sample}_R1.fastq.gz"
    ln -sfn "../../RAW/${sample}_2.fastq.gz" "${sample}_R2.fastq.gz"
  else
    ln -sfn "../../RAW/${sample}_R1.fastq.gz" "${sample}_R1.fastq.gz"
    ln -sfn "../../RAW/${sample}_R2.fastq.gz" "${sample}_R2.fastq.gz"
  fi
done < ../samples_id.txt

ls -l
```

> Debes ver cinco muestras: `ERR2261314`, `ERR2261315`, `ERR2261318`, `virus1` y `virus2`. Comprueba que los enlaces no están rotos con `find -L . -type l` (no debe mostrar nada).

### 1.2 Descargar los scripts y copiar a `/scratch`

Sitúate en el directorio de la práctica y descarga los esqueletos. Si GitHub no estuviese accesible desde el clúster, el docente facilitará esos mismos ficheros por otra vía.

```bash
cd "$ANALYSIS_DIR/07-scripting-and-parallelization"
BASE_URL='https://raw.githubusercontent.com/BU-ISCIII/introduction_to_hpc/main/exercises/07_handson_scripting_and_parallelization'

for file in fastqc_demo.sbatch fastqc_failcmd.sbatch fastqc_overask.sbatch \
            array_demo.sbatch fastqc_array_samplesid.sbatch \
            spades_openmp.sbatch raxml_mpi.sbatch; do
  wget -O "$file" "$BASE_URL/$file"
done
```

Sincroniza el directorio completo al espacio temporal. Se hace con `srun` porque `/scratch` no admite escritura directa desde el nodo de acceso.

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 \
  rsync -avh "$DATA_DIR/" "$SCRATCH_DIR/"

cd "$SCRATCH_DIR/ANALYSIS/07-scripting-and-parallelization"
pwd
```

## 2. Un trabajo correcto y dos diagnósticos

Los tres scripts usan rutas relativas desde `07-scripting-and-parallelization`; por ello se envían con `--chdir` y no contienen rutas absolutas con comodines. Todos comienzan con `set -euo pipefail`, de modo que un comando que falla hace fallar el trabajo y Slurm registra un código de salida distinto de cero.

### Ejercicio 1 — FastQC correcto

Revisa primero el script y envíalo:

```bash
less fastqc_demo.sbatch
sbatch --chdir="$PWD" fastqc_demo.sbatch
```

Mientras está activo y al terminar, consulta:

```bash
squeue --me
scontrol show job <JOBID> | grep -E 'JobName|Partition|NumCPUs|TRES|NodeList|Reason|TimeLimit'
sacct -j <JOBID> -o JobID,JobName,State,Elapsed,MaxRSS,AllocCPUS,TotalCPU,ExitCode
less "logs/fastqc_demo-<JOBID>.out"
less "logs/fastqc_demo-<JOBID>.err"
ls -lh 01-fastqc-demo-results/
```

Preguntas:

1. ¿En qué partición y nodo se ejecutó?
2. ¿Qué estado y `ExitCode` tiene el trabajo?
3. ¿Cuánto tardó y qué `MaxRSS` alcanzó?

### Ejercicio 2 — Fallo por una entrada inexistente

`fastqc_failcmd.sbatch` referencia deliberadamente `does_not_exist_R1.fastq.gz`. No cambies el script antes de enviarlo.

```bash
sbatch --chdir="$PWD" fastqc_failcmd.sbatch
sacct -j <JOBID> -o JobID,State,Elapsed,ExitCode
tail -n 20 "logs/fastqc_fail-<JOBID>.err"
```

Preguntas:

1. ¿Qué fichero indica FastQC que no puede leer?
2. ¿Qué `ExitCode` aparece? ¿Por qué ahora no termina como `COMPLETED`?
3. ¿Cuál sería el cambio mínimo para corregirlo?

### Ejercicio 3 — Solicitud de memoria imposible

El script `fastqc_overask.sbatch` pide `1T` de RAM. Antes de enviarlo, confirma con el `sinfo` inicial que ningún nodo tiene esa cantidad. Si existiera un nodo con 1 TB o más, cambia `--mem` por un valor superior al máximo observado.

```bash
sbatch --chdir="$PWD" fastqc_overask.sbatch
squeue --me
scontrol show job <JOBID> | grep -E 'JobState|Reason|ReqTRES|MinMemoryNode|Partition'
```

El trabajo debe permanecer en `PD`; no lo dejes en cola al acabar el ejercicio:

```bash
scancel <JOBID>
```

Pregunta: ¿qué valor de `Reason` muestra Slurm y qué recurso debes reducir para que el trabajo pueda empezar?

## 3. Job arrays

Un *job array* envía muchas tareas con el mismo script. Cada tarea tiene el mismo `SLURM_ARRAY_JOB_ID` y un `SLURM_ARRAY_TASK_ID` distinto. El patrón `%A_%a` en los logs evita que se mezclen sus salidas.

### Ejercicio 1 — Dos muestras con índices consecutivos

`array_demo.sbatch` procesa `virus1` y `virus2`; el rango `1-2` ya está definido en el propio script.

```bash
sbatch --chdir="$PWD" array_demo.sbatch
squeue --me
sacct -j <ARRAY_JOBID> -o JobID,JobName%20,State,Elapsed,MaxRSS,ExitCode
find 02-array-demo-results -maxdepth 2 -type f -name '*.html'
```

Preguntas:

1. ¿Qué `ArrayJobID` comparten las tareas y qué `TaskID` tiene cada una?
2. ¿Qué archivos de log corresponden a cada tarea?
3. ¿Cuál fue el `MaxRSS` de cada tarea?

### Ejercicio 2 — Array a partir de `samples_id.txt`

Este array obtiene la muestra de la línea que corresponde a su índice. El rango se calcula desde el fichero para que no haya que modificar el script cuando cambie la lista. Limita a dos tareas simultáneas: es una buena práctica cuando el conjunto puede crecer.

```bash
N_SAMPLES=$(wc -l < "$SCRATCH_DIR/ANALYSIS/samples_id.txt")
sbatch --chdir="$PWD" --array="1-${N_SAMPLES}%2" fastqc_array_samplesid.sbatch

sacct -j <ARRAY_JOBID> -o JobID,State,Elapsed,MaxRSS,ExitCode
find 03-fastqc-array-results -maxdepth 2 -type f -name '*.html'
```

El script valida que exista un identificador y los dos FASTQ antes de ejecutar FastQC. Los logs de Slurm están en `logs/`; los resultados de cada tarea quedan en un directorio que incluye `ArrayJobID`, `TaskID` y nombre de muestra.

Preguntas:

1. ¿Por qué el rango se calcula con `wc -l` y no se escribe a mano?
2. ¿Qué efecto tiene `%2`?
3. ¿Cómo reenviarías únicamente la tarea 3 si hubiese fallado?

## 4. OpenMP frente a MPI

| Modelo | Slurm | Idea |
| --- | --- | --- |
| OpenMP | `--cpus-per-task` | Un proceso con varios hilos en un nodo. |
| MPI | `--nodes`, `--ntasks`, `--ntasks-per-node` | Varios procesos que pueden repartirse entre nodos. |

Pedir recursos no paraleliza un programa por sí solo: hay que comunicar el número de hilos o procesos al ejecutable.

### Ejercicio 1 — OpenMP con SPAdes

El script solicita 16 CPU para un único proceso y pasa ese valor a `spades.py` mediante `--threads "$SLURM_CPUS_PER_TASK"`.

```bash
sbatch --chdir="$PWD" spades_openmp.sbatch
squeue --me
sacct -j <JOBID> -o JobID,State,Elapsed,MaxRSS,AllocCPUS,TotalCPU,NodeList,ExitCode
```

Cuando termine, revisa `04-openmp-spades-results/spades_sample01/`. Después, compara el resultado de `AllocCPUS`, `TotalCPU` y `MaxRSS` con los valores solicitados.

Preguntas:

1. ¿Cuántos nodos reservó y por qué?
2. ¿Qué parámetro de SPAdes recibe el número de CPU que concede Slurm?
3. ¿Qué inconveniente tendría pedir 32 CPU y 64 GB si el análisis no los utiliza?

### Ejercicio 2 — MPI con RAxML

El ejemplo es deliberadamente pequeño: su propósito es observar la distribución de procesos, no medir rendimiento. Crea el alineamiento de prueba en el directorio de la práctica (esta escritura pequeña no es un cálculo):

```bash
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
```

`raxml_mpi.sbatch` solicita dos nodos con cuatro tareas MPI en cada uno. Busca explícitamente un binario MPI (`raxmlHPC-MPI-AVX2`, `raxmlHPC-MPI-AVX` o `raxmlHPC-MPI`) y falla de forma clara si el módulo no proporciona ninguno; nunca sustituye silenciosamente ese binario por el serial `raxmlHPC`.

```bash
sbatch --chdir="$PWD" raxml_mpi.sbatch
squeue --me
sacct -j <JOBID> -o JobID,JobName%20,State,Elapsed,AllocCPUS,NodeList,ExitCode
```

Preguntas:

1. ¿Aparecen realmente dos nodos en `NodeList`?
2. ¿Cuántos procesos MPI hay por nodo?
3. Si cambias a `--nodes=1 --ntasks=4`, ¿qué cambia en `NodeList`? ¿Por qué este input no sirve para comparar tiempos de escalado?

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
