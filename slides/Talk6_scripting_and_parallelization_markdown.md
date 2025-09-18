# Talk 6: Scripting and parallelization

## Scripting

The main idea of this part of the course is learning to **delegate work** to the cluster. Instead of running every command by hand, we prepare a small script that the job scheduler (Slurm) reads and runs for us. This way we can log off and let the computers do the work without direct supervision. Also, working like this is safer for the system: admins recommend not running heavy tasks on the **login node** (frontend), but sending them to the compute nodes through Slurm. Slurm will assign the job to an available node, control how it runs, and avoid resource conflicts, ensuring fair and efficient use of the cluster.

### SBATCH: the entry door

#### What is `sbatch`?

* `sbatch` is a command you can run in the terminal to send an order to **Slurm**.
* More specifically, it’s the **Slurm** command to submit a job *script* to the cluster queue. It’s like dropping a parcel at the post office so they deliver it when they can: you hand in the parcel (your script) at the Slurm “office”, and the cluster runs it when resources are available.
* In bioinformatics and other areas, it’s useful to launch repetitive analyses (e.g., quality control with `FastQC`, alignments, assemblies, etc.) over many sequencing files without doing them interactively one by one.
* It lets you send jobs to run in the **background** (for example, in the `short_idx` queue on nodes `ideafix[01-10]`), freeing your personal computer for other tasks. In other words, you use the cluster’s power instead of overloading your PC.

#### What is it for?

* **Automation:** You can launch long or multiple tasks without staying connected. Slurm will handle the queueing of these tasks (commonly called “jobs”) in the HPC system, run them, and you can disconnect or do other things.
* **Resource reservation:** When you submit a job, you specify how many CPUs, how much RAM, and how much time you need. The scheduler reserves those resources for you, ensuring each analysis has what it needs and doesn’t interfere with others. This prevents overload and helps use the hardware fairly.
* **Reproducible execution:** There is a record of the activity and results of each job. Standard output and errors are saved to log files, which makes it easier to review what happened at each step and debug if something fails.
* **Easy reruns:** You can repeat an analysis with different parameters by editing a single file instead of retyping all commands. Your steps are documented in the script, reducing human error.

#### How is an `sbatch` script organized?

An `sbatch` script is a text file with a fixed structure that combines **Slurm directives** and **terminal commands**. For example:

```bash
#!/bin/bash                  # 1) Shebang: interpreter that will run the script
#SBATCH --option=value       # 2) SBATCH directives that request resources/settings
#SBATCH --option=value
#SBATCH --option=value
# From here on, the commands we want to run:
command_1
command_2
```

> See complete examples below.

1. **Shebang (`#!/bin/bash`)** – the first line tells which shell will be used (usually Bash).
2. **`#SBATCH` directives** – lines starting with `#SBATCH` to request resources or job settings. These are not normal commands; they are instructions for Slurm processed when you submit the script.
3. **Commands** – after the directives, you write the Linux commands you want to run. When Slurm executes your job on a compute node, it will run these commands in order.

##### Common parameters

A typical header could be:

```bash
#!/bin/bash
#SBATCH --chdir=/path/to/working/directory   # Folder where the analysis will run
#SBATCH --job-name=my_first_slurm_job        # A recognizable job name
#SBATCH --cpus-per-task=1                    # Number of CPU cores (threads) for this job
#SBATCH --mem=1G                             # RAM to reserve
#SBATCH --time=00:10:00                      # Time limit (HH:MM:SS)
#SBATCH --partition=short_idx                # Queue/partition to run in
#SBATCH --output=slurm-%j.out                # File for standard output
#SBATCH --error=slurm-%j.err                 # File for standard error
# From here on, the commands we want to run:
command_1
command_2
```

In this example, the job **my\_first\_slurm\_job** will run in the indicated folder, reserving 1 CPU and 1 GB of RAM for up to 10 minutes, in the `short_idx` partition. The output files `slurm-%j.out` and `slurm-%j.err` will contain what you would usually see on screen: `%j` is replaced by the job ID so each job has its own logs. Later, you can open `slurm-<jobid>.out` to see normal messages, and `slurm-<jobid>.err` to see errors, without mixing them with other jobs. Keep in mind that **setting a time limit is very important** – in some clusters it is mandatory to use `D-HH:MM:SS` or `HH:MM:SS`. If you don’t, Slurm might assume a default max (e.g., 2 days) and that can make your job wait longer before starting.

