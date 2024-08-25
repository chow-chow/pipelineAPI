from fastapi import FastAPI
from loguru import logger
from os import getenv

app = FastAPI()

POD_NAME = getenv("POD_NAME", "Unknown Pod")

@app.get("/")
def read_root():
    logger.info(f"Root endpoint was invoked by {POD_NAME}")
    return {"Hello": "World", "pod": POD_NAME}