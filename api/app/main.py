from fastapi import FastAPI
from loguru import logger
from os import getenv
from multiprocessing import Queue
from logging_loki import LokiQueueHandler
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)

POD_NAME = getenv("POD_NAME", "Unknown Pod")

loki_application_handler = LokiQueueHandler(
    Queue(-1),
    url=getenv("LOKI_ENDPOINT"),
    tags={"dev_api": "pipeline-api", "pod": POD_NAME},
    version="1",
)

logger.add(loki_application_handler, level="INFO", filter=lambda record: "/metrics" not in record["message"] and "loki-write.logging.svc.cluster.local" not in record["message"])

@app.get("/")
def read_root():
    logger.info(f"Root endpoint was invoked by {POD_NAME}")
    return {"Hello": "World Dev!", "pod": POD_NAME}
