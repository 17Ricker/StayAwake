<p align="center"><img src="Resources/AppIcon.png" width="128" alt="Icono de StayAwake"></p>

# StayAwake

[English](README.md) · [Italiano](README.it.md) · **Español**

Una pequeña app para la barra de menús de macOS que mantiene el Mac encendido, **incluso con la tapa cerrada**, durante el tiempo que elijas.

<p align="center"><img src="docs/screenshots/night.png" width="720" alt="StayAwake en el estilo Noche: apagado, temporizador en marcha, continuo"></p>

## Qué hace

- **Temporizador** de 5 minutos a 24 horas, o **continuo** hasta que lo detengas. Puedes añadir tiempo mientras corre.
- Funciona **con la tapa cerrada** (usa `pmset disablesleep` de macOS).
- **La seguridad, primero:**
  - se detiene cuando la batería baja del 20 % (opcional);
  - se detiene si macOS indica una temperatura crítica (opcional);
  - al salir devuelve el reposo a la normalidad, y también si la app se cierra inesperadamente o se fuerza su salida.
- Tres estilos (Noche, Retro, Moderno) y tres idiomas (Español, English, Italiano).
- **Sin conexiones de red**, sin telemetría, sin actualizaciones automáticas.

<p align="center"><img src="docs/screenshots/modern.png" width="560" alt="StayAwake en el estilo Moderno"></p>

## Requisitos

macOS 14 Sonoma o posterior, en Mac con Apple silicon o Intel.

## Instalación

1. Descarga `StayAwake.zip` y `StayAwake.zip.sha256` de la [última versión](https://github.com/ricky7x/StayAwake/releases/latest).
2. Comprueba la descarga (opcional, recomendado):

   ```bash
   shasum -a 256 -c StayAwake.zip.sha256
   gh attestation verify StayAwake.zip -R ricky7x/StayAwake
   ```

   - El primer comando comprueba que la descarga no esté dañada. El hash viene de la misma versión, así que por sí solo no demuestra de dónde viene el archivo.
   - El segundo ([GitHub CLI](https://cli.github.com)) demuestra que el zip lo creó GitHub Actions **a partir del código público de este repositorio**.
3. Descomprímelo y mueve **StayAwake** a la carpeta **Aplicaciones**.
4. Ábrela. StayAwake es gratuita y no está notarizada por Apple, así que la primera vez macOS dice que no puede verificar al desarrollador.
   - Pulsa **OK**, luego abre **Ajustes del Sistema → Privacidad y seguridad**.
   - Baja hasta el mensaje sobre StayAwake y pulsa **Abrir igualmente**. Solo hace falta una vez.
   - No desactives Gatekeeper ni quites los atributos de cuarentena para evitar el aviso.

Busca el rayo ⚡ en la barra de menús.

## Compilarla tú mismo

Necesitas Xcode (la app completa: las macros de SwiftUI no se compilan solo con las Command Line Tools).

```bash
git clone https://github.com/ricky7x/StayAwake.git
cd StayAwake
./test.sh        # pruebas, sin contraseña de administrador
./install.sh     # compila e instala en ~/Aplicaciones
```

`./release.sh` genera el mismo zip universal con firma ad-hoc que usan las versiones publicadas.

## Para qué sirve la contraseña

Solo un administrador puede cambiar `disablesleep`. La primera vez que activas StayAwake, macOS muestra su propia ventana de contraseña: StayAwake no la ve ni la guarda. Con ella, StayAwake instala una regla que permite **solo a tu usuario** ejecutar **solo estos dos comandos** sin contraseña:

```
#501 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- `501` es tu ID de usuario.
- La regla se comprueba con `visudo` antes de instalarla.
- Está en su propio archivo, `/etc/sudoers.d/stayawake-uid<tu ID>`, uno por usuario, así los usuarios del mismo Mac no se sobrescriben entre sí.

Para verla:

```bash
sudo cat /etc/sudoers.d/stayawake-uid$(id -u)
```

Conviene saberlo: otras apps que se ejecutan con tu usuario también pueden usar esta regla, pero solo para activar o desactivar el reposo, nada más.

## Quitarlo todo

1. **Primero apaga StayAwake** (Detener, o desactiva Continuo).
2. En StayAwake: **Ajustes → Quitar permiso** (macOS pide la contraseña de administrador). O en Terminal:

   ```bash
   sudo rm /etc/sudoers.d/stayawake-uid$(id -u)
   sudo pmset -a disablesleep 0    # se asegura de que el reposo vuelva a estar activo
   ```

3. Sal de StayAwake y arrástrala a la Papelera.

Las primeras versiones usaban un solo archivo, `/etc/sudoers.d/stayawake`. StayAwake lo quita sola la primera vez que la activas, si contiene tu regla antigua; si no, puedes borrarlo con `sudo rm /etc/sudoers.d/stayawake`.

## Seguridad y límites

- **No metas el Mac en una mochila con StayAwake activo.** Con la tapa cerrada puede calentarse. La protección térmica detiene StayAwake a temperatura crítica, pero no confíes solo en ella.
- Con batería, el Mac sigue consumiendo con la tapa cerrada. La protección de batería detiene StayAwake por debajo del 20 %.
- Si el Mac **se reinicia** con StayAwake activo, el reposo sigue desactivado hasta que StayAwake vuelva a abrirse, también en la pantalla de inicio de sesión. Activa **Abrir al iniciar sesión** para que el reposo vuelva en cuanto entres.
- El reposo es un ajuste de todo el Mac. Si varias personas usan StayAwake en el mismo Mac (cambio rápido de usuario), abrirla o cerrarla en una cuenta reactiva el reposo para todos, aunque otra cuenta la siga mostrando activa.
- Si StayAwake se cierra inesperadamente o se fuerza su salida, un pequeño proceso en segundo plano devuelve el reposo a la normalidad en un par de segundos.
- StayAwake no hace ninguna conexión de red.

## Idiomas

**Ajustes → Idioma**: Sistema, Italiano, English, Español. *Sistema* sigue el idioma de macOS, o el inglés si no es ninguno de estos.

<p align="center"><img src="docs/screenshots/settings.png" width="560" alt="Ajustes en los estilos Noche y Retro"></p>

## Seguridad

En [SECURITY.md](SECURITY.md) se explica qué se ejecuta como administrador y cómo informar de una vulnerabilidad.

## Licencia

[MIT](LICENSE) © 2026 Riccardo Gnoni
