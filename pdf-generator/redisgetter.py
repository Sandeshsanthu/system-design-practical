import redis


def get_redis_content():
    try:
        # decode_responses=True converts byte data (b'...') to readable strings
        r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

        print(f"Connected to Redis: {r.ping()}")
        print("-" * 30)

        keys = r.keys('*')
        if not keys:
            print("Redis is empty.")
            return

        for key in keys:
            k_type = r.type(key)
            print(f"Key: {key} | Type: {k_type}")

            # If it's a List (Common for Celery/BullMQ queues)
            if k_type == 'list':
                # Get all items from the list
                items = r.lrange(key, 0, -1)
                for i, item in enumerate(items):
                    print(f"  [{i}]: {item}")

            # If it's a String (Common for Celery task results)
            elif k_type == 'string':
                print(f"  Value: {r.get(key)}")

    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    get_redis_content()
