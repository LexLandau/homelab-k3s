# Argo CD

Stand: 29.09.2026, Argo CD v3.5.3 (Non-HA), selbstverwaltet ueber die Application `argocd`.

## Neuaufbau (Bootstrap)

```bash
kubectl apply -f kubernetes/argocd/namespace.yaml
kubectl apply -n argocd --server-side --force-conflicts -k kubernetes/argocd/install
kubectl apply -f kubernetes/argocd/applications/root-app.yaml
```

Admin-Passwort nach Neuinstallation:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Upgrade

1. Upgrade-Hinweise jeder Minor-Version zwischen Ist- und Zielversion lesen.
2. Sicherung: `argocd admin export -n argocd > argocd-export-<version>-<datum>.yaml` (lokal, nie ins Repo).
3. Version in `kubernetes/argocd/install/kustomization.yaml` aendern, committen, pushen.
4. Kontrolle: `kubectl -n argocd get applications.argoproj.io`

## Verlauf

| Datum | Von | Nach | Weg |
|---|---|---|---|
| 29.09.2026 | v2.13.2 | v3.5.3 | Stufenweise per kubectl (2.14.21, 3.0.23, 3.1.16, 3.2.12, 3.3.14, 3.4.9, 3.5.3), danach in Git ueberfuehrt |
