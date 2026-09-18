# Publicar `bspwm1-maflorezp-git` en AUR

El PKGBUILD que se publica vive en `pkg/arch/bspwm1-maflorezp-git/`, junto al `.SRCINFO`. La copia
de `~/.dotFiles/pkgbuilds/` es sólo para compilar en caliente mientras se desarrolla.

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
git clone ssh://aur@aur.archlinux.org/bspwm1-maflorezp-git.git ~/aur/bspwm1-maflorezp-git
cd ~/aur/bspwm1-maflorezp-git

cp /websites/personal/bspwm/pkg/arch/bspwm1-maflorezp-git/{PKGBUILD,.SRCINFO} .

git add PKGBUILD .SRCINFO
git commit -m "initial release"
git push
```

**Sólo van esos dos ficheros.** Nada de fuentes, ni paquetes, ni `.gitignore`: AUR rechaza el push
si aparecen.

## Después, en los otros servidores

```sh
yay -S bspwm1-maflorezp-git
```

Cada instalación clona la rama `local` en ese momento, así que todos acaban en el mismo commit que
`local` tenga ese día. El paquete sustituye a `bspwm` y a `bspwm1`.

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
