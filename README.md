# Running Locally

```bash
npm i
docker build -t navikun:latest .
docker run -d -p 8080:8080 navikun:latest
caddy reverse-proxy --from localhost:443 --to localhost:8080
```

navigate to `https://localhost` in your browser
