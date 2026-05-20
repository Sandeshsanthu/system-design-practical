import redis
import time

# Connect to your Redis services
r = redis.Redis(host='cache-headless.pdf-gen.svc.cluster.local', port=6379)

print("Starting to add 50 tasks to the queue...")
for i in range(50):
    # 'pdf_tasks' must match the listName in your ScaledObject
    r.lpush('pdf_tasks', f'task-{i}')
    print(f"Added task {i}")
    time.sleep(0.1) # Small delay to see it happen

print("Done! Check your pods now.")
