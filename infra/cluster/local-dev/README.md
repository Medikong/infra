# Local dependencies

Kubernetes 프로비저닝과 독립적으로 PostgreSQL, Redis, Kafka를 Docker Compose로 실행합니다.

```bash
cd infra/cluster/local-dev
docker compose up -d
docker compose ps
docker compose down
```

volume까지 제거할 때만 `docker compose down -v`를 사용합니다.
