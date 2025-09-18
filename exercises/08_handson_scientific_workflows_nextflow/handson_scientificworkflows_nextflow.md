# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 10: Scientific Workflows with Nextflow (Slurm)

Bienvenido a la sesión práctica sobre flujos de trabajo científicos con Nextflow en nuestro HPC. Verás por qué encadenar trabajos o tareas con `sbatch` es tedioso y sensible a errores humanos. Aprenderás como Nextflow es una potente herramienta para solventar estas limitaciones. Además, ejecutaremos un pipeline demo de Nextflow integrado en Slurm ([nf-core/demo](https://nf-co.re/demo/dev/)), y posteriormente, haremos frente a un caso de análisis real usando el pipeline [nf-core/bacass](https://nf-co.re/bacass/dev/).

- [Curso Práctico de Iniciación al uso del Entorno de Alta Computación](#curso-práctico-de-iniciación-al-uso-del-entorno-de-alta-computación)
  - [Práctica 10: Scientific Workflows with Nextflow (Slurm)](#práctica-10-scientific-workflows-with-nextflow-slurm)
  - [Descripción](#descripción)
  - [A) El “antes”: encadenar tareas a mano con Slurm](#a-el-antes-encadenar-tareas-a-mano-con-slurm)
  - [B) Nextflow con Slurm: **nf-demo**](#b-nextflow-con-slurm-nf-demo)
  - [C) Caso real: **nf-core/bacass**](#c-caso-real-nf-corebacass)
  - [D) Comparativa explícita: manual vs Nextflow (qué gana el alumno)](#d-comparativa-explícita-manual-vs-nextflow-qué-gana-el-alumno)
  - [E) Errores frecuentes y cómo resolverlos (rápido)](#e-errores-frecuentes-y-cómo-resolverlos-rápido)
  - [Checklist de lo que debes hacer/tocar](#checklist-de-lo-que-debes-hacertocar)

## Descripción

Hasta ahora hemos visto **realizar** tareas en paralelo con Slurm para tareas puntuales. Sin embargo, esto no suele funcionar cuando quieres:

* **Encadenar** varias etapas de un análisis (QC ➜ trimming ➜ mapeo ➜ reporte).
* **Reintentar** fallos y **reanudar** donde lo dejaste.
* Mantener de forma **organizada** resultados intermedios, logs y resultados finales.

La orquestación con varios `sbatch` + `--dependency` + manejo de logs se vuelve frágil y tediosa.

**Nextflow** resuelve esto. Con Nextflow puedes crear y ejecutar **workflows** cuyos **procesos** (etapas o pasos del análisis) y **canales** (flujo de datos) están definidos, y la información fluye entre ellos. Entre otras particularidades, Nextflow se integra con **Slurm**, facilitando gestionar los trabajos y enviarlos al clúster por ti (capa de abstracción). Nextflow se encarga de gestionar absolutamente todo: instalar dependencias (conda, Docker, Singularity/Apptainer); ejecutar tareas; registrar los logs y resultados de forma estructurada; asegurar la reproducibilidad; y permitir **reintentar** fallos o **reanudar** etapas. En concreto, para lanzar en Slurm solo se necesita una **configuración mínima** por tu parte: eliges el *executor* (Slurm), la cola/recursos y, opcionalmente, contenedores (Singularity/Apptainer). Es particularmente útil porque un workflow que tengas con Nextflow en local (por ejemplo, en tu laptop) es compatible para ser usado en cualquier infraestructura computacional conocida; simplemente se necesita una pequeña configuración.

Ejercicios que vamos a **realizar** en esta sesión:

1. Ver el “antes” (lo complejo que sería encadenar **etapas** de un **análisis** con `sbatch`).
2. Ejecutar **nf-demo** con Slurm.
3. Probar un caso real con **nf-core/bacass**.

---

## A) El “antes”: encadenar tareas a mano con Slurm

> *No lo ejecutes ahora; es para comparar mentalmente con Nextflow.*

* **Paso 1** (array FastQC):

  ```bash
  sbatch fastqc_array.sbatch          # -> Submitted batch job 31001
  ```
* **Paso 2** (Fastp tras FastQC):

  ```bash
  sbatch --dependency=afterok:31001 fastp_array.sbatch
  ```
* **Paso 3** (Bowtie2 después de Fastp):

  ```bash
  sbatch --dependency=afterok:31002 bowtie2_array.sbatch
  ```
* **Problemas típicos**: capturar JOBID, reintentar solo una tarea, reanudar mitad del flujo, mezclar logs, etc.

**Con Nextflow** no usas `--dependency`: declaras *procesos* y *canales* y **él decide el paralelismo**, dependencias, reintentos y *resume*.

---

## B) Nextflow con Slurm: **nf-demo**

### 1) Prepara carpeta y config mínima

Crea `nextflow.config` en tu carpeta de trabajo:

```groovy
// El gestor de paquetes que usaremos será Singularity:
singularity {
  enabled    = true
  autoMounts = true
}

process {
  executor      = 'slurm'      // Con este parámetro hacemos saber a Nextflow que ejecutará en Slurm
  queue         = 'short_idx'  // Indica el nombre de la cola
  cpus          = 1            // CPUs por tarea
  memory        = '2 GB'       // Memoria por tarea
  time          = '1h'        // Límite por tarea
  jobName       = { "${task.process} (${task.name})" }  // Nombre legible en la cola
  errorStrategy = { task.exitStatus in [140,143,137,138,104,134,139] ? 'retry' : 'finish' }
  maxRetries    = 1
  maxErrors     = -1
  // Opcional: restringe nodos o añade flags del clúster
  // clusterOptions = '--nodelist=ideafix[01-10]'
}
```

> **Notas**
>
> * No necesitas `sbatch`; Nextflow hablará con Slurm por ti.

### 2) Lanza **nf-demo**

Vamos a crear un script `sbatch` con el comando de Nextflow a ejecutar. Hay que entender una cosa. Por un lado, está el script `sbatch` que actúa como **master** para la ejecución de las tareas que Nextflow irá lanzando al sistema de colas. Por ello, es importante que la ejecución de este master no se vea interrumpida, ya que si eso pasa no se lanzarán más trabajos. Por otro lado, como este master solo controla la ejecución del comando de Nextflow, pero no lanza las tareas pesadas, no es necesario que le demos muchos recursos más allá del tiempo.



```bash
#!/bin/bash
#SBATCH --job-name=nf_demo
#SBATCH --chdir=/scratch/hpc_course/HPC-COURSE-${USER}/ANALYSIS/10-scientific-workflows-nextflow
#SBATCH --partition=short_idx
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1                 # Recursos SOLO para el controlador de Nextflow
#SBATCH --mem=2G
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

# Carga las dependencias para ejecutar Nextflow
module purge
module load Nextflow/23.10.0
module load singularity/3.7.1

mkdir -p 01-nextflow-demo-results
# Ejecuta nf-core/demo (workflow preparado)
# Importante: le indicamos que lea el archivo de configuración
nextflow run nf-core/demo \
  -profile test,singularity \
  -c nextflow.config \
  --outdir 01-nextflow-demo-results \
  -resume
```

> Nota: Entre sus capas de abstracción, Nextflow tiene la propiedad de descargarse **workflows** listos (datos de prueba, perfiles de testing, etc.) desde repositorios como GitHub. En este caso, antes de lanzar `nf-core/demo`, si no existe en el clúster, lo descargará y luego lo ejecutará.

Ejecutemos el script sbatch:

```bash
sbatch nextflow_demo.sbatch
```


**Monitoreo**

Ahora es el momento de monitorizar las tareas. En Nextflow tenemos que visualizar los siguientes puntos para el monitoreo:

* El *standard output* se guardará en el archivo que hayamos definido en `--output` (en este ejemplo: `%x-%j.out`). Ejemplo de un *standard output* de Nextflow.:

```bash
tail -f logs/nf_demo-<JOBID>.out
```

```bash
N E X T F L O W  ~  version 24.02.0
Launching `main.nf` [elegant_burnell] DSL2 - revision: a1b2c3d4f5
executor >  slurm (6)
[3a/5f1c2b] process > DOWNLOAD_TEST_DATA           [100%] 1 of 1 ✔
[b9/904773] process > FASTQC (sample_1)            [100%] 1 of 1 ✔
[6e/12ab34] process > FASTQC (sample_2)            [100%] 1 of 1 ✔
[2d/aa77cc] process > ECHO_HELLO (1)               [100%] 4 of 4 ✔
[7f/33dd44] process > MULTIQC                       [100%] 1 of 1 ✔

Completed at: 2025-09-01 11:42:17
Duration    : 2m 12s
CPU hours   : 0.1
Succeeded   : 8
```

* Comando `watch squeue --me` para ver las tareas que van entrando al sistema de colas del HPC.

* Por último tendrás que explorar los resultados. Como podrás observar, se habrá creado una carpeta `01-nextflow-demo-results/` (corresponde con los resultados finales del workflow) y `work/` (carpeta propia de Nextflow que almacena tanto datos intermedios como resultados finales).


**PREGUNTAS:**

* ¿Cuántas tareas se lanzaron y con qué **jobName** aparecen en `squeue`?
* Explora detenidamente la carpeta `01-nextflow-demo-results/pipeline_info/` generada por el workflow. 
* Lanza **otra vez** el comando anterior añadiendo `-resume`: ¿re-ejecuta todo?

## D) Comparativa explícita: manual vs Nextflow (qué gana el alumno)

| Aspecto                       | Cadena `sbatch` manual          | Nextflow                                                     |
| ----------------------------- | ------------------------------- | ------------------------------------------------------------ |
| Dependencias                  | `--dependency` a mano           | Implícitas por el grafo (canales)                            |
| Paralelismo                   | Lo gestionas tú (arrays/bucles) | Lo calcula por inputs; el *executor* reparte en Slurm        |
| Reintentos y *resume*         | A mano, frágil                  | `errorStrategy`, `maxRetries`, `-resume` automático          |
| Trazas y reportes             | `sacct`/logs por tu cuenta      | `-with-trace`, `-with-report`, `-with-timeline`, `-with-dag` |
| Portabilidad de software      | Módulos/conda que montas tú     | Perfiles `singularity`/`conda` en `nextflow.config`          |
| Re-ejecutar sólo lo pendiente | Difícil                         | Hashing de tareas + caché                                    |

---

## E) Errores frecuentes y cómo resolverlos (rápido)

* **No hay contenedor** / Singularity no instalado
  ➜ Desactiva singularity y usa `conda.enabled = true` o módulos de tu HPC.

* **Cola/nodo incorrecto**
  ➜ Ajusta `process.queue`, `clusterOptions` o `withName:` en `nextflow.config`.

* **No encuentra archivos de entrada**
  ➜ Revisa rutas del *samplesheet* y permisos. Si el canal queda vacío, Nextflow no lanza tareas.

* **Quiero ver qué está lanzando exactamente**
  ➜ `tail -f .nextflow.log` y `squeue --me`.

---

## Checklist de lo que debes hacer/tocar

1. Crear `nextflow.config` (executor=slurm, perfil singularity, recursos por defecto).
3. Crear `samplesheet.csv` y ejecutar **nf-core/bacass**.
4. Repetir con `-resume` y **ver qué se salta**.
5. Ajustar recursos con `withName:` y **confirmar** en `squeue/trace`.

**Preguntas:**

* ¿Qué parte te resultó más “mágica”: **no usar `sbatch`** o **reanudar** con `-resume`?
* ¿Dónde mirarías primero si algo falla?
