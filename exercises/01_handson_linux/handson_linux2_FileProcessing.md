# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 2: Manejo y gestión de ficheros

### Descripción

Uno de los puntos fuertes de los sistemas Linux estriba en la facilidad con la que se analizan los ficheros de texto. Estos sistemas incluyen una serie de herramientas que permiten realizar una gran cantidad de manipulaciones en estos ficheros sin necesidad de instalar ninguna herramienta especializada.

### Notas importantes

* Usa el tabulador para guiarte en la terminal y autocompletar nombres de ruta, archivos y comandos (el tabulador es tu mejor aliado).
* Usa las flechas del teclado para moverte por el historial de comandos ejecutados (podrás reutilizarlos sin volver a escribirlos).
* No es aconsejable usar espacios, tildes ni caracteres especiales como la "ñ" en los nombres de archivos o directorios.
* Comandos básicos que siempre debes recordar: `pwd`, `cd`, `ls`, `mkdir`, `mv`, `rm`, `rmdir`, `less`, `nano`.

### Ficheros de texto y binarios

Antes de comenzar a analizar este tipo de ficheros hay que aclarar qué es y qué no es un fichero de texto. Un fichero de texto es un fichero dividido en líneas y cuyo contenido es texto. A pesar de lo que pudiese parecer a priori, un documento de Microsoft Office o de LibreOffice no es un fichero de texto. La información contenida en estos documentos es binaria y sólo los programas especialmente creados para abrir estos ficheros pueden acceder a ella de un modo inteligible. En un documento como en un fichero Word además de texto se guarda la información sobre el formato, imágenes, tablas, etc... Por el contrario en un fichero de texto sólo hay caracteres alfanuméricos (letras y números), retornos de carro y tabuladores.

Los ficheros de texto pueden ser abiertos e inspeccionados sin necesidad de hacer uso de un software especial diseñado para trabajar con ellos. Un documento Word no puede ser leído sino tenemos el Office o LibreOffice instalado pero un fichero de texto se puede ver y editar con las herramientas que vienen instaladas por defecto en el sistema operativo.

Estas herramientas de manejo de ficheros de texto permiten realizar complejas manipulaciones de un modo muy sencillo y son uno de los principales atractivos de los sistemas Linux para el manejo de grandes cantidades de información.

Para esta práctica se va a usar el fichero microarray_adenoma_hk69.csv. En este fichero están almacenados los resultados de un experimento de expresión diferencial en el que se han analizado distintos adenomas.

Este es un fichero tabular en el que la información se representa dividiendo los campos mediante tabuladores (formato tabla). En este caso cada fila del fichero corresponde a una sonda de microarray y cada columna a una propiedad sobre la sonda o sobre el resultado de la hibridación sobre ella.

Lo primero que podemos hacer con un fichero de texto es abrirlo para ver sus contenidos. Existen editores de texto que funcionan en ventanas, como gedit, y editores que funcionan en la terminal, como nano. Por desgracia a veces los ficheros con los que vamos a trabajar son tan grandes que incluso los buenos editores de texto pueden tener problemas para abrirlos. Otra forma de acceder a los contenidos del fichero es visualizarlo en la terminal utilizando el comando cat.

### Ejercicios

#### 1. Obtener el fichero para trabajar

```bash
cd
pwd
ls
mkdir practica_ficheros
cd practica_ficheros
wget https://plantgenomics.es/edu/linux/_downloads/9bce0e4eba7e74591baab487df7ca394/microarray_adenoma_hk69.csv
```

`wget` es un comando que nos permite obtener un archivo a partir de una URL de internet y nos lo descarga.

#### 2. Leer el contenido de un archivo

1. cat
2. head
3. tail
4. less

```bash
cat microarray_adenoma_hk69.csv
```

Al hacerlo la terminal quedará bloqueada durante bastante tiempo puesto que el fichero es muy grande.

> **Nota**: Si habéis ejecutado el comando anterior y ahora queréis terminar (o matar) el programa que está ejecutándose en el terminal (en este caso cat) podéis utilizar la combinación de teclas `Ctrl + c`. Esto suele hacer que los programas terminen lo que estén haciendo inmediatamente, se apaguen y vuelva a mostrarse el prompt.

Para abrir ficheros de texto inmensos sin problemas se usan los comandos more o less. No se puede editar el fichero, pero sí navegar por su contenido. Son programas interactivos por lo que cuando se ejecute se abrirá ocupando el terminal y haciendo desaparecer el prompt. En cualquier momento se puede salir pulsando la tecla “q”.

