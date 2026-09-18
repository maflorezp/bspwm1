# Grabar los GIF del README

El README tiene tres huecos, comentados con `<!-- GIF: ... -->`. Grabas, guardas el fichero en
`docs/media/` y le quitas el comentario al bloque. Nada más.

Herramientas: `ffmpeg` (ya instalado). No hace falta nada más; las órdenes de abajo generan el GIF
con paleta propia, que es lo que evita el look sucio de los GIF de 256 colores mal cuantizados.

## Antes de grabar

```sh
bspc config magnet_threshold          30
bspc config edge_snap_zone_ratio      0.2
bspc config edge_snap_preview_color   '#04dd29'
bspc config edge_snap_preview_opacity 25
```

- Un escritorio vacío, sin correo, sin chats, sin nombres de clientes a la vista. Lo que se
  publica en unixporn lo mira mucha gente con tiempo libre.
- Dos o tres ventanas sencillas y reconocibles: una terminal, un visor de imágenes, una calculadora.
- Ratón a velocidad normal. Los movimientos muy rápidos no dejan ver el imán.

## Las tres tomas

### 1. `docs/media/magnet.gif` — el imán (10-12 s)

1. Dos ventanas flotantes separadas.
2. Arrastra una hacia la otra **despacio**: al acercarse, el borde se pega. Para un segundo ahí,
   para que se vea el enganche.
3. Sigue arrastrando en la misma dirección hasta despegarla.
4. Repite contra el borde de la pantalla.
5. Termina alineando la ventana con el **mismo borde** de la vecina (arriba con arriba), que es el
   caso que menos gente espera.

### 2. `docs/media/snap-zones.gif` — zonas y vista previa (10-12 s)

1. Arrastra una ventana hacia una esquina, **sin llegar a la esquina**: basta con entrar en el
   quinto exterior del borde. Se dibuja la vista previa verde del cuarto de pantalla. Suelta.
2. Arrastra al centro del borde superior: la vista previa ocupa la pantalla entera. Suelta.
3. Arrastra al borde superior pero lejos del centro: mitad de arriba.
4. Si te caben, el borde inferior y un lateral.

Con el compositor corriendo la vista previa se ve translúcida; sin él, opaca. Graba con picom
puesto.

### 3. `docs/media/demo.gif` — la portada (12-15 s)

La que se ve primero: un resumen. Imán → zona de snap → una regla en la terminal, por ejemplo
`bspc rule -a class=Pavucontrol/i state=floating` y abrir `pavucontrol` para que salga flotante.
Si no cabe todo, quédate con el imán y las zonas: las reglas se leen mejor en el README.

## Las órdenes

Región y tamaño: mira las coordenadas con `xwininfo` o `slop`, o graba una pantalla entera y
recorta después.

```sh
# 1. Grabar (sin comprimir mucho, que la fuente sea buena)
ffmpeg -f x11grab -framerate 30 -video_size 1280x720 -i :0.0+320,180 \
       -c:v libx264 -qp 0 -preset ultrafast -t 12 /tmp/toma.mkv

# 2. Paleta propia a partir de la toma
ffmpeg -i /tmp/toma.mkv -vf "fps=15,scale=720:-1:flags=lanczos,palettegen=stats_mode=diff" \
       -y /tmp/paleta.png

# 3. GIF con esa paleta
ffmpeg -i /tmp/toma.mkv -i /tmp/paleta.png \
       -lavfi "fps=15,scale=720:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
       -y docs/media/magnet.gif
```

- `fps=15` y `scale=720` es el equilibrio que suele funcionar: por debajo se ve a trompicones, por
  encima el fichero se dispara.
- Apunta a **menos de 5 MB por GIF**. GitHub aguanta más, pero la portada tiene que cargar rápido.
  Si se pasa, baja a `fps=12` o recorta un segundo.
- Comprueba el peso: `du -h docs/media/*.gif`.

## Para el vídeo de unixporn

Ahí no hace falta GIF: sube el `.mkv` o pásalo a mp4, que se ve mucho mejor y pesa menos.

```sh
ffmpeg -i /tmp/toma.mkv -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart /tmp/demo.mp4
```

El `-pix_fmt yuv420p` no es opcional: sin él, Reddit y Twitter no reproducen el vídeo.

## Al terminar

1. `docs/media/` con los tres ficheros.
2. En `README.md`, quitar `<!--` y `-->` de los tres bloques.
3. Mirar la portada en GitHub antes de anunciarla en ningún sitio.
