# Monitoring (kube-prometheus-stack)

Stand: 02.10.2026. Chart 91.8.2, Prometheus-Operator v0.94.1, Prometheus v3.15.0, Grafana 13.2.3, Alertmanager v0.34.1.
Definition: kubernetes/argocd/applications/monitoring-helm.yaml (ArgoCD, ServerSideApply).

## Zugang

| Dienst | Adresse | Anmeldung |
|---|---|---|
| Grafana | http://192.168.1.228 | admin, Passwort aus 1Password (Tresor Homelab-K3s-ESO, Eintrag grafana-admin) |
| Prometheus | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090` | ohne |

Grafana bekommt das Passwort über das Secret monitoring/grafana-admin (ExternalSecret). Grafana übernimmt es aber nur beim ersten Start; danach gilt die Grafana-Datenbank.

Passwortwechsel:

1. Neues Passwort in 1Password eintragen.
2. Secret sofort abgleichen und in Grafana setzen:

```bash
kubectl -n monitoring annotate externalsecrets.external-secrets.io grafana-admin force-sync="$(date +%s)" --overwrite
sleep 20
GPW=$(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)
kubectl -n monitoring exec deploy/kube-prometheus-stack-grafana -c grafana -- grafana cli admin reset-admin-password "$GPW" 2>&1 | grep -v "^logger="
unset GPW
```

## Chart-Update

1. Upgrade-Hinweise lesen: charts/kube-prometheus-stack/UPGRADE.md in prometheus-community/helm-charts, zusätzlich Release Notes (UPGRADE.md war für 88 bis 91 unvollständig).
2. Longhorn-Backup auslösen: `kubectl -n longhorn-system create job --from=cronjob/daily-backup-all backup-vor-kps-update`
3. CRDs der Zielversion vorab einspielen, sonst scheitert der ArgoCD-Vergleich (`field not declared in schema`):

```bash
V=91.8.2
D=/tmp/kps-crds-$V
rm -rf "$D" && mkdir -p "$D"
for c in alertmanagerconfigs alertmanagers podmonitors probes prometheusagents prometheuses prometheusrules scrapeconfigs servicemonitors thanosrulers; do
  curl -sf -o "$D/crd-$c.yaml" "https://raw.githubusercontent.com/prometheus-community/helm-charts/kube-prometheus-stack-$V/charts/kube-prometheus-stack/charts/crds/crds/crd-$c.yaml" || echo "FEHLT: $c"
done
kubectl apply --server-side --force-conflicts -f "$D"
```

4. `targetRevision` in monitoring-helm.yaml ändern, committen, pushen.
5. Kontrolle: Pods laufen, Scrape-Ziele aktiv (unten).

Große Sprünge in Etappen (29.09.2026: 65.8.1, 83.7.0, 91.8.1). Grafana migriert seine Datenbank bei Hauptversionen; zurück nur über das Backup des Grafana-Volumes.

## Kontrolle Scrape-Ziele

Die Images sind distroless (kein wget/sh im Container). Abfrage über den API-Server-Proxy:

```bash
kubectl get --raw "/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:http-web/proxy/api/v1/query?query=count(up==1)"
kubectl get --raw "/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:http-web/proxy/api/v1/query?query=count%20by%20(job)%20(up==0)"
```

Stand 29.09.2026: 23 Ziele aktiv, 0 inaktiv. Controller-Manager, Scheduler und etcd werden nicht erfasst (bei k3s im k3s-Prozess).

## Ressourcen

| Komponente | Limit | Verbrauch 29.09.2026 |
|---|---|---|
| Prometheus | 2Gi | ca. 1,4 GiB |
| Grafana | 768Mi | ca. 450 MiB |
| Node Exporter / kube-state-metrics | 64Mi / 128Mi | ca. 15 / 35 MiB |

Werte für Unter-Charts stehen unter `prometheus-node-exporter` bzw. `kube-state-metrics`, nicht unter `nodeExporter`/`kubeStateMetrics`.

## Offen

Alertmanager hat noch keinen Empfänger: Warnungen werden erzeugt, aber nicht zugestellt. Geplant: Mail (SMTP-Zugang aus 1Password über ESO) und externes Lebenszeichen über die Watchdog-Warnung.
