# Publicar `bspwm-ng-git` en AUR

> **Cambio de nombre (2026-09-21).** Hasta la `v1.6.3` el paquete se llamó `bspwm1-maflorezp-git`
> y el repo `maflorezp/bspwm1`. El paquete nuevo lleva `replaces` y `conflicts` del viejo, y el viejo
> se fusiona en el nuevo con un *merge request* desde la web de AUR (Package Actions → Submit Request
> → Merge), que es lo que traslada votos y comentarios. GitHub redirige la URL vieja del repo.

El PKGBUILD que se publica vive en `pkg/arch/bspwm-ng-git/`, junto al `.SRCINFO`. Es el
único; la copia que había en `~/.dotFiles/pkgbuilds/` con su `build.sh` se retiró el 2026-09-18,
porque compilaba exactamente lo mismo que AUR.

**`bspwm1-maflorezp-git` se publicó el 2026-09-18; `bspwm-ng-git`, el 2026-09-21.** El clon de AUR está en `/websites/personal/aur/bspwm-ng-git`.

Comprobado el 2026-09-17: desde un directorio vacío, `makepkg` clona el repo público, compila y
genera el paquete con `bspwm`, `bspc` y los dos manuales. Es decir, funciona tal cual para
cualquiera que lo instale, no sólo aquí.

## Una vez: la cuenta y la clave

1. Cuenta en <https://aur.archlinux.org> (la misma que la del foro de Arch, si ya la tienes).
2. En **My Account → SSH Public Key**, pegar la clave pública. Si hace falta una nueva:
   ```sh
   ssh-keygen -t ed25519 -C "aur" -f ~/.ssh/aur
   cat ~/.ssh/aur.pub
   ```
   Y en `~/.ssh/config`:
   ```
   Host aur.archlinux.org
       User aur
       IdentityFile ~/.ssh/aur
       IdentitiesOnly yes
   ```
3. Comprobar: `ssh aur@aur.archlinux.org help` responde con la lista de órdenes.

## Publicar

AUR es un repositorio git por paquete. El primer push crea el paquete.

```sh
git clone ssh://aur@aur.archlinux.org/bspwm-ng-git.git \
    /websites/personal/aur/bspwm-ng-git
cd /websites/personal/aur/bspwm-ng-git

cp /websites/personal/bspwm/pkg/arch/bspwm-ng-git/PKGBUILD .
# El pkgver sale del commit que se publica (ver «Mantenimiento»), nunca del PKGBUILD del fork.
PV=$(git -C /websites/personal/bspwm describe --long --tags --abbrev=7 local |
     sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')
sed -i "s/^pkgver=.*/pkgver=$PV/" PKGBUILD
makepkg --printsrcinfo > .SRCINFO

git add PKGBUILD .SRCINFO
git commit -m "initial release"
git push
```

**Sólo van esos dos ficheros.** Nada de fuentes, ni paquetes, ni `.gitignore`: AUR rechaza el push
si aparecen.

## Instalar y actualizar, aquí y en los otros servidores

```sh
yay -S bspwm-ng-git   # instalar
yay -Syu --devel              # actualizar cuando la rama local avance
```

Cada instalación clona la rama `local` en ese momento, así que todos acaban en el mismo commit que
`local` tenga ese día. El paquete sustituye a `bspwm` y a `bspwm1`.

`--devel` es lo que hace que yay mire el último commit de la rama; sin esa opción se fía del
`pkgver` publicado en AUR y no ve los avances de `local`. `yay -S bspwm-ng-git` también
actualiza: no compara versiones, recompila el paquete desde `local` y no toca el resto del sistema.

## La identidad de los commits

El primer commit (`3a0d34c`) quedó con `maflorez@cognox.com`, y **no se puede arreglar**: el hook de
AUR rechaza cualquier push que no sea avance directo, así que no hay reescritura posible. Los
siguientes ya salen bien: hay un `includeIf` por carpeta en `~/.gitconfig` que fija
`maflorezp@gmail.com` en `/websites/personal/bspwm`, sus worktrees y `/websites/personal/aur`.

## Mantenimiento

- Al ser un paquete `-git`, `pkgver()` resuelve el commit solo en cada compilación, así que compila
  bien sin tocar nada. Pero **sin subir el `pkgver` publicado, nadie se entera**: un `yay -Syu`
  normal compara con él. Se sube al sacar una versión o un cambio que merezca aviso.
- **El `pkgver` de AUR se calcula al publicar**, con la misma cuenta que `pkgver()`, sobre el commit
  que se publica:
  ```sh
  git -C /websites/personal/bspwm describe --long --tags --abbrev=7 local |
      sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
  ```
  Se escribe en el `PKGBUILD` del clon de AUR, se regenera allí `.SRCINFO` y se empuja. El
  `PKGBUILD` del fork no puede llevarlo exacto, porque no puede contener el hash de su propio
  commit, así que puede ir una publicación por detrás. Es seguro: un `pkgver` viejo nunca es mayor
  que lo que se compila.
- **Nunca publicar un `pkgver` sin su `.rN.g<hash>`**, como `1.6.3` a secas: pacman lo considera
  más nuevo que `1.6.3.r0.g…`, y yay ofrecería la misma actualización en bucle.
- **Versiones.** Una etiqueta anotada `vX.Y.Z` en `local`, con su sección en `doc/CHANGELOG.md`, el
  fichero `VERSION` y el manual regenerado con `make doc VERSION=vX.Y.Z`, todo en el mismo commit.
  Para que `bspwm -v` diga la versión a secas, la etiqueta va en el último commit empujado. Se
  empuja aparte: `git push origin vX.Y.Z`.
- Sí conviene rehacer el `.SRCINFO` y empujarlo cuando cambien las dependencias, la descripción o
  la rama de origen:
  ```sh
  cd /websites/personal/bspwm/pkg/arch/bspwm-ng-git
  makepkg --printsrcinfo > .SRCINFO
  ```
- **Sin `check()` a propósito.** `make test` necesita Xvfb y la prueba de iconify falla de vez en
  cuando por un fallo conocido de bspwm1 (el bucle de epoll deja eventos en la cola de xcb). Con
  `check()`, esa intermitencia rompería la instalación a quien lo instale. Cuando ese fallo se
  arregle, se puede añadir con `checkdepends=('xorg-server-xvfb')`.
- Antes de cada push a AUR, la prueba en limpio:
  ```sh
  cd $(mktemp -d) && cp /websites/personal/bspwm/pkg/arch/bspwm-ng-git/PKGBUILD . && makepkg
  ```
