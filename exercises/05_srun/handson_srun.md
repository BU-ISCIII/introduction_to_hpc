# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 4: Uso de slurm para gestión de trabajos en el clúster

- [Curso Práctico de Iniciación al uso del Entorno de Alta Computación](#curso-práctico-de-iniciación-al-uso-del-entorno-de-alta-computación)
  - [Práctica 4: Uso de slurm para gestión de trabajos en el clúster](#práctica-4-uso-de-slurm-para-gestión-de-trabajos-en-el-clúster)
    - [Objetivo](#objetivo)
    - [Prerrequisitos](#prerrequisitos)
    - [1. Reservar recursos mínimos con srun desde /home](#1-reservar-recursos-mínimos-con-srun-desde-home)
    - [2. Probar opciones avanzadas de srun](#2-probar-opciones-avanzadas-de-srun)
    - [3. Enviar trabajos con srun en segundo plano y comprobar con squeue](#3-enviar-trabajos-con-srun-en-segundo-plano-y-comprobar-con-squeue)
    - [4. Gestionar logs y nombre de job](#4-gestionar-logs-y-nombre-de-job)
    - [5. Abrir una sesión interactiva con srun](#5-abrir-una-sesión-interactiva-con-srun)
    - [6. Monitorizar trabajos con squeue y revisar finalizados con sacct](#6-monitorizar-trabajos-con-squeue-y-revisar-finalizados-con-sacct)
    - [7. Cancelar trabajos con scancel](#7-cancelar-trabajos-con-scancel)
    - [8. Copiar datos entre /data y /scratch usando srun con rsync](#8-copiar-datos-entre-data-y-scratch-usando-srun-con-rsync)
    - [9. Ejecutar fastqc sobre datos reales en /scratch](#9-ejecutar-fastqc-sobre-datos-reales-en-scratch)
    - [10. Copiar resultados a /data y limpiar /scratch](#10-copiar-resultados-a-data-y-limpiar-scratch)
    - [11. Solución de problemas](#11-solución-de-problemas)

### Objetivo

- Comprender cómo reservar recursos con srun
- Diferenciar ejecuciones en lote no interactivas e interactivas
- Monitorizar, cancelar y auditar ejecuciones
- Usar áreas /data y /scratch de forma correcta

### Prerrequisitos

- Tener acceso al clúster y autenticación por ssh configurada
- Conocer comandos básicos de Linux

### 1. Reservar recursos mínimos con srun desde /home

1. Primero vamos a comprobar qué particiones hay en el clúster y cuáles son sus características. Acuérdate de entrar al HPC primero.

```bash
sinfo -o '%P %l %c %m %G'
```

Output:

| Partition   | Timelimit   | Cpus | Memory   | Gres                  |
|-------------|-------------|------|----------|-----------------------|
| long_idx    | 10-00:00:00 | 32   | 385000+  | local_scratch:880G    |
| middle_idx  | 2-00:00:00  | 32   | 385000+  | local_scratch:880G    |
| short_idx*  | 12:00:00    | 32   | 385000+  | local_scratch:880G    |
| tmp_idx     | infinite    | 32   | 385000+  | local_scratch:880G    |

- ¿Qué memoria máxima tenemos por nodo en gb? ¿Cuántas cpus máximas puedo pedir por nodo?

2. Vamos a empezar ejecutando srun specificando CPU, memoria y tiempo.

```bash
cd ~
# 1 cpu, 1gb memoria ram, 5 minutos tiempo máximo
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:00:60 bash -c "hostname; sleep 60"
# Comprobamos con squeue en otra terminal
squeue -u "$USER" -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
# si no usamos -u "$USER" veremos el trabajo de otros usuarios
squeue -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
```

3. Repetir pidiendo dos threads y dos gigas.

```bash
srun --partition=short_idx --cpus-per-task=2 --mem=2G --time=00:00:60 bash -c "hostname; sleep 60"
# Comprobamos con squeue en otra terminal. Esta vez filtrando solo por tu usuario
squeue -u "$USER" -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
```

- Comprobamos que no se ejecuta en el nodo de acceso portutatis, sino que se ejecuta en uno de los nodos de cómputo. El hostname va a devolver el nombre del nodo donde se está ejecutando, cada uno tendréis uno diferente. ¿Cuál es el tuyo?

4. ¿Qué ocurre si solicita menos tiempo del necesario?

```bash
srun --partition=short_idx --cpus-per-task=2 --mem=2G --time=00:00:60 bash -c "hostname; sleep 100"
# espera un minuto
```

Output:

```bash
hostname

slurmstepd-ideafix03: error: ***STEP 4833283.0 ON ideafix03 CANCELLED AT 2025-09-04T16:17:42 DUE TO TIME LIMIT***
srun: Job step aborted: Waiting up to 32 seconds for job step to finish.
srun: error: ideafix03: task 0: Terminated
```

5. ¿Qué mensaje aparece si excede la memoria solicitada?

```bash
srun --partition=short_idx --time=00:05:00 --mem=300M bash -lc 'python3 -c "import time; b=[]; [ (b.append(bytearray(5*1024*1024)), time.sleep(0.1)) for _ in range(200) ]"'
```

Output:

```bash
slurmstepd-ideafix03: error: Detected 1 oom_kill event in StepId=4833316.0. Some of the step tasks have been OOM Killed.
srun: error: ideafix03: task 0: Out Of Memory
```

- Revisemos la información del job con `sacct`

```bash
sacct -j SLURM_JOB_ID --format=JobID,State,MaxRSS,ReqMem
# Debido a que el trabajo es muy corto no da tiempo al accounting a recoger la información por lo que no lo veremos aquí.
# en un trabajo más largo sería donde se vería que MaxRSS llega al ReqMem
```

### 2. Probar opciones avanzadas de srun

En esta parte de la práctica vamos a usar opciones más avanzadas de srun para solicitar varios nodos, varias tareas y recursos de GPU cuando existan.

1. Primero podemos comprobar la estructura de los cpus en los nodos de cómputo:

```bash
srun --partition=short_idx bash -c "lscpu | grep -E 'CPU\(|Thread|Core'"
```

Output:

```bash
CPU(s):              32
On-line CPU(s) list: 0-31
Thread(s) per core:  1
Core(s) per socket:  16
NUMA node0 CPU(s):   0-15
NUMA node1 CPU(s):   16-31
```

1. Ejecutar múltiples tareas MPI simuladas.

```bash
srun --partition=short_idx --nodes=1 --ntasks=4 --time=00:10:00 bash -c 'echo Tarea $SLURM_PROCID en $(hostname)'
```

2. Probar dos nodos con dos tareas por nodo.

```bash
srun --partition=middle_idx --nodes=2 --ntasks-per-node=1 --time=00:10:00 bash -c 'echo Nodo $(hostname) con tarea $SLURM_PROCID'
```

1. Solicitar una GPU si la partición gpus está disponible.

```bash
srun --partition=gpus --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=00:30:00 nvidia-smi
```

> Nota: por motivos técnicos los nodos gpu no están disponibles en este momento por lo que este comando no funcionará.

### 3. Enviar trabajos con srun en segundo plano y comprobar con squeue

Vamos a probar a dejar procesos ejecutándose y seguir trabajando en la shell.

1. Enviar una tarea en segundo plano que tarde unos minutos.

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:05:00 bash -c 'sleep 180 && date' &
```

2. Obtener su identificador de trabajo.

```bash
jobs
# si es necesario traiga el id con ps o grep srun
```

3. Consultar su estado en la cola.

```bash
squeue -u $USER -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
```

### 4. Gestionar logs y nombre de job

A continuación vamos a aprender a registrar salida a ficheros con el JobID y nombre del trabajo, y a cambiar el directorio de trabajo.

1. Preparar un directorio para pruebas y logs.

```bash
mkdir -p "$HOME/srun_demo/logs"
```

2. Lanzar un trabajo que use `--job-name`, `--chdir` y `--output` con `%x` (nombre) y `%j` (JobID).

```bash
srun \
  --partition=short_idx \
  --cpus-per-task=1 \
  --mem=200M \
  --time=00:02:00 \
  --job-name=demo_log \
  --chdir="$HOME/srun_demo" \
  --output="$HOME/srun_demo/logs/%x_%j.out" \
  bash -lc '
    echo "Job: $SLURM_JOB_NAME (ID: $SLURM_JOB_ID)";
    echo "Host: $(hostname)";
    echo "PWD : $(pwd)";
    echo "Inicio: $(date)";
    sleep 10;
    echo "Fin   : $(date)";
  '
```

3. Verificar que el log existe y contiene la información esperada.

```bash
ls -lh "$HOME/srun_demo/logs"
cat "$HOME/srun_demo/logs"/demo_log_*.out
```

4. Borrar la carpeta con los logs demo.

```bash
rm -r "$HOME/srun_demo/logs"
```

**Notas**

- `--output` acepta patrones de formato: `%j` (JobID), `%x` (JobName), `%N` (nodo), etc.
- La ruta del `--output` debe existir; cree el directorio antes con `mkdir -p`.
- `--chdir` establece el directorio de trabajo para el proceso lanzado.
- Estas opciones son combinables con las usadas en la práctica (`--cpus-per-task`, `--mem`, `--time`, `--nodes`, `--ntasks`, etc.).

### 5. Abrir una sesión interactiva con srun

En esta parte de la práctica vamos a obtener una shell en un nodo de cómputo para pruebas.

1. Solicitar una shell en un nodo de cómputo.

```bash
srun --partition=short_idx --cpus-per-task=2 --mem=2G --time=00:30:00 --pty bash
# comprobar el nodo actual
hostname
# salir de la sesión
exit
```

- El hostname debe ser un nodo de cómputo
- Es recomendable limitar el tiempo y los recursos al mínimo necesario

### 6. Monitorizar trabajos con squeue y revisar finalizados con sacct

1. Obtener un resumen de los trabajos en la cola. Esto lo hemos ido haciendo a lo largo de la práctica.

```bash
squeue -o "%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c"
```

Leyenda del formato:

- %i: JobID (identificador del trabajo)
- %j: JobName (nombre del trabajo)
- %t: State (estado abreviado)
- %u: User (usuario)
- %q: QoS (calidad de servicio, si aplica)
- %P: Partition (partición)
- %Q: Priority (prioridad en cola)
- %D: Nodes (número de nodos asignados)
- %l: TimeLimit (tiempo límite solicitado)
- %L: TimeLeft (tiempo restante)
- %R: Reason/NodeList (motivo si PENDING o lista de nodos si RUNNING)
- %C: CPUs (total de CPUs asignadas al job/step)
- %c: CPUs per task (cpus por tarea, si aplica)

Nota sobre los números: en expresiones como `%8i` o `%22j`, el número indica el ancho de columna (margen/padding) para una salida tabulada más legible. No forma parte del campo en sí.

1. Obtener un resumen de los trabajos terminados.

```bash
sacct -u "$USER" --starttime=today --format=JobID,JobName%20,Partition,AllocCPUS,Elapsed,State,MaxRSS,ExitCode
```

### 7. Cancelar trabajos con scancel

Vamos a lanzar varios trabajos de prueba, cancelar uno específico y luego cancelar el resto, verificando con squeue en cada paso.

1. Lanzar varios trabajos dummy en segundo plano (duermen 180 s) con nombre identificable.

```bash
for i in 1 2 3; do \
  srun --partition=short_idx \
       --cpus-per-task=1 \
       --mem=200M \
       --time=00:05:00 \
       --job-name=demo_cancel_$i \
       bash -lc 'sleep 180' &
done
```

2. Verificar que están en cola/ejecución.

```bash
squeue -u "$USER" -o "%8i %22j %4t %10u %20P %11l %11L %50R"
```

3. Cancelar un trabajo concreto por JobID.

```bash
# Elige un JobID de la salida anterior, p.ej. 1234567
scancel JOBID
# Verifica que ese solo desaparece
squeue -u "$USER" -o "%8i %22j %4t %10u %20P %11l %11L %50R"
```

4. Cancelar todos los trabajos restantes del usuario (o solo por nombre).

```bash
# Opción A: cancelar todo lo tuyo (incluye otros trabajos si los hubiera)
scancel -u "$USER"

# Opción B: solo los que coincidan por nombre (p.ej. demo_cancel), se puede cancelar por nombre además de por jobid
scancel -n demo_cancel_1
scancel -n demo_cancel_2
scancel -n demo_cancel_3
```

5. Comprobar que no quedan trabajos demo.

```bash
squeue -u "$USER" -o "%8i %22j %4t %10u %20P %11l %11L %50R" | grep demo_cancel || echo "Sin trabajos demo_cancel"
```

### 8. Copiar datos entre /data y /scratch usando srun con rsync

Ahora que sabemos usar srun con su parametrización, vamos a aprender a usar los filesystem de /data y /scratch. Específicamente vamos a copiar de un recurso a otro usando un nodo de cómputo evitando cargar el nodo de acceso.

1. Preparamos las carpetas que vamos a necesitar para el análisis real partiendo de la carpeta que creamos en la práctica anterior.

```bash
# Nos movemos a la carpeta en nuestra carpeta compartida dentro del hpc
cd /data/courses/hpc_course/*HPC-COURSE_${USER}/ANALYSIS
# Creamos las carpetas que vamos a necesitar
mkdir -p 00-reads 01-fastqc/logs
# vamos a crear un archivo con los nombres de los muestras
ls ../RAW/*.fastq.gz | cut -d "/" -f 3 | cut -d "_" -f 1 | sort -u > samples_id.txt
# Por último creamos enlaces simbólicos para cada muestra de forma homogéne en 00-reads para tenerlo a mano
cd 00-reads
cat ../samples_id.txt | xargs -I % echo "ln -s ../../RAW/%_*1*.fastq.gz %_R1.fastq.gz" | bash
cat ../samples_id.txt | xargs -I % echo "ln -s ../../RAW/%_*2*.fastq.gz %_R2.fastq.gz" | bash
```

1. Copiamos los datos a scratch con un rsync lanzado en un nodo de cómputo.

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 rsync -avh /data/courses/hpc_course/*HPC-COURSE*${USER}* /scratch/hpc_course
```

### 9. Ejecutar fastqc sobre datos reales en /scratch

Por último vamos a efectuar un ciclo de trabajo completo en scratch.

1. Cargar el módulo o activar el entorno.

```bash
cd /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS/
# Modules y la gestión de software se desarrollará en la siguiente práctica
module load FastQC/0.11.9-Java-11
```

2. Ejecutar fastqc con srun guardando en RESULTS.

```bash
srun --partition=short_idx --cpus-per-task=2 --mem=4G --time=00:15:00 --chdir /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS fastqc -t 2 -o 01-fastqc 00-reads/*.fastq.gz*
```

3. Revisar salida.

```bash
ls 01-fastqc
```

- Deben generarse ficheros HTML y zip por cada fastq

3. Para hacer este análisis hemos utilizado un único comando srun, es decir hemos analizado todas las muestras utilizando un único job, y se ha analizado una detrás de otra. Ahora vamos a lanzarlas todas a la vez en paralelo.

```bash
cat samples_id.txt | xargs -I @@ echo "srun --chdir /scratch/hpc_course/*HPC-COURSE_${USER}/ANALYSIS --partition=short_idx --job-name fastqc_@@ --cpus-per-task=2 --mem=4G --time=00:15:00 fastqc -t 2 -o 01-fastqc 00-reads/@@_R1.fastq.gz 00-reads/@@_R2.fastq.gz &" | bash
```

Lo puedes comprobar en otra terminal lanzando:

```bash
watch squeue -u $USER -o \"%8i %22j %4t %10u %20q %20P %10Q %5D %11l %11L %50R %10C %c\"
```

### 10. Copiar resultados a /data y limpiar /scratch

Una vez terminado el procesamiento tenemos que devolver resultados a almacenamiento persistente y liberar scratch.

1. Copiar resultados a un directorio de proyecto en /data.

```bash
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 rsync -avh /scratch/hpc_course/*HPC-COURSE_${USER} /data/courses/hpc_course/
```

2. Limpiar temporal de forma segura.

```bash
cd /data/courses/hpc_course/*HPC-COURSE_${USER}
srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:10:00 rm -rf /scratch/hpc_course/*HPC-COURSE_${USER}
```

- Confirmar que el espacio en /scratch disminuye y que los resultados están en /data

### 11. Solución de problemas

- Mensaje de denegación en nodo de acceso
- Trabajo en estado pendiente prolongado: revise la partición, recursos, límites de proyecto y prioridad
- Error por memoria insuficiente: aumente --mem y revise MaxRSS en sacct
- No hay GPUs disponibles: use la partición correcta y compruebe gres con sinfo -o '%G'
- Permisos en /scratch o en /data: verifique propietario y espacio disponible
