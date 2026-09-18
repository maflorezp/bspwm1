# Publicar `bspwm1-maflorezp-git` en AUR

El PKGBUILD que se publica vive en `pkg/arch/bspwm1-maflorezp-git/`, junto al `.SRCINFO`. Es el
único; la copia que había en `~/.dotFiles/pkgbuilds/` con su `build.sh` se retiró el 2026-09-18,
porque compilaba exactamente lo mismo que AUR.

**Publicado el 2026-09-18.** El clon de AUR está en `/websites/personal/aur/bspwm1-maflorezp-git`.

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
git clone ssh://aur@aur.archlinux.org/bspwm1-maflorezp-git.git \
    /websites/personal/aur/bspwm1-maflorezp-git
cd /websites/personal/aur/bspwm1-maflorezp-git

cp /websites/personal/bspwm/pkg/arch/bspwm1-maflorezp-git/{PKGBUILD,.SRCINFO} .

git add PKGBUILD .SRCINFO
git commit -m "initial release"
git push
```

**Sólo van esos dos ficheros.** Nada de fuentes, ni paquetes, ni `.gitignore`: AUR rechaza el push
si aparecen.

## Instalar y actualizar, aquí y en los otros servidores

```sh
yay -S bspwm1-maflorezp-git   # instalar
yay -Syu --devel              # actualizar cuando la rama local avance
```

Cada instalación clona la rama `local` en ese momento, así que todos acaban en el mismo commit que
`local` tenga ese día. El paquete sustituye a `bspwm` y a `bspwm1`.

`--devel` es lo que hace que yay mire el último commit de la rama; sin esa opción se fía del
`pkgver` publicado en AUR y no ve los avances de `local`.

## La identidad de los commits

El primer commit (`3a0d34c`) quedó con `maflorez@cognox.com`, y **no se puede arreglar**: el hook de
AUR rechaza cualquier push que no sea avance directo, así que no hay reescritura posible. Los
siguientes ya salen bien: hay un `includeIf` por carpeta en `~/.gitconfig` que fija
`maflorezp@gmail.com` en `/websites/personal/bspwm`, sus worktrees y `/websites/personal/aur`.

## Mantenimiento

- Al ser un paquete `-git`, `pkgver()` resuelve el commit solo en cada compilación: **no hace falta
  tocar `pkgver` en cada cambio**. Basta con que `local` esté empujado.
- Sí conviene rehacer el `.SRCINFO` y empujarlo cuando cambien las dependencias, la descripción o
  la rama de origen:
  ```sh
  cd /websites/personal/bspwm/pkg/arch/bspwm1-maflorezp-git
  makepkg --printsrcinfo > .SRCINFO
  ```
- **Sin `check()` a propósito.** `make test` necesita Xvfb y la prueba de iconify falla de vez en
  cuando por un fallo conocido de bspwm1 (el bucle de epoll deja eventos en la cola de xcb). Con
  `check()`, esa intermitencia rompería la instalación a quien lo instale. Cuando ese fallo se
  arregle, se puede añadir con `checkdepends=('xorg-server-xvfb')`.
- Antes de cada push a AUR, la prueba en limpio:
  ```sh
  cd $(mktemp -d) && cp /websites/personal/bspwm/pkg/arch/bspwm1-maflorezp-git/PKGBUILD . && makepkg
  ```
