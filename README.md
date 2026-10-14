# CyboltDFIR ISO

Bootable CD-ROM que agrega los últimos releases de los proyectos
CyboltDFIR en un solo ISO. Se monta como CD-ROM en VMs/hosts y se
ejecuta desde ahí.

## Quickstart

```bash
# Default: usa los ultimos releases
./build.sh

# Version personalizada del ISO (los proyectos incluidos son latest)
./build.sh 5.3.1

# Pin a versiones especificas de proyectos
./build.sh --pin triage=5.3.1 --pin uploader=5.3.1

# Output: dist/CyboltDFIR-ISO-v<VERSION>.iso
```

## Componentes

- `build.sh` — baja los ultimos releases de los proyectos en `projects.json`
- `projects.json` — config de qué proyectos incluir (repos + asset patterns)
- `dist/CyboltDFIR-ISO-v<VERSION>.iso` — output

## Cómo funciona

1. Lee `projects.json` para resolver qué proyectos bajar
2. Usa `gh release download` para bajar el último release de cada uno
3. Extrae los ZIPs en `staging/`
4. Construye el ISO con `hdiutil makehybrid` (macOS) o `genisoimage` (Linux)

## Proyectos incluidos

- [Beacon-Lab-IR/cybolt-dfir-triage](https://github.com/Beacon-Lab-IR/cybolt-dfir-triage) — wizard de adquisición
- [Beacon-Lab-IR/cybolt-dfir-uploader](https://github.com/Beacon-Lab-IR/cybolt-dfir-uploader) — subidor de ZIPs

Para agregar un proyecto nuevo, editar `projects.json` con un nuevo entry.

## Releases

- [GitHub Releases](https://github.com/Beacon-Lab-IR/cybolt-dfir-iso/releases)
- Cada release genera `CyboltDFIR-ISO-v<VERSION>.iso`

## Licencia

By Cybolt, MIT License.
