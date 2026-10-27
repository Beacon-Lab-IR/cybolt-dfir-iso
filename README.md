# CyboltDFIR ISO

ISO no-booteable que agrega los últimos releases de los proyectos
CyboltDFIR en un solo medio. Se monta como CD-ROM en VMs/hosts y se
ejecuta desde ahí.

## Quickstart

```bash
# Version del header de VERSION.txt + latest de triage/uploader
./build.sh

# Fuerza version del ISO
./build.sh 0.2.0

# Pin a versiones especificas de proyectos
./build.sh --pin triage=0.3.2 --pin uploader=0.2.0

# Output: dist/CyboltDFIR-ISO-v<VERSION>.iso
```

**Una sola versión del ISO:** tag git = nombre del asset = header de
`VERSION.txt`. Los proyectos embebidos (triage/uploader) usan el mismo
esquema `0.x`.

## Componentes

- `build.sh` — baja los releases de los proyectos en `projects.json`
- `projects.json` — config de qué proyectos incluir (repos + asset patterns)
- `VERSION.txt` — changelog + header de versión del ISO
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
