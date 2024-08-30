import os
import logging
import sys
from uvicorn import Config, Server
from loguru import logger

LOG_LEVEL = logging.getLevelName(os.environ.get("LOG_LEVEL", "DEBUG"))
JSON_LOGS = True if os.environ.get("JSON_LOGS", "0") == "1" else False

class InterceptHandler(logging.Handler):
    def emit(self, record):
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno

        frame, depth = sys._getframe(6), 6
        while frame and frame.f_code.co_filename == logging.__file__:
            frame = frame.f_back
            depth += 1

        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )

def setup_logging():
    logging.root.handlers = [InterceptHandler()]
    logging.root.setLevel(LOG_LEVEL)

    for name in logging.root.manager.loggerDict.keys():
        logging.getLogger(name).handlers = []
        logging.getLogger(name).propagate = True

    # Add a filter to exclude /metrics logs in configure: "filter": filter_metrics
    def filter_metrics(record):
        message = record["message"]
        return "/metrics" not in message and "loki-write.logging.svc.cluster.local" not in message

    logger.configure(handlers=[{"sink": sys.stdout, "serialize": JSON_LOGS}])

if __name__ == "__main__":
    server = Server(
        Config(
            "app.main:app",
            host="0.0.0.0",
            port=8080,
            log_level=LOG_LEVEL,
        ),
    )

    setup_logging()
    server.run()
