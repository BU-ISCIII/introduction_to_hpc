# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

## Práctica 6: Gestión de Software en HPC

Bienvenido a la sesión práctica sobre la gestión de software en nuestro HPC. Hoy cubriremos tres temas principales:

- [Curso Práctico de Iniciación al uso del Entorno de Alta Computación](#curso-práctico-de-iniciación-al-uso-del-entorno-de-alta-computación)
  - [Práctica 6: Gestión de Software en HPC](#práctica-6-gestión-de-software-en-hpc)
    - [Notas importantes](#notas-importantes)
  - [1. Permisos: PC personal vs HPC](#1-permisos-pc-personal-vs-hpc)
  - [2. Entornos Virtuales \& Gestores de Software](#2-entornos-virtuales--gestores-de-software)
    - [(Extra) Cómo compartir entornos virtuales entre usuarios con micromamba](#extra-cómo-compartir-entornos-virtuales-entre-usuarios-con-micromamba)
    - [2.2 Otros gestores: Easybuild](#22-otros-gestores-easybuild)
  - [3. Contenedores: Docker \& Singularity](#3-contenedores-docker--singularity)
    - [3.1 Descargar y ejecutar un contenedor de Singularity](#31-descargar-y-ejecutar-un-contenedor-de-singularity)
    - [3.2 Otros conceptos importantes sobre singularity](#32-otros-conceptos-importantes-sobre-singularity)

### Notas importantes

- El acceso se realiza al nodo de login `portutatis.isciii.es` mediante el puerto `32122`.
- No se deben ejecutar cálculos en el nodo de login, solo gestionar ficheros y enviar trabajos a la cola.
- Los datos de usuario se organizan en diferentes espacios de trabajo:

  - `/home/usuario` → scripts y ficheros pequeños.
  - `/data/unidad` → datos y resultados de proyectos.
  - `/scratch/unidad` → ejecución temporal de trabajos (se eliminan ficheros inactivos a los 5 días).
  - `/local_scratch` → espacio temporal en cada nodo, se elimina al terminar el trabajo.
- No almacenar información no relacionada con los cálculos autorizados.

## 1. Permisos: PC personal vs HPC

- En este apartado vamos a **Comparar permisos de archivos y software** entre tu PC personal y el HPC y cómo gestionarlos.
- **Práctica: comprobar permisos de usuario y grupo**

  - Comprobar tus permisos de usuario en tu ordenador personal:

  ```bash
  whoami # Mostrar mi nombre de usuario
  groups # Mostrar los grupos a los que pertenece mi usuario
  ls -l ~ # Listar contenido del directorio home (~), incluyendo permisos
  ```

  - Ahora repite el mismo comando pero en el HPC, ¿ves alguna diferencia? ¿Por qué?

- **Práctica con `chown` (cambiar propietario del archivo):**

  - En tu ordenador personal (si tienes acceso admin/root), crea un archivo y cambia su propietario:

  ```bash
  touch testfile.txt # Crear archivo
  ls -l testfile.txt
  rm testfile.txt
  ```

  - El archivo se ha borrado sin problema. Pero ¿qué pasa si solo puede borrarlo root?

  - Primero, iniciemos una sesión root en nuestro ordenador personal:

  ```bash
  sudo su
  touch testfile.txt
  exit # Salir de la sesión root
  ```

  - Ahora que salimos de root, revisemos los permisos de testfile.txt.

  ```bash
  ls -l testfile.txt
  ```

  - Intenta editar o borrar el archivo como usuario normal:

  ```bash
  rm testfile.txt
  ```

  - **En el HPC**, intenta ejecutar `chown` en un archivo de tu directorio home:

  ```bash
  # vamos a nuestro home
  cd
  pwd
  ls
  touch myfile.txt
  ls -l myfile.txt # Veremos que los permisos son unicamente de nuestro usuario
  chown root:root myfile.txt
  ```

  - **Output:** Aparecerá `"Operation not permitted"`, porque no tienes privilegios root en el HPC.

  - Ahora intenta cambiar la propiedad a un grupo común del laboratorio: `chown alumnoXX:hpccourse myfile.txt`. Podremos ver con `ls -l` que en ese caso sí que funciona porque pertenecemos a ese grupo y el propietario sigue siendo el mismo.

  - **Discusión:**

    - ¿Por qué `chown` está restringido en sistemas compartidos?
    - ¿Cómo afecta esto a la instalación de software y gestión de archivos en HPC?

## 2. Entornos Virtuales & Gestores de Software

- **¿Por qué usar entornos virtuales?**
  Principalmente para aislar dependencias y evitar conflictos, pero también sirve para organizar todo el software necesario para una tarea en el mismo lugar.

- **¿Cómo crear un entorno virtual?**
  Existen muchas herramientas que ayudan a crear entornos virtuales. Softwares como **conda o mamba** incluso los gestionan para simplificar la instalación de software y evitar conflictos.
  
- En primer lugar, sino estamos ya conectados, vamos a conectarnos al HPC por ssh como hemos visto anteriormente: `ssh -p 32122 usuario@portutatis.isciii.es`

  - Una manera sencilla de crear un entorno virtual es con `venv`, una herramienta propia de Python:

    ```bash
    cd # nos aseguramos que estamos en nuestro home
    pwd
    ls
    python3 -m venv bioenv # Crear el entorno
    source bioenv/bin/activate # Activar el entorno
    ```

    Verás `(bioenv)` a la izquierda del prompt indicando que está activado. `pip` se instala por defecto, así que podemos aprovecharlo para instalar librerías ya que ayuda a gestionar las dependencias:

    ```bash
    pip install --upgrade pip # Upgrade pip version, default is too old
    pip install numpy rich requests # Instalar paquetes con pip
    python3 -c 'import numpy as np; print(np.random.rand(10))' # Comprobar instalación
    "Output (Numeros aleatorios)
    [0.82817341 0.32560646 0.96031543 0.49938711 0.28076754 0.5633077
    0.62029871 0.13840926 0.12178352 0.74080816]
    "
    ```

    - Vamos a ver que pasa si lo desinstalamos:

    ```bash
    pip uninstall -y numpy # -y Evita que nos pregunte si estamos seguros 
    python3 -c 'import numpy' # Esperado -> ModuleNotFoundError
    "Output
    Traceback (most recent call last):
    File "<string>", line 1, in <module>
    ModuleNotFoundError: No module named 'numpy'
    "
    deactivate # Salir del entorno virtual
    ```

    Nota: Puedes salir en cualquier momento del entorno virtual con `deactivate`.

- **¿Cómo trabajar con entornos virtuales en nuestro HPC?**
  En este ejercicio usaremos **seqkit** para inspeccionar archivos de secuencias.

  - Veamos si lo tenemos instalado:

    ```bash
    seqkit --help # <-- Command 'seqkit' not found
    ```

  - Intentemos instalarlo con pip:

    ```bash
    pip install seqkit
    ```

  - Bueno, eso no salió como esperábamos ¿verdad? Como vimos en la clase teórica, pip no crea ninguna virtualización, solo gestiona paquetes y dependencias. Por lo tanto, si intentáramos instalar algo con pip, terminaríamos instalándolo para todos los demás usuarios del HPC. Esa es la razón principal por la que **pip no está instalado globalmente en nuestro HPC**.

  - **Discusión:** ¿Se te ocurre alguna alternativa para instalar seqkit?
  Vamos a ver si lo tenemos disponible dentro de **bioenv**, el entorno virtual que creamos previamente.

    ```bash
    source bioenv/bin/activate
    pip list # Comando para ver qué paquetes están instalados por pip

    "Output

    Package            Version
    ------------------ ---------
    certifi            2025.4.26
    charset-normalizer 2.0.12
    commonmark         0.9.1
    dataclasses        0.8
    idna               3.10
    numpy              1.19.5
    pip                21.3.1
    Pygments           2.14.0
    requests           2.27.1
    rich               12.6.0
    setuptools         39.2.0
    typing_extensions  4.1.1
    urllib3            1.26.20n
    "
    ```

    No es nuestro caso, pero podemos intentar instalarlo con pip.

    ```bash
    pip install seqkit

    # Output esperado:
    # ERROR: Could not find a version that satisfies the requirement seqkit (from versions: none)
    # ERROR: No matching distribution found for seqkit
    ```

    Parece que `seqkit` no está disponible en el repositorio de pip [https://pypi.org/](https://pypi.org/). En este caso, usaremos **micromamba** para crear un entorno aislado ya que seqkit si se encuentra accesible en los repositorios de micromamba. Una vez activado el entorno, podremos instalar y usar `seqkit` de manera segura dentro de él. <br><br>

- **Micromamba:** Nuestro gestor de entornos favorito, ya que es especialmente rápido y ligero. Para descargarlo en vuestro _Home_ podéis utilizar el siguiente comando (recuerda salir de `bioenv` primero):

```bash
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
```

- Comprobamos que está instalado viendo que tenemos un fichero binario en `~/bin/micromamba`. Además de lanzar el comando y ver que vemos la ayuda

```bash
micromamba
```

- Output:

```bash
Version: 2.3.2 



micromamba [OPTIONS] [SUBCOMMAND]


OPTIONS:
  -h,     --help              Print this help message and exit
          --version

Configuration options:
          --rc-file FILE1 FILE2...
                              Paths to the configuration files to use
          --no-rc             Disable the use of configuration files
          --no-env            Disable the use of environment variables

Global options:
  -v,     --verbose           Set verbosity (higher verbosity with multiple -v, e.g. -vvv)       
          --log-level ENUM:value in {critical->5,debug->1,error->4,info->2,off->6,trace->0,warning->3} OR {5,1,4,2,6,0,3}
                              Set the log level
  -q,     --quiet             Set quiet mode (print less output)
  -y,     --yes               Automatically answer yes on prompted questions
          --json              Report all output as json
          --offline           Force use cached repodata
          --dry-run           Only display what would have been done
          --download-only     Only download and extract packages, do not link them into
                              environment.
          --experimental      Enable experimental features
          --use-uv            Whether to use uv for installing pip dependencies. Defaults to     
                              false.

Prefix options:
  -r,     --root-prefix PATH  Path to the root prefix
  -p,     --prefix PATH       Path to the target prefix
          --relocate-prefix PATH
                              Path to the relocation prefix
  -n,     --name NAME         Name of the target prefix

SUBCOMMANDS:
  shell                       Generate shell init scripts
  create                      Create new environment
  install                     Install packages in active environment
  update                      Update packages in active environment
  self-update                 Update micromamba
  repoquery                   Find and analyze packages in active environment or channels        
  remove, uninstall           Remove packages from active environment
  list                        List packages in active environment
  package                     Extract a package or bundle files into an archive
  clean                       Clean package cache
  config                      Configuration of micromamba
  info                        Information about micromamba
  constructor                 Commands to support using micromamba in constructor
  env                         See `mamba/micromamba env --help`
  activate                    Activate an environment
  run                         Run an executable in an environment
  ps                          Show, inspect or kill running processes
  auth                        Login or logout of a given host
  search                      Find packages in active environment or channels
                              This is equivalent to `repoquery search` command
```

- Para hacer que el comando micromamba persista en nuestro entorno cuando reiniciemos la terminar, o salgamos y entremos de nuevo en el hpc. Tenemos que añadir una serie de cambios a nuestro bashrc. Además de hacer el setup de la carpeta donde se van a instalar todos los entornos.

```bash
./bin/micromamba shell init -s bash -r ~/micromamba
```

- Este comando añadirá este bloque a tu .bashrc. Puedes comprobarlo con `cat .bashrc`

```bash
# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba  init' !!
export MAMBA_EXE='/home/USUARIO/bin/micromamba  bin/micromamba';
export MAMBA_ROOT_PREFIX='/home/USUARIO/bin/micromamba micromamba';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash  --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"
fi
unset __mamba_setup
# <<< mamba initialize <<<
```

- Para que se apliquen los cambios a nuestra terminal actual recargamos la configuración de nuestra terminal:

```bash
source ~/.bashrc
```

- Ahora ya podemos utilizar micromamba invocándolo directamente por su nombre. Micromamba cuenta con un entorno `base` pre-instalado: podemos activarlo con `micromamba activate`. Cuando se haya activado aparecerá `(base)` a la izquierda de nuestra linea de comandos. Para salir, utiliza `micromamba deactivate`.

- Por último vamos a configurar nuestro `.condarc`:

```bash
touch ~/.condarc
```

- Escribimos lo siguiente en el fichero con `nano` o `vim`:

```bash
auto_activate_base: false
channels:
  - conda-forge
channel_priority: strict
```
- Si a pesar de esto no os deja instalar, probad a modificar el archivo para que **solo** tenga el contenido anterior:
```bash
# Borrar todo lo anterior y dejar solo esto:
auto_activate_base: false
channels:
  - conda-forge
channel_priority: strict
# Guardar y salir
```

- Con esto ya tendríamos un entorno virtual, pero nosotros vamos a ir más allá, creando un entorno virtual personalizado con `micromamba create`:

```bash
micromamba create -y -n mamba_env python==3.12.0 pip twine -c conda-forge
```
  
- Output:

```bash
  #
  # Transaction finished
  # 
  # To activate this environment, use:
  # 
  #     micromamba activate mamba_env
  # 
  # Or to execute a single command in this environment, use:
  # 
  #    micromamba run -n mamba_env mycommand
```
  
- Vamos a explicar cada parámetro en profundidad:

  - `-y` sirve para no tener que confirmar la instalación
  - `-n` se usa para asignar el **nombre del entorno**
  - `python==3.12.0 pip twine` son los **paquetes iniciales** a instalar: en este caso especificamos `python` con la versión `3.12.0` y `pip`.
  - `-c` indica el **channel o canal** donde va a buscar los paquetes.

  **Podemos establecer tantos paquetes iniciales como queramos**, siempre que estén disponibles en los canales de conda configurados.
  
  - Activemos nuestro entorno virtual:
  
  ```bash
  micromamba activate mamba_env
  ```
  
  - Tus paquetes ahora están aislados del   sistema global. Verás `(mamba_env)` añadido en la esquina   izquierda del prompt de tu terminal como indicador de que   el entorno está activado.
  
  - Puedes probar `pip list`   ahora, ya que estará disponible dentro del entorno   virtual. Esto listará todos los paquetes instalados con   pip. Intenta hacer lo mismo en el anterior virtualenv   `mamba_env` para ver qué ocurre (_pista: primero necesitarás   salir con `micromamba deactivate`_).
  
  - Veamos si `seqkit` está disponible en pip o micromamba para poder instalarlo:
  Pip no tiene un comando oficial para buscar un paquete, debes ir a su página web y usar el navegador para encontrarlo [https://pypi.org/search](<https://pypi.org/>  search). Es crucial inspeccionarlo antes de instalar, ya que podría haber un paquete con el mismo nombre que el que quieres pero con diferente funcionalidad.
  
  **Ejemplo**: `taranis` en pip es un wrapper de una API meteorológica, pero en bioconda es un pipeline para wg/cgMLST allele calling.
  
  - En este caso, `Seqkit` no está disponible a través de pip, por lo que nuestra mejor opción es instalarlo con micromamba.
  
  - Veamos si `seqkit` está disponible en micromamba:
  
  ```bash
  micromamba search seqkit
  # Getting repodata from channels...

  # nodefaults/  # linux-64                                         Using   # cache
  # nodefaults/  # noarch                                           Using   # cache
  # conda-forge/noarch                                  22.3MB   # @  31.6MB/s  0.6s
  # conda-forge/linux-64                                47.0MB   # @  51.1MB/s  0.9s
  # No entries matching "seqkit" found
  # Try looking in a different channel with '-c, --channel'.
  ```
  
  Como puedes ver no aparece. Esto es debido a que seqkit solo se encuentra disponible en [https://conda.anaconda.org/bioconda](https://conda.anaconda.org/bioconda). Esto significa que si no tenemos el canal `bioconda` añadido a nuestra configuración, no podremos descargarlo con micromamba.
  
  - Puedes comprobar la lista de canales accesibles con:
  
  ```bash
  micromamba config get channels
  ```
  
  Podrías ver algo como lo siguiente:
  
  ```bash
  channels:
      - conda-forge
  ```

  Vamos a indicarle que busque el paquete en `bioconda`:

  ```bash
  micromamba install seqkit -c bioconda
  ```
  
  - Si quieres **añadir un canal por defecto**, puedes hacerlo modificando la sección `channels` en el archivo de configuración `~/.condarc`. El orden de los canales es importante para evitar conflictos, la configuración actual que recomienda bioconda es esta, pero puede cambiar con el tiempo:

  > Nota primer canal con más prioridad que el segundo
  
  ```bash
  channels:
      - conda-forge
      - bioconda
  ```

  Ahora ya no tendrás que indicar bioconda como canal al instalar ya que lo usará por defecto.

  Como práctica, vamos a **eliminar el canal bioconda** e intentar reinstalar `seqkit`:
  
  1. Elimina `- bioconda` de la sección `channels` en `~/.  condarc`
  2. Ejecuta `micromamba remove seqkit` para desinstalarlo
  3. Reinstala `seqkit` con micromamba
  
  Bueno bueno, ahora parece que `seqkit` ya no está   disponible.
  
  Para continuar con la siguiente sección, **vuelve a añadir   el canal bioconda** e **instala seqkit otra vez** por tu   cuenta.
  
  - **Consejo**: si quieres instalar paquetes de   Python, usa `pip install` ya que es el repositorio de   paquetes de Python más grande, pero para herramientas más   complejas como `bedtools` o ``fastp utiliza **micromamba** o   **conda**.

  - Ahora que ya tenemos instalado `seqkit`, vamos a hacer una pequeña prueba para ver que funciona:

  ```bash
  micromamba activate mamba_env
  seqkit version
  "Output
  seqkit v2.10.1
  "
  ```

  ```bash
  # zcat permite leer archivos comprimidos
  srun --partition=short_idx --cpus-per-task=1 --mem=1G --time=00:02:00 zcat /data/courses/hpc_course/*HPC-COURSE_${USER}/RAW/virus1_R1.fastq.gz | seqkit stats
  "Output
  
  file  format  type  num_seqs     sum_len  min_len  avg_len  max_len
  -     FASTQ   DNA    142,672  15,874,146       35    111.3      151
  "
  micromamba deactivate
  ```

### (Extra) Cómo compartir entornos virtuales entre usuarios con micromamba

- Configura `.condarc` para utilizar un directorio de entornos común para otros usuarios:

    ```bash
    nano ~/.condarc
    envs_dirs:
       - RUTA_POSIBLE/micromamba/envs
    ```

  A partir de ahora, tendrás disponibles todos los entornos creados y guardados en esa localización. Y todos los usuarios que hagan lo mismo tendrán acceso a la misma lista de entornos.

### 2.2 Otros gestores: Easybuild

- Easybuild es un gestor de software especialmente pensado para sistemas HPC como el nuestro. Este gestor permite a los administradores empaquetar software en módulos o `modules`. Esto hace accesibles a los usuarios múltiples versiones de un mismo software de forma rápida y eficaz.
<br>
- Vamos a probar un ejemplo con R. Intentemos iniciar una sesión de R:

```bash
R
# Output
# -bash: R: command not found
```

- Como podemos ver, R no está instalado a nivel de sistema (no es accesible directamente para los usuarios). Sin embargo, podemos acceder a R en el HPC a través de `modules`

```bash
module load R/4.1.3
R
"
Output

R version 4.1.3 (2022-03-10) -- "One Push-Up"
Copyright (C) 2022 The R Foundation for Statistical Computing
Platform: x86_64-conda-linux-gnu (64-bit)

R is free software and comes with ABSOLUTELY NO WARRANTY.
You are welcome to redistribute it under certain conditions.
Type 'license()' or 'licence()' for distribution details.

  Natural language support but running in an English locale

R is a collaborative project with many contributors.
Type 'contributors()' for more information and
'citation()' on how to cite R or R packages in publications.

Type 'demo()' for some demos, 'help()' for on-line help, or
'help.start()' for an HTML browser interface to help.
Type 'q()' to quit R.

> Aquí podréis lanzar comandos de R 
ctrl+D para salir y pulsar "n" (no guardar) 
"
```

Aunque esto pueda parecer engorroso, si sólo tuvieramos una sóla versión de R instalada a nivel de sistema, impediría a los usuarios ejecutar software que requiera de versiones concretas de R para su funcionamiento.

- **¿Cómo listar los módulos accesibles en el HPC?**.
Para ello bastará con utilizar `module avail`. En el output veremos una gran lista de módulos, agrupados por categorías, entre ellas:

      - `bio`: Software bioinformático
      - `data`: Software de gestión de datos como MariaDB o XML
      - `tools`: Herramientas variadas como compresores de archivos
      - ``lang``:lenguajes de programación.
      - `math`: software de cálculo/matemático.
      - `vis`: software de visualizacion genérico o de datos.
Para cada módulo veremos el nombre del módulo seguido por `/` y la versión del software contenido (ej: `python/3.6.9`).
- Podemos utilizar `module avail <regex>` para buscar modulos por su nombre o parte de éste. Por ejemplo, para buscar todas las versiones de R disponibles:

```bash
module avail python/

"
Output

------------------- /opt/modulefiles/eb/bio ------------------
   bx-python/0.8.9-foss-2020a-Python-3.8.2

------------------- /opt/modulefiles/eb/lang -------------------
   Python/2.7.18-GCCcore-9.3.0     Python/3.7.4-GCCcore-8.3.0    Python/3.8.6-GCCcore-10.2.0         Python/3.9.5-GCCcore-10.3.0
   Python/2.7.18-GCCcore-10.2.0    Python/3.8.2-GCCcore-9.3.0    Python/3.9.5-GCCcore-10.3.0-bare    Python/3.10.4-GCCcore-11.3.0-bare (D)

  Where:
   D:  Default Module

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching any of the "keys".
"
```

Otra opción más dirigida es `module spider`. La principal diferencia con `module avail`es que `spider` te devuelve cada paquete de forma individualizada con una descripción y sus versiones disponibles, en vez de un listado genérico. Vamos a repetir la búsqueda de las versiones de python con esta opción:

```bash
module spider Python

" Output
----------------------------------------------------------------------------
  Python:
----------------------------------------------------------------------------
    Description:
      Python is a programming language that lets you work more quickly and
      integrate your systems more effectively.

     Versions:
        Python/2.7.18-GCCcore-9.3.0
        Python/2.7.18-GCCcore-10.2.0
        Python/3.7.4-GCCcore-8.3.0
        Python/3.8.2-GCCcore-9.3.0
        Python/3.8.6-GCCcore-10.2.0
        Python/3.9.5-GCCcore-10.3.0-bare
        Python/3.9.5-GCCcore-10.3.0
        Python/3.10.4-GCCcore-11.3.0-bare
     Other possible modules matches:
        bx-python

----------------------------------------------------------------------------
  To find other possible module matches execute:

      $ module -r spider '.*Python.*'

----------------------------------------------------------------------------
  For detailed information about a specific "Python" package (including how to load the modules) use the module's full name.
  Note that names that have a trailing (E) are extensions provided by other modules.
  For example:

     $ module spider Python/3.10.4-GCCcore-11.3.0-bare
----------------------------------------------------------------------------
"
```

Es importante mencionar que es **case-sensitive** por lo que no es lo mismo buscar `Python` que `python`. Como esta última opción nos enseñará todos los paquetes que contengan python en alguna parte de su nombre, podemos reducir el rango de búsqueda incluyendo el parámetro `-r`:

```bash
module -r spider Python

" Output
----------------------------------------------------------------------------
  Python:
----------------------------------------------------------------------------
    Description:
      Python is a programming language that lets you work more quickly and
      integrate your systems more effectively.

     Versions:
        Python/2.7.18-GCCcore-9.3.0
        Python/2.7.18-GCCcore-10.2.0
        Python/3.7.4-GCCcore-8.3.0
        Python/3.8.2-GCCcore-9.3.0
        Python/3.8.6-GCCcore-10.2.0
        Python/3.9.5-GCCcore-10.3.0-bare
        Python/3.9.5-GCCcore-10.3.0
        Python/3.10.4-GCCcore-11.3.0-bare

----------------------------------------------------------------------------
  For detailed information about a specific "Python" package (including how to load the modules) use the module's full name.
  Note that names that have a trailing (E) are extensions provided by other modules.
  For example:

     $ module spider Python/3.10.4-GCCcore-11.3.0-bare
----------------------------------------------------------------------------
"
```

- **Prueba por tu cuenta** a lanzarlo ahora sin `-r`. ¿Qué diferencias ves?
<br>

- Si quieres comprobar **qué módulos están activos** en tu sesión, puedes ejecutar `module list`.
Cuando termines de usar un módulo, puedes ejecutar `module unload <module_name>` para descargarlo de tu sesión, o `module purge` para descargar todos los módulos activos.

**Puedes combinar modules y entornos virtuales**: Por ejemplo, puedes iniciar el entorno `mamba_env` de micromamba y se mantendrán cargados los módulos que tuvieras cargados, o cargar módulos desde dentro, como prefieras.

## 3. Contenedores: Docker & Singularity

- **¿Por qué contenedores?**
  Portabilidad y reproducibilidad de entornos de software.

- **Práctica:**
  Desafortunadamente, no tenemos Docker disponible en nuestro HPC. **Singularity** es un buen reemplazo de Docker ya que gestiona contenedores y además está **específicamente diseñado para sistemas HPC**.

- En este ejercicio usaremos **fastp** para convertir algunos archivos bam de nuevo a fastq. Busquemos un contenedor de Singularity con el software requerido:

```bash
singularity search fastp
```

Espera, parece que Singularity no está disponible... Así es, porque para mantener la reproducibilidad los HPC no tienen tanto software instalado a nivel de sistema.
En nuestro caso, Singularity se accede a través de **módulos de EasyBuild**:

```bash
module load singularity
singularity search fastp

"Output
Found 6 container images for amd64 matching "fastp":

        library://abourdais/default/fastplast:lastest

        library://edwardbirdlab/fastp/fastp:1.0

        library://hud/mgnext/fastp:0.20.1

        library://jiayiliujiayi/condas/fastp:0.23.2

        library://marcniebel/repo/fastp:1.0.0

        library://wallaulabs/viralflow/fastp:0.23.4
"
```

- Estos son repositorios comunitarios de singularity. Como podéis ver las versiones están muy limitadas y no todas las ubicaciones están contrastadas. Nosotros recomendamos otras opciones, especialmente pensadas para software científico, que veremos en el siguiente punto.

### 3.1 Descargar y ejecutar un contenedor de Singularity

Existen muchos repositorios de contenedores, siendo [https://hub.docker.com](https://hub.docker.com) el más común. Para herramientas bioinformáticas recomendamos:

- [galaxy index](https://depot.galaxyproject.org/singularity/)
- [biocontainers registry](https://biocontainers.pro/registry)
- [sequera containers](https://seqera.io/containers/)

El comando `singularity run` ya descarga la imagen antes de ejecutarla, lo cual usaremos en este ejercicio para correr un contenedor de fastp directamente desde el repositorio de Galaxy.

**Cómo usar `singularity run/exec`:**

`singularity run` iniciará una sesión en el container y ejecutará la acción por defecto programada en él si la hubiere.

```bash
singularity run https://depot.galaxyproject.org/singularity/fastp%3A1.0.1--heae3180_0 
# Ahora estaremos dentro del container, ya que esta imagen no tiene proceso de inicio.
# Podemos probar a lanzar fastp para ver que está disponible en el container 
fastp --help
exit # Salir del container. También con ctrl+D
```

En contraparte tenemos `singularity exec`, que permite configurar lo que queremos que se ejecute con el container, sin iniciar una sesión en él, pero aprovechándonos de todas las dependencias que se encuentren instaladas dentro. Ejemplo:

```bash
singularity exec https://depot.galaxyproject.org/singularity/fastp%3A1.0.1--heae3180_0 fastp --help
```

Si queremos simplemente descargar la imagen para tenerla accesible en local, podemos utilizar `singularity pull`:

```bash
cd /data/courses/hpc_course/*_HPC-COURSE_${USER}/ANALYSIS/
mkdir -p 06-software-management/singularity_images 06-software-management/singularity_cache
singularity pull 06-software-management/singularity_images/fastp.img https://depot.galaxyproject.org/singularity/fastp%3A1.0.1--heae3180_0
```

Como ya sabéis, siempre es mejor lanzar los trabajos con `srun`. Lo mismo aplica para procesos con containers:

```bash
cd 06-software-management
srun --partition=short_idx --cpus-per-task=1 --mem=2G --time=00:05:00 singularity exec \
--bind /data/courses/hpc_course/*_HPC-COURSE_${USER} \
./singularity_images/fastp.img fastp -i ../00-reads/virus1_R1.fastq.gz -I ../00-reads/virus1_R2.fastq.gz -o trimmed_virus1_R1.fastq.gz -O trimmed_virus1_R2.fastq.gz
```

Al hacer `--bind <PATH>`, lo que pongamos en `<PATH>` será accesible dentro del contenedor. Por ejemplo en este caso `/scratch/hpc_course/<CARPETA_HPC_COURSE>` será accesible en el contenedor. 

### 3.2 Otros conceptos importantes sobre singularity

Singularity utiliza por defecto dos variables para el guardado de cache (imagenes guardadas al lanzar exec y run) y imagenes (pull). En este caso, podemos modificarlas por defecto configurando nuestro ``~/.bashrc``:

```bash
# Añadiremos estas lineas a nuestro ~/.bashrc
export SINGULARITY_CACHEDIR=/scratch/hpc_course/<CARPETA_HPC_COURSE>/ANALYSIS/06-software-management/singularity_cache
export SINGULARITY_PULLFOLDER=/scratch/hpc_course/<CARPETA_HPC_COURSE>/ANALYSIS/06-software-management/singularity_images/
```

Después, hacemos `source ~/.bashrc` para aplicar los cambios y a partir de ahora nuestras imagenes serán descargadas ahi y singularity buscará automáticamente imágenes en guardadas en `SINGULARITY_CACHEDIR` antes de descargar nuevas.
**Nota**: Al igual que lo explicado con micromamba, con singularity también es posible compartir ubicación de imagenes o containers. Si por ejemplo nos coordináramos entre usuarios para usar una misma carpeta compartida, podríamos tener todos acceso a las mismas imágenes de singularity.

- Para uso únicamente interactivo dentro de una imagen, ejecuta:

  ```bash
  singularity shell /path/to/image
  ```

- Puedes **configurar y crear tu propio contenedor vía web** fácilmente con [https://seqera.io/containers](https://seqera.io/containers).
  Solo busca cada dependencia y añádela a la lista, luego haz clic en **"Get Container"** y espera a que la imagen esté lista. Una vez completado, puedes usarla con:

  ```bash
  singularity run <container_url>
  ```

- Si quieres aprender más sobre cómo crear tu propio contenedor, recomendamos revisar la documentación de [singularity build](https://docs.sylabs.io/guides/3.0/user-guide/build_a_container.html) y [docker build](https://docs.docker.com/get-started/workshop/02_our_app/) para conocer todas las especificaciones necesarias.
