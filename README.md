# aroma-gitops

Repositorio de manifiestos declarativos de la plataforma Aroma —
independiente del repositorio de código
(`Pr-cticas-SA-B-202103763`), según exige el patrón GitOps.

**ArgoCD es el único componente que aplica cambios a partir de este
repositorio.** Ningún workflow de CI/CD corre `kubectl apply` ni
`helm upgrade` contra el clúster — el pipeline de código solo abre
Pull Requests aquí, actualizando la versión de imagen de un servicio.

## Patrón app-of-apps

```
apps/
├── sealed-secrets.yaml     [ola -2] controlador de Sealed Secrets
├── velero-secrets.yaml     [ola -1] SealedSecrets de secrets/
├── argo-rollouts.yaml      [ola  0] controlador de Argo Rollouts
├── kyverno.yaml            [ola  0] Kyverno (politicas de admision)
├── velero.yaml             [ola  0] Velero (respaldo/restauracion)
├── velero-schedules.yaml   [ola  1] Schedules de backups/
└── microservicios/         -> un Application por servicio (capa siguiente)
backups/schedule.yaml       -> respaldo-diario-aroma y respaldo-llaves
secrets/                    -> solo SealedSecret (nunca Secret en claro)
```

Las olas esperan a que la ola anterior esté `Healthy` solo porque ArgoCD
tiene configurado el chequeo de salud de `Application` (receta oficial de
app-of-apps) en `P9/terraform/bootstrap.tf`. El mismo archivo activa el
rastreo por anotación: Velero copia las etiquetas de un `Schedule` a los
`Backup` que genera y, con rastreo por etiqueta, el `prune` los borraría.

Una sola `Application` raíz (`aroma-root`, namespace `argocd`) apunta
a la carpeta `apps/` de **este** repositorio. ArgoCD descubre ahí
todos los `.yaml` como `Application` hijas y las sincroniza solo.
La raíz la instala Terraform (`helm_release.aroma_root` en
`P9/terraform/bootstrap.tf` del repositorio de código, chart
`argocd-apps`), invocado desde el punto de entrada único
`P9/bootstrap.ps1`: no hay pasos intermedios fuera de ese comando.

## Respaldo de Velero

Velero escribe en el bucket `velero-backups` de MinIO fuera del clúster,
mediante el plugin S3 de AWS y el uploader Kopia/node-agent para incluir
los volúmenes persistentes de kind (local-path no ofrece snapshots CSI).
Las credenciales existen en GitOps solo como `SealedSecret`; nunca se
guardan como `Secret` en claro.

`backups/schedule.yaml` declara el respaldo diario de producción y staging
(retención de 15 días) y un respaldo semanal de la llave de Sealed Secrets
(retención de un año). El respaldo de la llave queda sin cifrado de reposo
en MinIO: exportarlo también de forma cifrada fuera del clúster y de Git.
MinIO local con credenciales de desarrollo sirve para esta práctica, no
para producción.
