# Terraria Server

Journey Mode world for local multiplayer.

## Deployment

```bash
kubectl apply -f kubernetes/games/terraria/
```

## World Selection

After pod starts, the server prompts for world selection. Attach to the container and enter the world number:

```bash
kubectl attach -n terraria $(kubectl get pods -n terraria -o name) -it
# Enter: 1
# Detach: Ctrl+P, Ctrl+Q
```

## Connection

- IP: 192.168.1.230
- Port: 7777
- World: AlbrechtsServerwelt (Journey Mode)

Note: Only Journey Mode characters can join.

## Management

```bash
# Logs
kubectl logs -n terraria -l app=terraria -f

# Restart
kubectl rollout restart deployment terraria -n terraria
```

## Admin

In-game: `/setup <token>` (token shown in logs on startup)
