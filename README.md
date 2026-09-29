Prácticas de aula 3 (PA03). Procesa datos GNSS y obtén soluciones
fijas<small><br>Geomorfología (GEO-114)<br>Universidad Autónoma de Santo
Domingo (UASD)</small>
================
El Tali
2026-08-31

Versión HTML (quizá más legible),
[aquí](https://geomorfologia-master.github.io/datos-gnss-soluciones-fijas/README.html)

<img src="img/paresen_felise.jpg" style="width:50.0%" /><br> **Foto:
José Gabriel Almánzar/Christian Gómez**. El trabajo de campo en el
campus no es que sea “campo a través”, pero parece que pone a la gente
contenta.

# Fecha/hora de entrega

**Ver portal de la asignatura**

# Objetivos

1.  **Familiarizarse con un flujo reproducible de procesamiento GNSS**:
    convertir observaciones crudas a RINEX, preparar observaciones
    estáticas de una base, obtener de forma independiente una coordenada
    precisa mediante PPP y utilizarla posteriormente para PPK.

2.  **Evaluar la calidad de datos GNSS crudos**: mediante inspección de
    los archivos RINEX y herramientas de RTKLIB-EX, identificar
    problemas como interrupciones, saltos de ciclo (*cycle slips*),
    geometría desfavorable o pérdida de observaciones.

3.  **Comprender el papel del marco de referencia y de la época de las
    coordenadas**: interpretar correctamente una solución PPP expresada
    en ITRF/IGS y su época, y comprender por qué **no es necesario
    transformar dicha coordenada al WGS84 original (Transit) para
    realizar el PPK con RTKLIB-EX** cuando la coordenada PPP y las
    observaciones corresponden a la misma época y se emplean productos
    GNSS modernos.

4.  **Obtener de manera independiente la coordenada precisa de la
    base**: cada estudiante preparará las observaciones estáticas de la
    base y enviará personalmente el RINEX resultante a un servicio
    PPP/posprocesamiento como CSRS-PPP de NRCan, OPUS o AUSPOS.

5.  **Generar soluciones fijas mediante PPK**: procesar aproximadamente
    120 segundos de observaciones tomadas en un mismo punto del campus
    con dos tipos de rover, Unicore (triple frecuencia) y u-blox (doble
    frecuencia), y comparar los resultados.

6.  **Documentar el flujo mediante código reproducible**: aunque
    RTKLIB-EX dispone de interfaces gráficas, se priorizará el uso de
    `convbin`, `rnx2rtkp` y `gfzrnx` desde scripts ejecutables y
    documentados en este cuaderno.

# Recursos

- [**Carpeta de Drive con archivos fuente de la práctica (base y
  rovers)**](https://drive.google.com/drive/folders/1QwhfmtxwDR04yZ38Cwc9Fkcq6g_mmFg0?usp=drive_link)

- Software:

  - [RTKLIB-EX, antiguamente
    “Demo5”](https://github.com/rtklibexplorer/RTKLIB/releases). Usa la
    versión más reciente disponible. RTKLIB-EX proporciona tanto
    aplicaciones con interfaz gráfica como programas equivalentes para
    terminal: RTKCONV/`convbin` para conversión y RTKPOST/`rnx2rtkp`
    para posproceso.

  - [GFZRNX](https://gnss.gfz.de/services/gfzrnx), herramienta para
    comprobar, manipular, unir, dividir, seleccionar y diezmar archivos
    RINEX. Existen ejecutables para Windows y GNU/Linux. Si prefieres
    trabajar en un entorno Linux desde Windows, puedes usar WSL
    (*Windows Subsystem for Linux*).

> **Preferencia de esta práctica:** puedes utilizar RTKCONV y RTKPOST
> para explorar las opciones y comprobar visualmente configuraciones,
> pero el procesamiento que reportes debe quedar reproducible. Por ello,
> es preferible ejecutar `convbin`, `gfzrnx` y `rnx2rtkp` mediante
> scripts y conservar dichos scripts en tu repositorio.

# Datos y geometría de la práctica

Cada estudiante dispone de dos colectas cortas realizadas
aproximadamente durante **120 segundos en el mismo punto del campus de
la UASD**:

- una colecta con rover **Unicore**, receptor GNSS de triple frecuencia;
- una colecta con rover **u-blox**, receptor GNSS de doble frecuencia.

Durante la ocupación se utilizó un **jalón** de aluminio. Te facilitaré
la altura empleada y la información necesaria de las antenas. Es
importante distinguir:

- **ARP (*Antenna Reference Point*)**: punto físico de referencia de la
  antena respecto del cual se mide normalmente la altura instrumental o
  del jalón;
- **PCO (*Phase Center Offset*)**: vector que relaciona el ARP con el
  centro de fase medio de una señal/frecuencia;
- **APC (*Antenna Phase Center*)**: centro de fase efectivo, que depende
  de la señal y puede variar con la dirección de llegada de la señal.

Por tanto, **no debes inventar una corrección APC** ni restar
automáticamente la longitud del jalón a una coordenada. Te proporcionaré
la altura ARP–marca y, cuando corresponda, el tipo/modelo de antena o
sus parámetros de calibración (PCO/PCV). Deberás declarar en tu informe
qué punto representa finalmente tu solución: ARP o marca/punto del
terreno.

# Ejercicio 1. Descarga tus datos, conviértelos, evalúa su calidad, descríbelos

- Descarga desde la [**carpeta de Drive con archivos fuente de la
  práctica (base y
  rovers)**](https://drive.google.com/drive/folders/1QwhfmtxwDR04yZ38Cwc9Fkcq6g_mmFg0?usp=drive_link)
  tus dos colectas de rover y los archivos horarios correspondientes a
  la base.

- Organiza el proyecto, por ejemplo (no está así estructurado en la
  carpeta de Drive, y esto es sólo una sugerencia, puedes organizar como
  prefieras, pero siguiendo un orden):

``` text
gnss/
├── raw/
│   ├── base/
│   └── rover/
├── rinex/
│   ├── base/
│   └── rover/
├── ppp/
├── ppk/
└── scripts/
```

## Convierte a RINEX

Convierte las observaciones crudas (*raw*) a **RINEX 3.04**. Los
archivos crudos contienen observables GNSS (pseudorango, fase portadora,
Doppler, SNR, etc.) y mensajes de navegación/efemérides transmitidas.

En esta práctica encontrarás dos familias de receptores:

- **Unicore UM980** (triple frecuencia): archivos extensión `.log`. La
  versión reciente de RTKLIB-EX utilizada en la asignatura permite
  convertir correctamente los archivos crudos Unicore (triple
  frecuencia) mediante RTKCONV o `convbin`. En versiones anteriores esta
  compatibilidad era incompleta, razón por la cual en prácticas antiguas
  se recurría al programa propietario Converter de Unicore.
- **u-blox ZED-F9P** (doble frecuencia): los archivos `.ubx` son
  compatibles con RTKLIB desde hace mucho tiempo y pueden convertirse
  mediante RTKCONV o `convbin`.

Para fines de comprobación, los detalles sobre hora exacta de colecta
(hora GPS), persona que colectó y tipo de receptor) fueron facilitados
vía el foro; transcribo dicha información a continuación:

GPS time

- Talibán
  - Triple: 15:03:10
  - Doble: 15:19:49
- Buanerges
  - Triple: 15:32:04
  - Doble 15:38:59
- Juancito
  - Triple 15:45: 36
  - Doble 16:00:12
- Rosamalia
  - Triple 16:07:16
  - Doble 16:13:13
- Yeral
  - Triple 16:19:29
  - Doble 16:27:58
- Camila
  - Triple 16:35:00
  - Doble 16:42:08

Puedes realizar una primera conversión con RTKCONV para familiarizarte
con las opciones, pero debes dejar documentada una conversión
reproducible con `convbin`.

Ejemplo general para u-blox:

``` bash
convbin -r ubx -v 3.04 \
  -o rinex/rover/rover_ublox.obs \
  -n rinex/rover/rover_ublox.nav \
  raw/rover/rover_ublox.ubx
```

Para Unicore, consulta primero la ayuda de **la versión de RTKLIB-EX
instalada**:

``` bash
convbin -h
```

y usa el formato de entrada Unicore que reconozca esa versión. No copies
mecánicamente una opción `-r` de versiones antiguas: documenta en el
cuaderno el comando que realmente utilizaste y la versión de `convbin`.

> **Importante:** revisa el encabezado y algunas épocas del RINEX
> resultante. La conversión no debe considerarse correcta sólo porque el
> programa haya producido un archivo.

## Evalúa la calidad

- Realiza una inspección visual de los RINEX de la base y de ambos
  rovers.
- Comprueba fechas, horas, intervalo, constelaciones, tipos de
  observación y continuidad.
- Usa RTKPLOT u otra herramienta de RTKLIB-EX para inspeccionar
  disponibilidad de satélites, DOP, interrupciones y posibles *cycle
  slips*.
- Para los RINEX Unicore, presta atención a `SYS / # / OBS TYPES` y
  `SYS / PHASE SHIFT`. Si un servicio PPP emite advertencias
  relacionadas con *phase alignment*, no supongas automáticamente que el
  problema se corrige escribiendo ceros en `SYS / PHASE SHIFT`:
  documenta la advertencia y comprueba los observables realmente
  presentes.

# Ejercicio 2. Prepara las observaciones de la base y obtén TU solución PPP

## Une los archivos horarios de la base

La base fue registrada en archivos horarios. **Cada estudiante debe
construir por sí mismo el RINEX continuo que enviará al servicio PPP**.

Usa `gfzrnx` para unir (*splice*) los RINEX horarios. El patrón exacto
de nombres dependerá de los archivos descargados. Por ejemplo:

``` bash
gfzrnx -finp "rinex/base/*.obs" \
  -fout ppp/base_unida_01s.obs
```

Si tu versión o sistema operativo trata los comodines de manera
diferente, consulta:

``` bash
gfzrnx -h
```

y documenta la sintaxis finalmente utilizada.

Después de unirlos, comprueba que el archivo resultante contiene una
serie temporal continua y que las horas inicial y final son las
esperadas.

## Reduce la cadencia a 30 segundos

Para el envío PPP no necesitamos conservar una observación por segundo.
Genera una copia a **30 s**. GFZRNX puede realizar el remuestreo:

``` bash
gfzrnx -finp ppp/base_unida_01s.obs \
  -fout ppp/base_unida_30s.obs \
  -smp 30
```

También puedes realizar el diezmado con `convbin` leyendo el RINEX y
usando `-ti 30`. Por ejemplo:

``` bash
convbin -r rinex -v 3.04 -ti 30 \
  -o ppp/base_unida_30s_convbin.obs \
  ppp/base_unida_01s.obs
```

No es obligatorio aplicar **ambos** procedimientos. Elige uno, pero
debes demostrar de manera reproducible que el archivo enviado tiene una
cadencia de 30 s.

### Comprobaciones reproducibles

Incluye comandos que permitan demostrar, como mínimo:

1.  cuántos archivos horarios recibiste;
2.  que fueron unidos;
3.  fecha/hora de primera y última observación;
4.  que el RINEX final tiene intervalo de 15 s;
5.  tamaño y nombre del archivo finalmente enviado.

Puedes complementar `gfzrnx` con comandos del sistema (`ls`, `wc`,
`grep`, etc.) y mostrar sus salidas en el cuaderno.

## Obtén una solución independiente para la coordenada de la base

**Cada estudiante deberá enviar personalmente su RINEX de 30 s a uno de
estos servicios y conservar el informe de salida:**

- CSRS-PPP, Natural Resources Canada (NRCan);
- OPUS, National Geodetic Survey (NGS/NOAA);
- AUSPOS, Geoscience Australia.

El servicio elegido puede imponer requisitos particulares de duración,
constelaciones, tipo de antena o formato. Debes revisar dichos
requisitos antes del envío.

Registra en el informe:

- servicio utilizado;
- archivo RINEX enviado;
- intervalo de observación;
- duración total;
- modo de procesamiento;
- marco de referencia de la solución;
- **época de la coordenada**;
- coordenadas LLH y/o XYZ;
- incertidumbres reportadas;
- tratamiento de la antena y de la altura instrumental;
- advertencias emitidas por el servicio.

> **No uses una coordenada PPP facilitada por otra persona.** El
> objetivo es que cada estudiante complete y documente todo el flujo
> desde los archivos horarios hasta una solución PPP propia.

## Marco de referencia: no transformes la solución a WGS84 (Transit)

En versiones anteriores de esta práctica se pedía transformar la
coordenada ITRF obtenida mediante PPP a **WGS84 original (Transit)**
usando HTDP. **No hagas esa transformación.**

Una solución PPP moderna puede estar expresada, por ejemplo, en
**ITRF2020/IGS20 a la época de las observaciones**. ITRF es un marco
dinámico: no basta con conocer el nombre del marco, también importa la
época de la coordenada.

RTKLIB-EX utiliza coordenadas cartesianas/geodésicas y los marcos
implícitos en las órbitas empleadas, pero no necesita que una coordenada
PPP moderna y coherente con la época de observación sea artificialmente
transformada al WGS84 original (Transit). En esta práctica:

- la coordenada PPP de la base debe corresponder a la época de las
  observaciones;
- base y rover se observaron en la misma campaña;
- para PPK con efemérides transmitidas (*broadcast*) se utilizará
  directamente la coordenada PPP moderna de la base;
- si posteriormente se usan productos precisos SP3/CLK modernos, éstos
  se encuentran alineados con realizaciones IGS/ITRF modernas, lo que
  refuerza la necesidad de **conservar y documentar el marco y la
  época**, no de convertir a WGS84 Transit.

Por tanto, en tu informe escribe explícitamente algo como:

> *La coordenada de la base se obtuvo mediante PPP en \[marco\] a la
> época \[época\]. Se utilizó directamente como coordenada fija de la
> base en el PPK; no se realizó una transformación a WGS84 (Transit).*

# Ejercicio 3. Genera soluciones fijas PPK y evalúa el resultado

## Prepara la configuración reproducible de RTKLIB-EX

Puedes explorar la configuración mediante RTKPOST, pero el procesamiento
final debe poder repetirse con `rnx2rtkp`.

Una forma cómoda de trabajar consiste en configurar RTKPOST, guardar la
configuración y reutilizar ese archivo con `rnx2rtkp`. Conserva el
archivo de configuración en tu repositorio, por ejemplo:

``` text
scripts/ppk.conf
```

Documenta, como mínimo:

- modo de posicionamiento;
- frecuencias utilizadas;
- constelaciones;
- máscara de elevación;
- estrategia de resolución de ambigüedades;
- modelo ionosférico y troposférico;
- efemérides empleadas (`broadcast` o precisas, si posteriormente
  repites el ejercicio);
- coordenada fija de la base, con marco y época;
- información de antena;
- altura ARP–marca o corrección aplicada;
- formato de salida.

## Antena, ARP, PCO/APC y jalón

La altura del jalón **no debe tratarse como una corrección genérica de 2
m**. Usa la altura que se te proporcione para esta campaña y deja claro
entre qué puntos fue medida.

Para el rover, la observación GNSS está físicamente relacionada con el
centro de fase de la antena, mientras que el punto que normalmente
interesa levantar está en la base del jalón. RTKLIB puede aplicar
correcciones de antena cuando dispone de la información apropiada. Te
facilitaré el modelo de antena y/o los parámetros necesarios.

En el informe distingue:

- punto del terreno o marca;
- ARP;
- altura ARP–marca;
- PCO/PCV cuando se suministren;
- punto al cual corresponde la coordenada final reportada.

## Genera las soluciones

Tienes dos rovers observados aproximadamente durante 120 s en el mismo
punto:

1.  rover **u-blox**;
2.  rover **Unicore**.

Ambos se procesarán respecto de **la misma base cuya coordenada
obtuviste personalmente mediante PPP**.

Un comando reproducible tendrá esta estructura general:

``` bash
rnx2rtkp -k scripts/ppk.conf \
  -o ppk/rover_ublox.pos \
  rinex/rover/rover_ublox.obs \
  rinex/base/base_correspondiente.obs \
  rinex/base/base.nav
```

y para Unicore:

``` bash
rnx2rtkp -k scripts/ppk.conf \
  -o ppk/rover_unicore.pos \
  rinex/rover/rover_unicore.obs \
  rinex/base/base_correspondiente.obs \
  rinex/base/base.nav
```

Adapta los nombres y los archivos de navegación a los que realmente
generaste. Si las observaciones cruzan un cambio de día, asegúrate de
incluir todos los archivos de navegación necesarios.

**Para cada rover realiza dos salidas:**

- una solución que te permita obtener/resumir la posición fija del
  punto;
- una salida época por época para estudiar dispersión, estado FIX/FLOAT
  y estabilidad.

En total tendrás, como mínimo, **cuatro productos de solución**: dos
correspondientes al rover u-blox y dos al rover Unicore.

> No basta con presentar archivos `.pos`. Debes incluir el script o los
> comandos que permitan regenerarlos a partir de los RINEX y del archivo
> de configuración.

## Representa tabular y cartográficamente, compara

### Representación tabular

Muestra los resultados de las soluciones promediadas en una tabla como
ésta:

<div class="vlines" style="max-width: 700px;">

| Rover   | Receptor          | Resultado (LLH o XYZ) | % FIX | Observaciones |
|---------|-------------------|-----------------------|-------|---------------|
| u-blox  | doble frecuencia  |                       |       |               |
| Unicore | triple frecuencia |                       |       |               |

</div>

<br>

Incluye también la coordenada PPP utilizada para la base, indicando
**marco y época**, pero no la mezcles con las coordenadas rover como si
todas fueran observaciones equivalentes.

Para graficar las soluciones, ve a tu cuenta en el servidor RStudio,
sube tus archivos de soluciones `.pos`, carga la función personalizada
`pos_read_violin` usando el comando siguiente:

``` r
devtools::source_url(
paste0('https://raw.githubusercontent.com/geomorfologia-master/',
       'datos-gnss-soluciones-fijas/refs/heads/main/R/funciones.R'))
```

Evalúa la función:

``` r
archivos_pos <- list.files(pattern = '*.pos')
res <- pos_read_violin(archivos_pos, q_filter=1, export='gpkg',
                       export_path = "ppk_fix.gpkg",
                       export_layer = "ppk_fix",
                       plot_stat = "raw", stat_by = "archivo")
```

e imprime el resultado:

``` r
res
```

Si notas mucha dispersión, o quieres comparar la dispersión respecto de
la media:

``` r
res <- pos_read_violin(archivos_pos, q_filter=1, export='gpkg',
                       export_path = "ppk_fix.gpkg",
                       export_layer = "ppk_fix",
                       plot_stat = "z", stat_by = "archivo")
res
```

El argumento `export='gpkg'` genera un archivo GeoPackage
(`ppk_fix.gpkg`) que puedes descargar y abrir en QGIS. El argumento
`export_layer` permite definir el nombre de la capa.

### Compara los resultados

Compara las soluciones época por época de los dos receptores. Como ambos
levantaron el mismo punto, interesa cuantificar:

- diferencia entre las coordenadas promediadas;
- dispersión de cada solución;
- porcentaje de épocas FIX;
- presencia de FLOAT, SINGLE, outliers o interrupciones;
- diferencias horizontales y verticales;
- posible efecto de utilizar receptor doble frecuencia frente a triple
  frecuencia.

Si las dos colectas **no son temporalmente coincidentes**, no las trates
como muestras emparejadas. Puedes usar una prueba t de Student no
emparejada por componente, siempre que discutas sus supuestos y
limitaciones. Si el objetivo principal es comparar
precisión/estabilidad, acompaña cualquier prueba inferencial con medidas
descriptivas de dispersión y diferencias en metros.

<div class="vlines" style="max-width: 650px;">

| Componente | Media u-blox | Media Unicore | Diferencia | p   | Interpretación |
|------------|--------------|---------------|------------|-----|----------------|
| Lat / X    |              |               |            |     |                |
| Lon / Y    |              |               |            |     |                |
| H / Z      |              |               |            |     |                |

</div>

### Representación cartográfica

Representa las soluciones promediadas y/o época por época en RTKPLOT o
QGIS. La simbología debe permitir distinguir claramente las soluciones
del rover u-blox y del rover Unicore.

Cuando la separación sea muy pequeña para apreciarse a escala
cartográfica, complementa el mapa con gráficos en coordenadas locales
E/N/U o con distancias respecto de una posición de referencia.

# Redacta un informe integrado (IMRaD abreviado)

Prepara un **informe breve con estructura IMRaD** (Introducción,
Métodos, Resultados, Discusión), **usando IA como apoyo si lo deseas**.
Todo debe ser conciso: **cada sección debe tener entre 3 y 4 párrafos
cortos**. Añade lista de referencias al final y citas en el texto
(mínimo **3** fuentes).

> **Uso de IA**: puedes apoyarte en herramientas de IA para redactar,
> resumir, programar o formatear, pero debes verificar contenidos,
> números, comandos y citas. Añade al final una breve nota explicando
> para qué utilizaste IA y qué verificaciones realizaste.

------------------------------------------------------------------------

## 1) Introducción (3–4 párrafos)

- **Contexto y relevancia**: posicionamiento GNSS, PPP, PPK/RTK y
  aplicaciones en geomorfología.
- **Estado breve del arte**: diferencia entre PPP y posicionamiento
  relativo; observables de fase; importancia de RINEX, marco de
  referencia y época.
- **Objetivo(s) y pregunta(s)**: compara las soluciones obtenidas con
  rover u-blox y rover Unicore en el mismo punto.
- **Hipótesis (opcional)**: plantea si esperas diferencias de dispersión
  o porcentaje FIX entre receptor doble y triple frecuencia y justifica
  por qué.

## 2) Métodos (3–4 párrafos)

- **Datos y equipos**: describe los dos rovers, la base, duración
  aproximada de 120 s de las ocupaciones rover, archivos crudos y
  conversión a RINEX 3.04.
- **Preparación de la base y PPP**: explica cómo uniste los archivos
  horarios con `gfzrnx`, cómo redujiste la cadencia a 15 s y qué
  servicio utilizaste para obtener personalmente la coordenada de la
  base.
- **Marco y antena**: reporta marco y época de la coordenada PPP;
  explica que no se transformó a WGS84 (Transit); documenta ARP, altura
  del jalón y parámetros de antena suministrados.
- **PPK reproducible**: RTKLIB-EX, `rnx2rtkp`, archivo de configuración,
  parámetros esenciales, efemérides, salidas y criterio Q=1/FIX.

## 3) Resultados (3–4 párrafos)

- **Tabla(s) y figura(s) numeradas**: incluye al menos una tabla de
  coordenadas/resúmenes y una o dos figuras.
- **PPP de la base**: informa coordenada, marco, época e incertidumbre
  obtenidos por tu propio envío.
- **PPK**: reporta coordenadas de ambos rovers, porcentaje FIX,
  dispersión y diferencias entre soluciones.
- **Calidad y anomalías**: documenta *cycle slips*, interrupciones,
  advertencias de conversión/PPP, FLOAT, outliers u otras incidencias.

## 4) Discusión (3–4 párrafos)

- **Interpretación**: explica las diferencias entre los dos receptores y
  separa precisión relativa, exactitud absoluta y dispersión.
- **Marco de referencia**: discute por qué conservar el ITRF/IGS moderno
  y su época es preferible a transformar innecesariamente la solución a
  WGS84 (Transit).
- **Limitaciones**: ocupaciones rover de sólo ~120 s, multipath del
  campus, geometría satelital, configuración de RTKLIB-EX, calidad de la
  coordenada PPP y tratamiento de antena.
- **Implicaciones y trabajo futuro**: sesiones más largas, productos
  SP3/CLK Rapid/Final, repetición en distintos entornos, comparación
  entre efemérides broadcast y precisas.

## Referencias

- Incluye **mínimo 3** fuentes y cítalas en el texto.
- Sugerencias:
  - documentación de **RTKLIB-EX/RTKLIB**;
  - documentación del servicio PPP utilizado (NRCan/CSRS-PPP, OPUS o
    AUSPOS);
  - documentación de **GFZRNX**;
  - especificación **RINEX**;
  - literatura científica sobre PPP, RTK/PPK, resolución de ambigüedades
    y marcos ITRF/IGS.

------------------------------------------------------------------------

### Requisitos de forma

- **Extensión breve**: 4 secciones × **3–4 párrafos** cada una.
- **Reproducibilidad obligatoria**: incluye los comandos/scripts
  utilizados para conversión, unión, diezmado y PPK.
- **Trazabilidad PPP**: adjunta o conserva el informe del servicio y
  registra marco, época e incertidumbres.
- **Antena**: documenta ARP, altura ARP–marca y los parámetros PCO/PCV
  suministrados.
- **Numeración de figuras y tablas**, mención en el texto y leyendas
  claras.
- **Transparencia sobre IA**: identifica qué tareas se apoyaron en IA y
  qué errores o limitaciones detectaste al verificar sus respuestas.
- **Entregable**: PDF/HTML, con tablas/figuras incrustadas, scripts
  reproducibles y lista de referencias.

# Referencias
