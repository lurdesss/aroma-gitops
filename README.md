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
├── root aplicado UNA VEZ A MANO (fuera de este repo, ver mas abajo)
├── argo-rollouts.yaml      -> instala el controlador de Argo Rollouts
├── kyverno.yaml            -> instala Kyverno (politicas de admision)
├── velero.yaml             -> instala Velero (respaldo/restauracion)
├── sealed-secrets.yaml     -> instala el controlador de Sealed Secrets
└── microservicios/         -> un Application por servicio (capa siguiente)
```

Una sola `Application` raíz (`aroma-root`, ver
`P9/argocd/root-application.yaml` en el repositorio de código) apunta
a la carpeta `apps/` de **este** repositorio. ArgoCD descubre ahí
todos los `.yaml` como `Application` hijas y las sincroniza solo —
esa raíz es el único paso manual de todo el bootstrap; todo lo demás
lo hace ArgoCD.
