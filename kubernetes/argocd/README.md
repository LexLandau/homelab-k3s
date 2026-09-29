# Argo CD

Stand: 29.09.2026, Argo CD v3.5.3 (Non-HA), selbstverwaltet über die Application `argocd`.

## Neuaufbau (Bootstrap)

```bash
kubectl apply -f kubernetes/argocd/namespace.yaml
kubectl apply -n argocd --server-side --force-conflicts -k kubernetes/argocd/install
kubectl apply -f kubernetes/argocd/applications/root-app.yaml
```

Danach das Token für den External Secrets Operator anlegen (Wert aus 1Password, Eintrag „Token eso-k3s“, Tresor Homelab-K3s):

```bash
read -r -s -p "Token eso-k3s: " OPTOKEN; echo
kubectl -n external-secrets create secret generic onepassword-sa-token --from-literal=token="$OPTOKEN"
unset OPTOKEN
```

Admin-Passwort nach Neuinstallation:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Lokale Anpassungen

| Anpassung | Ort | Grund |
|---|---|---|
| Dex auf 0 Replikas | Patch in install/kustomization.yaml | Kein SSO in Nutzung; entlastet die Knoten |

Argo-CD-Oberfläche: `kubectl -n argocd port-forward svc/argocd-server 8080:443`, dann https://localhost:8080 (Benutzer admin).

## Upgrade

1. Upgrade-Hinweise jeder Minor-Version zwischen Ist- und Zielversion lesen.
2. Sicherung: `argocd admin export -n argocd > argocd-export-<version>-<datum>.yaml` (lokal, nie ins Repo).
3. Version in `kubernetes/argocd/install/kustomization.yaml` ändern, committen, pushen.
4. Kontrolle: `kubectl -n argocd get applications.argoproj.io`

## Verlauf

| Datum | Von | Nach | Weg |
|---|---|---|---|
| 29.09.2026 | v2.13.2 | v3.5.3 | Stufenweise per kubectl (2.14.21, 3.0.23, 3.1.16, 3.2.12, 3.3.14, 3.4.9, 3.5.3), danach in Git überführt |