```bash
less microarray_adenoma_hk69.csv
# q para salir
```

Para hacerse una idea del contenido del fichero sin bloquear la terminal se puede mostrar en pantalla tan solo una parte utilizando los comandos head o tail.

```bash
head microarray_adenoma_hk69.csv
tail microarray_adenoma_hk69.csv
tail -n 2 microarray_adenoma_hk69.csv
head -n 4 microarray_adenoma_hk69.csv
```

<details>
<summary>PREGUNTA: ¿Qué hace el comando <code class="code-inline">head</code> sin parámetros?</summary>

Muestra las primeras 10 filas de un archivo de texto.
</details>

<details>
<summary>PREGUNTA: ¿Qué hace el comando <code class="code-inline">tail</code> sin parámetros?</summary>

Muestra las ultimas 10 filas de un archivo de texto.
</details>

<details>
<summary>PREGUNTA: ¿Qué hace el parámetro <code class="code-inline">-n</code> sobre el comportamiento normal de head y tail?</summary>

El parámetro `-n` sirve para indicar el número de lineas que se quieren mostrar con `head` y `tail` en lugar de las 10 que se muestran por defecto.
</details>

#### 3. Buscar patrones

En archivos de texto a veces necesitamos localizar rápidamente las líneas que contienen cierto tipo de identificador, o localizar una entrada en particular. Esto lo podemos hacer fácilmente con el comando grep, que busca en el archivo una expresión regular o cadena de caracteres determinada y devuelve las líneas que la contienen. Una expresión regular es una secuencia de caracteres que forman un patrón de búsqueda, como pueden ser nuestro ya conocidos ‘*’ para expresar cualquier cadena de caracteres.

Grep también posee cantidad de opciones que modifican su funcionamiento de diversas maneras:
- `-v`: Devuelve las líneas que no contienen el patrón de búsqueda
- `-r`: se usa en lugar de indicar un archivo en el que buscar y sirve para buscar en todos los archivos del directorio de trabajo
- `-i` ignora las mayúsculas o minúsculas
- `-w` busca solo palabras enteras
- `–n` que devuelve el número de la línea donde encuentra el resultado de la búsqueda.

```bash
grep -w Experiment microarray_adenoma_hk69.csv
```

#### 4. Contar líneas, palabras y caracteres

El comando `wc` sirve para contar diversos elementos de un archivo:
- `l`: Permite contar cuántas líneas tiene un archivo, lo que es indispensable para saber las dimensiones d datos con las que trabajas
- `-m`: Para contar caracteres
- `-w`: Para contar palabras
- `-c`: Para contar bytes

```bash
wc -l microarray_adenoma_hk69.csv
```

<details>
<summary>PREGUNTA: ¿Cuántas lineas tiene el archivo <code class="code-inline">microarray_adenoma_hk69.csv</code>?</summary>

24212
</details>

#### 5. Seleccionar campos de una tabla

Si el fichero está dividido en campos (como en el caso de la tabla usada en la práctica), se pueden seleccionar campos de la tabla (comando `cut`)

Las tablas con las que se suele trabajar en bioinformática son demasiado grandes para que Excel pueda abrirlas, por lo que hay que utilizar otras herramientas para trabajar con ellas. Una de las más comunes para su exploración es `cut`, que nos permite escoger determinadas columnas. En combinación con grep (u otras herramientas que seleccionan filas rápidamente) podemos extraer información útil de grandes tablas de datos. El comando `cut` permite las opciones:
- `-f`: (field) Para indicar el número de columna a extraer (pueden ser rangos o listas separadas por comas) y
- `-d`: (delimiter) Para especificar el separador de campos en el archivo de texto (el tabulador es el separado por defecto y no hace falta especificarlo).

Recordemos que un pipe (símbolo `|`) en Linux es una herramienta que permite conectar la salida de un comando con la entrada de otro. Esto nos permite encadenar comandos para realizar operaciones más complejas de forma sencilla.

Si quieremos buscar la palabra Experiment completa en el archivo `microarray_adenoma_hk69.csv` y después seleccionar el segundo campo empleando como delimitador el símbolo de `=`.

```bash
grep -w Experiment microarray_adenoma_hk69.csv
grep -w Experiment microarray_adenoma_hk69.csv | cut -f 2 -d'='
```

#### 6. Ordenar el contenido del fichero

