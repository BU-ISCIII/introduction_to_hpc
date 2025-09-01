# HandsOn: Scientific workflows con Nextflow (mini-preview)

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

## A) El “antes”: encadenar a mano con Slurm (visión rápida)

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
#SBATCH --partition=short_idx
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1                 # Recursos SOLO para el controlador de Nextflow
#SBATCH --mem=2G
#SBATCH --output=nextflow_stdout.log

# Carga las dependencias para ejecutar Nextflow
module purge
module load Nextflow/23.10.0
module load singularity/3.7.1

# Ejecuta nf-core/demo (workflow preparado)
# Importante: le indicamos que lea el archivo de configuración
nextflow run nf-core/demo \
  -profile test,singularity \
  -c nextflow.config \
  --outdir results \
  -resume
```

> Nota: Entre sus capas de abstracción, Nextflow tiene la propiedad de descargarse **workflows** listos (datos de prueba, perfiles de testing, etc.) desde repositorios como GitHub. En este caso, antes de lanzar `nf-core/demo`, si no existe en el clúster, lo descargará y luego lo ejecutará.

Ejecutemos el script sbatch:

```bash
sbatch nextflow_demo.sbatch
```


**Monitoreo**

Ahora es el momento de monitorizar las tareas. En Nextflow tenemos que visualizar los siguientes puntos para el monitoreo:

* El *standard output* se guardará en el archivo que hayamos definido en `--output` (en este ejemplo: `nextflow_stdout.log`). Ejemplo de un *standard output* de Nextflow.:

```bash
tail -f nextflow_stdout.log
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

* Por último tendrás que explorar los resultados. Como podrás observar, se habrá creado una carpeta `results/` (corresponde con los resultados finales del workflow) y `work/` (carpeta propia de Nextflow que almacena tanto datos intermedios como resultados finales).


**PREGUNTAS:**

* ¿Cuántas tareas se lanzaron y con qué **jobName** aparecen en `squeue`?
* Explora detenidamente la carpeta `results/pipeline_info/` generada por el workflow. 
* Lanza **otra vez** el comando anterior añadiendo `-resume`: ¿re-ejecuta todo?

## C) Caso real: **nf-core/bacass**


Vamos a hacer un análisis real de un workflow en bioinformática automatizado con Nextflow y listo para ser utilizado en la infraestructura HPC. Este pipeline se llama [nf-core/bacass](https://nf-co.re/bacass/2.4.0), y realiza un control de calidad, ensamblado y anotación de genomas con multitud de herrmaientas.

Para comenzar, vamos cear un archivo de entrada para el pipeline en tu directorio de trabajo. Este archivo recoge la relación entre el nombre de la muestra y sus archivos implicados: 

```bash
cat > samplesheet.csv <<'CSV'
ID,R1,R2,LongFastQ,Fast5,GenomeSize
Sample01,data/sample01_R1.fastq.gz,data/sample01_R2.fastq.gz,NA,NA,NA
Sample02,data/sample02_R1.fastq.gz,data/sample02_R2.fastq.gz,NA,NA,NA
CSV
```

> Cada fila muestra la información de una muestra. 

### 2) Reutiliza `nextflow.config` y lanza bacass

Crea el script sbatch master que controlará la ejecución de nextflow. Llamaremos a este script `nextflow_bacass.sbatch`.

```bash
#!/bin/bash
#SBATCH --job-name=nf_bacass
#SBATCH --partition=short_idx
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=nextflow_bacass_stdout.log

module purge
module load Nextflow/23.10.0
module load singularity/3.7.1

nextflow run nf-core/bacass \
  -profile test,singularity \
  -c nextflow.config \
  --input samplesheet.csv \
  --outdir results/bacass_test \
  -resume
```

> **Tip**: muchos pipelines nf-core aceptan `--input` (o `--samplesheet` según release). Verifica con `-help`.

**Monitorea:**

```bash
squeue --me -o "%.18i %.10P %.40j %.2t %.10M %.6D %R"
tail -f nextflow_bacass_stdout.log
```

**Salidas esperables:**

* `results/bacass_test/` con ensamblados, anotación y **MultiQC**.
* `results/bacass_test/pipeline_info/`.

**PREGUNTAS:**

* Explora `results/bacass_test/pipeline_info/`: ¿qué **etapa** fue la más lenta?
* Vuelve a lanzar con `-resume`: ¿qué etapas **se saltan** y cuáles se re-ejecutan?

### 3) Ajustar recursos “por proceso” (sin tocar el pipeline)

Puedes subir/bajar recursos con **`withName:`** en `nextflow.config` sin editar el pipeline:

```groovy
process {
  withName: FASTQC {
    cpus   = 2
    memory = '3 GB'
    time   = '30m'
  }
  withName: SPADES {
    cpus   = 8
    memory = '64 GB'
    time   = '12h'
  }
}
```


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


