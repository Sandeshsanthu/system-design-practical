import redis
import os

# Use the same credentials from your docker-compose
r = redis.Redis(
    host="pdf-gen-redis-dil7md.serverless.use1.cache.amazonaws.com",
    port=6379,
    username="appuser",
    password="f8t8k3JCKwVQPbYxZjzcIFpulPVaE0zK",
    ssl=True,
    ssl_cert_reqs=None
)

print(f"Queue Length: {r.llen('job_queue')}")
