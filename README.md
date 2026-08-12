# CloudCuyo Migration Lab — Formatec Cloud 2026

Repositorio del curso **Arquitectura e Ingeniería Cloud | C2**.

**Profesor:** Nicolás Pannucio

## Organización

Todos los laboratorios viven dentro de `labs/`. Cada lab es autocontenido: incluye su README, guías, infraestructura, scripts y workflows. Los workflows que deben aparecer en GitHub Actions viven dentro de la carpeta del lab:

```text
labs/
├── m2-c1-lab/
├── m2-c2-lab/
├── m2-c3-lab/
├── m2-c4-lab/
├── m3-c1-lab/
├── m3-c2-lab/
├── m3-c4-lab/
└── m3-c5-lab/
```

Los alumnos trabajan desde `main` y entran a la carpeta indicada por la clase. Ya no es necesario cambiar de branch para encontrar el material de cada lab.

## Labs disponibles

| Carpeta | Tema |
|---|---|
| `labs/m2-c1-lab` | Migración inicial a AWS |
| `labs/m2-c2-lab` | Alta disponibilidad, ALB y Auto Scaling |
| `labs/m2-c3-lab` | Modernización y microservicios |
| `labs/m2-c4-lab` | Contenedores, Docker Swarm y serverless |
| `labs/m3-c1-lab` | Infrastructure as Code con Terraform |
| `labs/m3-c2-lab` | Gestión de configuración con Ansible |
| `labs/m3-c4-lab` | Pipelines CI/CD con GitHub Actions |
| `labs/m3-c5-lab` | Monitoreo proactivo con CloudWatch |

## Codespaces

1. Abrí el repositorio.
2. Presioná **Code → Codespaces → Create codespace on main**.
3. Verificá la ubicación:

```bash
git branch --show-current
```

Cada guía indica el directorio del lab y sus comandos. Codespaces prepara las herramientas, pero no reemplaza la cuenta AWS, los permisos ni el cleanup.

## Reglas generales

- No commitear credenciales, tokens, state, planes ni archivos `.env`.
- Leer el README y la guía dentro de `labs/<lab>/` antes de ejecutar comandos.
- Usar el Environment y las variables indicadas por cada lab.
- Ejecutar `destroy` al finalizar cuando la práctica cree recursos AWS.
- No eliminar buckets de state ni recursos compartidos.
- Los workflows de cada lab se ejecutan según su propio `workflow_dispatch` y sus condiciones documentadas.

## M3-C5

El nuevo flujo está en [`labs/m3-c5-lab/`](labs/m3-c5-lab/):

```text
spec → Cursor Plan Mode → workflow → Terraform
→ frontend + backend → tráfico → CloudWatch
→ logs → metric filters → dashboard → alarmas
```

El workflow y la configuración de Actions se encuentran dentro de esa carpeta, por lo que quedan disponibles desde la branch default `main` sin depender de una branch de módulo separada.

## Entornos anteriores

Las branches históricas por módulo se conservan como referencia y rollback. El material canónico para los alumnos pasa a ser el que está debajo de `labs/` en `main`.