##### Other useful parameters

* `--mail-type=END,FAIL` and `--mail-user=your_email@domain` – Slurm can email you when the job starts, ends, or fails, depending on what you choose.
* `--dependency=afterok:<jobid>` – makes your job wait until another one finishes successfully. Useful to chain steps.
* `--gres=gpu:2` – on clusters with GPUs, request, for example, 2 GPUs for your job (if you do accelerated computing).

Here is a page where you can find the full list of parameters:

* [https://slurm.schedmd.com/sbatch.html#SECTION\_OPTIONS](https://slurm.schedmd.com/sbatch.html#SECTION_OPTIONS)

> **Note:** Each cluster can have extra parameters or defaults. Check your local documentation for specifics.

#### Load modules and prepare the environment

As we saw in the course, compute nodes often use **environment modules** to manage available software. Before running a program, it’s common to “load” the corresponding module. In this example we will use FastQC, widely used in bioinformatics for short-read quality control. Suppose these short reads from sequencing are stored in the file `datos.fq.gz`:

```bash
#!/bin/bash
#SBATCH --chdir=/path/to/working/directory
#SBATCH --job-name=my_first_slurm_job
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --partition=short_idx
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
module load fastqc/0.12.1    # Load FastQC module version 0.12.1
fastqc datos.fq.gz           # Run the actual command on our file
```

This guarantees the right software is on the *PATH* when the job runs. You can load all modules or activate environments (conda, etc.) needed before the main commands. This way, the compute node will have the same tools you use when testing the analysis interactively.

> If you want to see which modules are available on your HPC, use `module avail`. You’ll get a list of all modules you can load in your scripts with `module load`.

#### Submit the job

To send the job to the cluster we use `sbatch` followed by the script name:

```bash
sbatch fastqc_slurm.sbatch
```

When you submit, Slurm prints something like `Submitted batch job 12345`. That **12345** is the unique job ID. It’s good to note it down, because we will use it to check status and review execution. Remember that `sbatch` only puts your job in the queue; it doesn’t start immediately, but when Slurm finds a slot with the resources you requested. The more resources you request (e.g., many cores or many hours), the longer it might wait, because it needs to find those resources free.

#### Check the job in Slurm

Once submitted, you have several tools to monitor and get information:

* `squeue --me` – shows your jobs in the queue or running (depending on configuration, `--me` filters by your user). You will see columns like JOBID, PARTITION, NAME, ST (state), TIME, and NODES. A freshly submitted job often appears as **PD (Pending)** while it waits, and then **R (Running)** when it starts. If you don’t see your job in `squeue`, it probably finished (or maybe it was never submitted correctly!).
* `scontrol show job <jobid>` – gives **detailed** information about a specific job. It shows all parameters and the current state: which node(s) it is running on or why it is pending (sometimes a *Reason=* field), how much memory it requested, when it was submitted, etc. It’s useful to diagnose why a job remains in the queue (e.g., if you asked for more time than allowed in that partition, you’ll see a Reason). *Tip:* You can only see details of **your** jobs, not other users’.
* `sacct -j <jobid> --format=JobID,State,Elapsed,MaxRSS` – shows the **history** of a job (works once it has **finished**, not for active jobs). This is part of Slurm accounting tools. For example, `sacct -j 12345 -o JobID,State,Elapsed,MaxRSS` will tell you if job 12345 completed successfully (State=COMPLETED) or had problems (FAILED, TIMEOUT, etc.), how long it actually ran (Elapsed), and the maximum RAM it used (MaxRSS). `sacct` is very useful to review resource usage after the fact and tune future requests.

#### Review the results

Once the job finishes (or even during execution), we should **validate the results**:

* Open the output files you set in the script. For example, if you used `--output=slurm-%j.out` and the job ID was 12345, there will be a file `slurm-12345.out`. That is the standard output of your program (what you’d normally see on screen). Also check `slurm-12345.err` for error messages. If your script did not define `--output`/`--error`, Slurm still creates one by default (often `slurm-<jobid>.out` or, for *array jobs*, `slurm-<jobid>_<taskid>.out` by default).
* If the job generated result files (e.g., a FastQC HTML report, a BAM file, etc.), look for them in the working directory you set with `--chdir`. Check they exist and make sense (size, expected format, etc.).
* Check the final status with `sacct`. If it shows **COMPLETED**, it likely finished well. If it shows **FAILED**, **CANCELLED**, or **TIMEOUT**, something happened: maybe the program exited with an error, ran out of memory, or exceeded the time limit. In that case, inspect `.err` for clues (e.g., “Killed” often means it used too much memory).

In short, logs and Slurm information help you do a little “CSI” on your jobs: understand what happened and fine-tune the configuration for next runs.

#### Tips and good practices

* **Use descriptive job names** (`--job-name`). A clear name (e.g., `fastqc_analysis`) helps you identify each job in `squeue` and in logs.
* **Do NOT request more resources than needed!** Responsible usage avoids long queues and wasted compute. Asking for too much (e.g., 16 CPUs if your code only uses 1) will make your job wait longer to start and block resources. In some clusters, if you don’t request memory/CPU, the scheduler assumes you want the whole node and your job **won’t start until a full node is free**, which can mean hours or days. Be specific but realistic.
* **Do not run heavy jobs on the login node:** In fact, never run heavy commands there (light commands like `ls`, `cat`, `tree`, … are fine). **ALWAYS** send heavy work through `sbatch` or `srun` to Slurm. Everyone shares the login node; if you run something big there, you slow down others. Many centers state that *“all HPC jobs must run on compute nodes by submitting a script to the job scheduler.”*
* **Comment your script** to explain each step. You’ll thank yourself when you come back months later. A simple `# Preprocess FASTQs` above a line helps a lot.
* **Test small first:** before launching a massive analysis or a 100-task job array, try a single case or a small subset. This helps you catch wrong paths, missing modules, or bad parameters. Better to discover a missing package in a 2-minute test than after 5 hours in the queue and a failed job.
* **Save your scripts** (ideally version them with Git). You’ll reuse many of them in future projects. Having a small repo of “Slurm scripts” saves time and ensures you use tested commands.
* **Use job arrays for repetitive tasks:** if you find yourself writing a `for` loop to run the same script for 10 files, you probably want a *job array* (we cover it in the next section). Arrays are Slurm’s clean, efficient way to submit many similar jobs at once.
* **Chain jobs with dependencies:** for small workflows, consider launching jobs that start when others finish (`--dependency`). For example, first a filtering job, and when it finishes, a second analysis job on the filtered data. This builds simple pipelines without manual supervision.

---

### Job Arrays: same steps, many samples

#### What are they?

This Slurm feature lets you launch many jobs with **identical structure** (same script) but small changes, usually in the input file or a parameter. Instead of creating 50 scripts for 50 samples, you create **one script** and tell Slurm to run it N times. Think of it like a fleet of couriers delivering the same package to different addresses: the process is the same, only the “address” changes (e.g., input file name). Slurm sends these tasks to the cluster automatically and in parallel when possible.

More formally, a *job array* is a set of *tasks* sharing the same **base JobID** but distinguished by an index (array index). If you submit an array of 10 tasks, Slurm gives you a JobID (say 45678) and each task an ID like 45678\_1, 45678\_2, …, 45678\_10.

#### When to use them?

* When you need to repeat the **same operation** on multiple inputs. For example, run a quality control tool like FastQC on 100 FASTQ files, or train 20 models with different random seeds.
* When you want to test the same code with different independent parameters (e.g., 10 values) without manually changing the script each time.
* In general, for *embarrassingly parallel* workloads, where each task can run on its own without communicating with others.

Official docs recommend arrays instead of launching many single jobs in a loop. It makes your life easier: one command controls the whole set.

#### Environment variables for arrays

Slurm provides some environment variables inside the script so you know which array task is which:

* `$SLURM_ARRAY_JOB_ID` – the array job ID (e.g., 45678 above). All tasks share this base ID.
* `$SLURM_ARRAY_TASK_ID` – the index of the task within the array. It takes values 1, 2, 3, … as defined.
* (There is also `$SLURM_ARRAY_TASK_COUNT` for total tasks, and `$SLURM_ARRAY_TASK_MAX`/`MIN` for the range limits, depending on Slurm version.)

The most useful is `$SLURM_ARRAY_TASK_ID`. You can use it to change input. For example, if your files are named `muestra_1.fq.gz`, `muestra_2.fq.gz`, etc., in the script you can refer to `muestra_${SLURM_ARRAY_TASK_ID}.fq.gz`. Task 1 uses `muestra_1.fq.gz`; task 2 uses `muestra_2.fq.gz`, and so on. One script serves all samples.

Let’s build this script:

```bash
nano fastqc_array_20.sbatch
```

```bash
#!/bin/bash
#SBATCH --chdir=/path/to/project
#SBATCH --job-name=fastqc_array
#SBATCH --partition=short_idx
#SBATCH --array=1-20          
#SBATCH --cpus-per-task=1
#SBATCH --mem=5G
#SBATCH --time=00:15:00
#SBATCH --output=fastqc_%A_%a.out # %A: array JobID, %a: task index
#SBATCH --error=fastqc_%A_%a.err

module load fastqc/0.12.1

mkdir fastqc_results
fastqc -o fastqc_results muestra_${SLURM_ARRAY_TASK_ID}.fq.gz
```

#### Running a job array

Launching an array is as simple as using `--array` with `sbatch`. For example:

```bash
sbatch fastqc_array_20.sbatch
```

This will submit **20 tasks**, numbered 1 to 20, each running the script `fastqc_array_20.sbatch` on its own. Slurm will try to run them in parallel, using as many resources as requested per task. If each task requests 1 CPU, up to 20 could run at once (if the cluster has enough free cores). If each task requests a lot of CPU or RAM, fewer will run at the same time.

You can set more complex ranges: `--array=1-3,7,9-12` would run tasks 1,2,3,7,9,10,11,12 (skipping some). You can also limit how many run concurrently using `%`. Example: `--array=1-100%10` runs at most 10 in parallel, although there are 100 total. This is useful if you don’t want to saturate the cluster or if each task is heavy. Note this does not guarantee order; Slurm manages the queue by priorities and availability—it just won’t start more than the set number at once.

Inside the script, it’s also common to customize log filenames to include the index:

```bash
#!/bin/bash
#SBATCH --job-name=fastqc_array
#SBATCH --partition=short_idx
#SBATCH --array=1-20              # 20 tareas (1..20). Opcional: limita concurrencia con %N, p.ej. 1-20%5
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --chdir=/path/to/project   # <- cambia a tu carpeta de trabajo
#SBATCH --output=fastqc_%A_%a.out  # %A = JobID del array, %a = índice de tarea
#SBATCH --error=fastqc_%A_%a.err

module load fastqc/0.12.1

mkdir -p fastqc_results
fastqc -o fastqc_results muestra_${SLURM_ARRAY_TASK_ID}.fq.gz
```

Here `%A` is the array’s main JobID and `%a` the task index. Each task writes to its own log (e.g., `fastqc_45678_3.out` for job 45678 task 3). Otherwise, if all tasks wrote to the same `slurm-45678.out`, it would be hard to separate outputs (by default, Slurm already separates array logs using `%A_%a` if you don’t set `--output`, but it’s good to know how to customize).

#### Monitoring arrays

* `squeue --me` will show each array task as a separate entry, with format `<JobID>_<Task>` in the JOBID column. For example, you might see `45678_5` in R and `45678_6` in PD, showing which indices are running or pending.
* `scontrol show job <JobID>` with the main ID lists information for the whole array, but you can also query a specific task by adding the index (sometimes `-d` helps to see subtasks). For quick info, `squeue` or `sacct` is usually easier.
* `sacct -j 45678` lists the history of all tasks in array 45678. You can see State (COMPLETED/FAILED) and resources used. This is great to detect, for example, if 2 out of 100 tasks failed and why.
* Custom cluster tools (like `gstat`, if available) may group array usage so the view isn’t flooded. Check local docs for how arrays are presented.

Monitoring arrays is similar to normal jobs, but you have **many child jobs** under one umbrella. To cancel, you can also do it in bulk: `scancel 45678` removes the **whole** array, while `scancel 45678_5` tries to remove just task 5. Once all tasks finish (or are cancelled), the parent JobID is marked as completed.

#### Quick tips

* **Step ranges:** You can launch arrays with a step using `start-end:step`. Example: `--array=0-9:2` runs tasks 0, 2, 4, 6, 8.
* **Avoid huge bursts without control:** While Slurm supports very large arrays, launching 100k tasks at once is not always a good idea. If you process hundreds of thousands of items, confirm the cluster can handle it (there may be limits like `%1000` concurrent, etc.). Split into batches if needed.
* **Combine arrays with dependencies:** You can run an array to process samples and then a single job to aggregate results after *all* tasks finish. Use `--dependency=afterok:<parentJobID>` on the aggregation job. There are other modes; check the docs for advanced cases.
* **Separate temporary files:** If all tasks write to the same file (rare, but possible), conflicts may happen. Try to give each task its own files, ideally tagged with its ID. The `%A`/`%a` placeholders and `$SLURM_ARRAY_TASK_ID` help here.
* **Debugging arrays:** If one task fails, you may want to re-run just that one. You can submit the same script limited to that index (`--array=7`, for example). Also check `sacct` for the exit code or signal that caused the failure.

## Parallelization in HPC: OpenMP vs MPI

In this second part we will see **how to use several cores or even several nodes** to speed up our analyses. In HPC, this is called *parallelization*, and there are two main approaches: **OpenMP** and **MPI**. There are more technologies, but these two are the most common and the ones we will see in our cluster.

### What are OpenMP and MPI?

**OpenMP** is a shared-memory parallel model. It lets a program use multiple threads inside a single process running on one node (which usually has several CPU cores). For example, an OpenMP program launches one process and creates several threads that run in parallel on that node, sharing data in common RAM.

**MPI** is a standard for distributed memory. It is designed to run an application using multiple separate processes, possibly on different nodes of a cluster, that communicate by passing messages over the network. It’s the typical model in supercomputing for very large problems, when data doesn’t fit in one node’s RAM or you need more compute power than a single machine can provide.

In **bioinformatics**, most programs use **OpenMP**:

* Aligners (BWA, Bowtie2, STAR, Minimap2…)
* Assemblers (SPAdes, MEGAHIT…)
* Variant analysis (GATK, FreeBayes…)
* Read processing (Fastp, Cutadapt…)

On the other hand, **MPI** is less common, with exceptions mainly in **phylogenetics** or massive simulations, for example:

* RAxML in MPI mode
* IQ-TREE MPI
* Some molecular modeling or dynamics packages

[TODO]: <Add image of partition — node — CPUs>

The **key difference** is **where and how tasks are split**:

| Technology | Parallelization level     | Communication between processes                                         | Typical use case                                                        |
| ---------- | ------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **OpenMP** | Within **one node**       | Shared memory: all threads access the same RAM                          | Align 200 million reads on one node using all its cores                 |
| **MPI**    | Across **multiple nodes** | Distributed memory: each node has its own RAM; communication by network | Build a very large phylogenetic tree by splitting the work over 4 nodes |

### Pros and cons of **OpenMP** and **MPI**

|                      | **OpenMP**                                                                                           | **MPI**                                                                                                           |
| -------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **What it is**       | Use **several cores of one machine** at the same time.                                               | Use **several machines/nodes** in the cluster that communicate with each other.                                   |
| **Pros**             | - Easy to use.<br>- Most bioinformatics tools support it.<br>- Ideal for quick analyses on one node. | - Works with **huge datasets** that don’t fit in one node.<br>- Scales well when you need **a lot** of resources. |
| **Cons**             | - Only works within a single node.<br>- If the node has few cores, you can’t speed up more.          | - More complex to configure.<br>- More sensitive to network/node issues.<br>- Few bioinformatics tools use it.    |
| **Bioinfo examples** | Aligners (BWA, Bowtie2, STAR), assemblers (SPAdes, MEGAHIT), variant callers (GATK).                 | Phylogeny with RAxML or IQ-TREE, molecular simulations.                                                           |

> As noted by professionals on LinkedIn (F. Quartin de Macedo, M. Saad), OpenMP stands out for simplicity in shared memory, while MPI is valued for scalability on distributed systems. [Article here](https://www.linkedin.com/advice/0/what-pros-cons-using-openmp-vs-mpi-shared?lang=es&lang=es&originalSubdomain=es).

---

[TODO]: <Still need to be tested>

### Setting up an OpenMP job in Slurm

Let’s say we want to run a bioinformatics program that supports OpenMP (for example, a sequence assembler) on a Slurm cluster. The goal is to use, say, 8 CPU cores on one node to speed up the analysis. With OpenMP, the key Slurm parameter is **`--cpus-per-task`**.

```bash
#!/bin/bash
#SBATCH --job-name=spades_openmp
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --partition=long
#SBATCH --output=spades_%j.out
#SBATCH --error=spades_%j.err

module load spades/3.15.5

R1="sample_R1.fq.gz"
R2="sample_R2.fq.gz"
spades.py \
  --threads "${SLURM_CPUS_PER_TASK}" \
  -m 64 \
  -1 "${R1}" -2 "${R2}" \
  -o ensamblado_resultado
```

**Relevant OpenMP script parameters:**

* **`--cpus-per-task`** = number of threads the software can use.
* **`--mem`** must be enough for all those threads, since they share the node’s RAM.
* `$SLURM_CPUS_PER_TASK` is a variable Slurm fills with the value you requested.

**Run the OpenMP script:**

```bash
sbatch spades_slurm.sbatch
```

**Debugging and usage checks:**

* During execution:
  `sstat -j <jobid> --format=JobID,MaxRSS,AveCPU` → see RAM and CPU usage.
* After it finishes:
  `sacct -j <jobid> --format=JobID,Elapsed,MaxRSS,TotalCPU` → check if you really used the threads you asked for.

---

[TODO]: <Still need to be tested>

### Setting up an MPI job in Slurm

With MPI, the key parameters are **`--nodes`** and **`--ntasks`**. Imagine using an MPI-enabled tool—e.g., **RAxML** for a large phylogenetic analysis. We want 2 nodes with 4 MPI processes on each (8 processes in total). The SBATCH script would be:

```bash
#!/bin/bash
#SBATCH --job-name=raxml_mpi
#SBATCH --nodes=2
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --partition=long
#SBATCH --output=raxml_%j.out
#SBATCH --error=raxml_%j.err

module load raxml/8.2.12
mpirun -np $SLURM_NTASKS raxmlHPC-MPI -s datos.phy -n resultado -m GTRGAMMA
```

**Relevant MPI script parameters:**

* **`--nodes`** = how many different nodes to use.
* **`--ntasks`** = total number of MPI processes to launch (they can be split across nodes).
* **`--ntasks-per-node`** = how many processes per node (optional but recommended).
* `$SLURM_NTASKS` = variable with the total number of tasks requested.

**Debugging and usage checks:**

* Same tools as OpenMP: `sstat` and `sacct` to see real usage.
* Important: with MPI, if a node fails or there is a network problem, the whole job can stop.

---

### Extra: quick pros and cons

| Aspect              | OpenMP                                      | MPI                                           |
| ------------------- | ------------------------------------------- | --------------------------------------------- |
| **Ease of use**     | Very simple: just request more CPUs/threads | More complex: nodes, tasks, distribution      |
| **Speed**           | Scales well inside one node                 | Scales across nodes; ideal for huge workloads |
| **Communication**   | Shared memory (fast)                        | Network between nodes (slower)                |
| **Typical bioinfo** | Most tools                                  | Specific cases (phylogeny, simulations)       |
| **Common risks**    | Asking for more threads than the tool uses  | Wrong node/task configuration                 |

---

### Debugging tips for students

* **OpenMP:**
  If you request 16 threads but `sacct` shows very low `AveCPU`, your tool is not using all threads. Adjust `--cpus-per-task` or check the tool’s parameter (`--threads` or similar).

* **MPI:**
  If a task hangs, check the `.err` logs for network or communication messages. Sometimes it’s a busy node or an incompatible module.

* **Both:**
  Use short test runs before starting a 3-day analysis. It’s better to find a problem in 5 minutes than after 72 hours.


