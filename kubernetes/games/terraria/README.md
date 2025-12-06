# Terraria Server

## Deployment
```bash
kubectl apply -f kubernetes/games/terraria/
```

## Nach jedem Pod-Start: Welt auswählen
```bash
kubectl attach -n terraria $(kubectl get pods -n terraria -o name) -it
# Eingeben: 1
# Detach: Strg+P dann Strg+Q
```

## Server Management
```bash
# Status
kubectl get pods -n terraria
kubectl get svc -n terraria

# Logs
kubectl logs -n terraria -l app=terraria -f

# Neu starten
kubectl rollout restart deployment terraria -n terraria
```

## Verbinden
- IP: 192.168.1.230
- Port: 7777
- Welt: AlbrechtsServerwelt (Journey Mode)

## Admin Setup
Im Spiel: `/setup [TOKEN aus Logs]`

## Hinweis
Die Welt ist im **Journey Mode** - nur Journey Charaktere können joinen!