Con el comando `sort` podemos ordenar una tabla de texto por una de sus columnas, ya sea alfabéticamente en caso de campos de caracteres o en orden ascendente o descendente en caso de numéricos. Para ello, se vale de las opciones:
- `-k`: número de columna por la que ordenar
- `-n`: especifica que la columna contiene números y no caracteres
- `-r`: ordenar en orden inverso
- `-u`: eliminar duplicados y mostrar solo elementos únicos

Vamos a coger las 10 primeras lineas del archivo y a ordenarlas por orden alfabético reverso de la primera columna.

```bash
head microarray_adenoma_hk69.csv | sort -k1 -r
```

#### 7. Reemplazar caracteres

También podemos eliminar algunos caracteres commo las comillas que rodean los campos. Esta tarea podemos realizarla con el comando `sed` (stream editor). `sed` toma las líneas de una en una, les aplica la transformación que le indiquemos y devuelve las líneas modificadas. Por ejemplo, eliminemos los punto y coma del resultado anterior:

```bash
head microarray_adenoma_hk69.csv | sort -k1 -r | sed "s/;//g"
```

#### Ejercicios finales

1) Saber cuál es la expresión de los genes relacionados con la leucemia en el fichero del microarray. Para ello buscaremos en el archivo las líneas que contienen leukemia ignorando diferencias entre mayúsculas y minúsculas. Si las líneas que coinciden con el patrón son muchas, usar una tubería ( | ) y pasar la salida del comando grep como entrada al comando less o more.

2) Buscar la palabra leukemia en todos los ficheros presentes el directorio home (/home/usuario).

3) ¿Qué posiciones del fichero están las líneas que cumplen con el patrón leukemia?

4) Buscar la palabra leukemia en las primeras cien líneas del fichero.

5) Buscar la palabra leukemia en las primeras cien líneas del fichero y guardar el resultado en un fichero.

6) Como el contenido del fichero está dividido en campos, seleccionar de la búsqueda anterior solo el nombre y la descripción del gen.

7) Ordenar alfabéticamente los genes relacionados con la leucemia.

8) Contar cuantos genes relacionados con la leucemia hay en el fichero.

<i>Nota: Recordad usar los comandos pwd, cd y ls para conocer vuestra localización, moveros entre directorios y listar el contenido de los directorios respectivamente. Necesitaréis ir al directorio donde se encuentra el archivo ‘microarray_adenoma_hk69.csv’ para poder trabajar con él más fácilmente.</i>

#### Soluciones

```bash
#1
grep -i leukemia microarray_adenoma_hk69.csv | less
----------------------------------------------------
#2
grep -r leukemia ~/* #o grep –r leukemia
----------------------------------------------------
#3
grep -n leukemia microarray_adenoma_hk69.csv | cut -f 1 -d':'
----------------------------------------------------
#4
head -n 100 microarray_adenoma_hk69.csv | grep leukemia
----------------------------------------------------
#5
head -n 100 microarray_adenoma_hk69.csv | grep leukemia > busqueda_leukemia_100.txt
----------------------------------------------------
#6
cat busqueda_leukemia_100.txt | cut -f 3,4
----------------------------------------------------
#7
grep leukemia microarray_adenoma_hk69.csv | cut -f 3,4 | sort
----------------------------------------------------
#8
grep leukemia microarray_adenoma_hk69.csv | cut -f 3,4 | sort -u | wc -l
```

> **PODEMOS ELIMINAR EL ARCHIVO DE MICROARRAY PARA EVITAR ALMACENAR ARCHIVOS INNECESARIAMENTE**
> `rm microarray_adenoma_hk69.csv`

### Nota final

* Podéis practicar estos ejercicios en cualquier ordenador, ya que estos comandos son universales y funcionan en toda máquina linux y similares, incluyendo macs y WSL.

* La manera más sencilla de practicarlos sin instalar nada es vía <http://www.webminal.org/>. En esta web puedes crearte un usuario de forma gratuita y abrir una terminal en una máquina remota, todo a través de vuestro explorador web. También contiene tutoriales complementarios que os pueden servir para afianzar lo aprendido hoy o repasar los comandos cuando tengáis necesidad de usarlos.

* Como alternativa podéis usar <http://copy.sh/v86/?profile=archlinux>, aunque esta carece de tutoriales.

```
Visita Webminal o copy.sh para practicar en casa: http://www.webminal.org/ o http://copy.sh/v86/?profile=archlinux
```
