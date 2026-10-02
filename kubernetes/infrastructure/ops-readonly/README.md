# ops-readonly: Nur-Lese-Zugang
ServiceAccount ops-readonly mit ClusterRole view plus ops-readonly-readonly-extra (Nodes, Metriken, CRDs von Longhorn, ArgoCD, MetalLB, Prometheus-Operator, External Secrets). Nur get, list, watch, keine Secrets.
Änderungen am Cluster laufen ausschließlich über Git und ArgoCD. Die kubeconfig liegt lokal unter ~/.kube/ops-readonly.yaml und ist nicht in Git.
Token: 30 Tage gültig, erzeugt am 02.10.2026, Ablauf ca. 01.11.2026. Erneuern mit Admin-kubeconfig: kubectl create token ops-readonly -n ops-readonly --duration=720h, dann in ~/.kube/ops-readonly.yaml eintragen.
Entzug: Application infrastructure läuft mit prune: false. Nach Entfernen aus Git zusätzlich Namespace ops-readonly und die ClusterRoleBindings ops-readonly-view und ops-readonly-readonly-extra manuell löschen.
