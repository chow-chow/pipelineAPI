from multiprocessing import Queue
from os import getenv

from fastapi import FastAPI, Depends
from logging_loki import LokiQueueHandler
from loguru import logger
from prometheus_fastapi_instrumentator import Instrumentator

from persistence.get_db import get_database_service
from persistence.database_service import DatabaseService

app = FastAPI()
Instrumentator().instrument(app).expose(app)

POD_NAME = getenv("POD_NAME", "Unknown Pod")

loki_application_handler = LokiQueueHandler(
    Queue(-1),
    url=getenv("LOKI_ENDPOINT"),
    tags={"dev_api": "pipeline-api", "pod": POD_NAME},
    version="1",
)

logger.add(loki_application_handler, level="INFO",
           filter=lambda record: "/metrics" not in record["message"] and "loki-write.logging.svc.cluster.local" not in
                                 record["message"])


@app.get("/")
def read_root():
    logger.info(f"Root endpoint was invoked by {POD_NAME}")
    return {"Hello": "World Dev!", "pod": POD_NAME}


@app.get("/items/")
async def read_items(db_service: DatabaseService = Depends(get_database_service)):
    query = "SELECT * FROM items"
    items = await db_service.select(query, {})
    return items