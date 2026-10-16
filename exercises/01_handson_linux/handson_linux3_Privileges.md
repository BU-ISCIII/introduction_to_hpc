# Curso Práctico de Iniciación al uso del Entorno de Alta Computación

BU-ISCIII

## Práctica 3: Usuarios y permisos

### Descripción

Al copiar o mover ficheros y/o directorios dentro del sistema o desde servidores de ficheros (FTP, samba, ...), tanto los permisos como propietario o grupo de esos ficheros, no siempre son los correctos para poder manipularlos.

El objetivo de la práctica es realizar desde la línea de comandos cambios en las características de los ficheros y/o directorios para que nuestro usuario del sistema pueda procesarlos y/o visualizarlos.

Los permisos se representan en grupos de tres letras:

| Letra | Significado         | Valor  |
|-------|---------------------|--------|
| r     | read (leer)         | 4      |
| w     | write (escribir)    | 2      |
| x     | execute (ejecutar)  | 1      |
| -     | sin permiso         | 0      |

Cada grupo (usuario, grupo, otros) se traduce a un número del 0 al 7, sumando los valores.

Por ejemplo:

- rwx = 4 + 2 + 1 = 7
- rw- = 4 + 2 + 0 = 6
- r-- = 4 + 0 + 0 = 4

Entonces, los permisos rwxr-xr-x se representan como 755

### Notas importantes

* Usa el tabulador para guiarte en la terminal y autocompletar nombres de ruta, archivos y comandos (el tabulador es tu mejor aliado).
* Usa las flechas del teclado para moverte por el historial de comandos ejecutados (podrás reutilizarlos sin volver a escribirlos).
* No es aconsejable usar espacios, tildes ni caracteres especiales como la "ñ" en los nombres de archivos o directorios.
* Comandos básicos que siempre debes recordar: `pwd`, `cd`, `ls`, `mkdir`, `mv`, `rm`, `rmdir`, `less`, `nano`.

### Ejercicios

#### 1. Creamos la estructura de carpetas para la práctica

1. Crear un directorio que se llame `practica_permisos`
2.  Dentro de `practica_permisos` crear otro directorio que se llame `copia_etc`
3. Copiar todos los ficheros que empiecen por `ho` desde el directorio `/etc/` al directorio `copia_etc` (usad el parámetro -v para ver el proceso de copia).

```bash
cd
pwd
ls
mkdir practica_permisos
cd practica_permisos
pwd
mkdir copia_etc
cd copia_etc
pwd
cp -v /etc/ho* ./ # (El punto “.” Indica que se copie en el directorio en el que te encuentras ubicado.)
```

#### 2. Listar el contenido y visualizar los permisos del directorio `copia_etc`

```bash
pwd
ls
ll # ls -l
```

El comando `ll` es lo mismo que escribir `ls -l`.

<details>
<summary>PREGUNTA: ¿Cuáles son los permisos del archivo <code class="code-inline">host.conf</code>?</summary>

Sabemos que es un archivo de texto porque no empieza por `d`, el usuario propietario tiene permisos de lectura y escritura, pero no de ejecución. El grupo tiene permisos de lectura, pero no de escritura ni ejecución, y el resto de usuarios tienen permiso de lectura pero no de escritura ni ejecución, el usuario propietario es tu usuario, el grupo es también tu usuario porque está en tu home, ocupa 9 bytes y fue modificado por ulima vez ahora mismo.
</details>

#### 3. Añadir permisos

1. Añadir permisos de escritura al grupo y resto de usuarios a todos los archivos que empiezan por `ho`
2. Listar el contenido y visualizar los permisos para ver los cambios

```bash
pwd
chmod go+w ho* #o chmod 666 ho*
ll #o ls -l
```

#### 4. Cambiar el grupo

1. Cambiar el grupo de los ficheros que empiece por `ho` al grupo `hpccourse`
2. Listar el contenido y visualizar para ver los cambios.

```bash
pwd
chgrp hpccourse ho*
ll #o ls -l
```

#### 5. Cambiar el propietario

1. Cambiar el propietario de los ficheros que empiece por `ho` a `root`
2. Listar el contenido y visualizar para ver los cambios

```bash
pwd
chown root ho*
ll #o ls -l
```

#### 6. Cambiar el grupo y el propietario al mismo tiempo

```bash
ll
chown -R <tu_usuaruio>:<tu_usuaruio> .
ll
```

El parámetro `-R` indica al `chown` que trabaje de forma recursiva sobre todos los ficheros de un directorio.

#### 7. Quitar permisos

1. Quitar todos los permisos al `resto de usuarios` (tercer bloque de permisos), de todos los ficheros dentro de ‘copia_etc’.
2. Listar el contenido y visualizar los permisos para ver los cambios.

```bash
pwd
chmod o-rwx * #o chmod 660 *
ll #o ls -l
```

#### 8. Limpiamos la carpeta del home

Eliminar el directorio ‘practica_permisos’ y todo su contenido

```bash
pwd
cd
pwd
ls
rm -rf practica_permisos
ls
```

### Nota final

* Podéis practicar estos ejercicios en cualquier ordenador, ya que estos comandos son universales y funcionan en toda máquina linux y similares, incluyendo macs y WSL.

* La manera más sencilla de practicarlos sin instalar nada es vía <http://www.webminal.org/>. En esta web puedes crearte un usuario de forma gratuita y abrir una terminal en una máquina remota, todo a través de vuestro explorador web. También contiene tutoriales complementarios que os pueden servir para afianzar lo aprendido hoy o repasar los comandos cuando tengáis necesidad de usarlos.

* Como alternativa podéis usar <http://copy.sh/v86/?profile=archlinux>, aunque esta carece de tutoriales.

```
Visita Webminal o copy.sh para practicar en casa: http://www.webminal.org/ o http://copy.sh/v86/?profile=archlinux
```


