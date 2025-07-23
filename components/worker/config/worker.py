#!/usr/bin/env python3
"""
Redstone Background Worker Service
Following the "Built for Clarity" design philosophy
"""

import os
import time
import logging
import redis
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RedstoneWorker:
    """Background worker for processing tasks"""
    
    def __init__(self):
        self.redis_host = os.getenv('REDIS_HOST', 'redis')
        self.redis_port = int(os.getenv('REDIS_PORT', 6379))
        self.redis_db = int(os.getenv('REDIS_DB', 0))
        self.worker_id = os.getenv('WORKER_ID', 'worker-1')
        
        try:
            self.redis_client = redis.Redis(
                host=self.redis_host,
                port=self.redis_port,
                db=self.redis_db,
                decode_responses=True
            )
            logger.info(f"Connected to Redis at {self.redis_host}:{self.redis_port}")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self.redis_client = None
    
    def process_task(self, task_data):
        """Process a single task"""
        logger.info(f"Processing task: {task_data}")
        
        # Simulate task processing
        time.sleep(2)
        
        # Log completion
        logger.info(f"Task completed: {task_data}")
        return True
    
    def run(self):
        """Main worker loop"""
        logger.info(f"Starting Redstone worker {self.worker_id}")
        
        if not self.redis_client:
            logger.error("Redis client not available, exiting")
            return
        
        while True:
            try:
                # Check for tasks in the queue
                task = self.redis_client.blpop('redstone:tasks', timeout=30)
                
                if task:
                    task_data = task[1]
                    self.process_task(task_data)
                else:
                    # No tasks, log heartbeat
                    logger.info(f"Worker {self.worker_id} heartbeat - {datetime.now()}")
                    
            except KeyboardInterrupt:
                logger.info("Worker shutting down...")
                break
            except Exception as e:
                logger.error(f"Worker error: {e}")
                time.sleep(5)  # Wait before retrying

def health_check():
    """Simple health check for the worker"""
    return {
        'status': 'healthy',
        'service': 'redstone-worker',
        'worker_id': os.getenv('WORKER_ID', 'worker-1'),
        'timestamp': datetime.now().isoformat()
    }

if __name__ == '__main__':
    worker = RedstoneWorker()
    worker.run()
