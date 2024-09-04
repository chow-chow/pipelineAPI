from os import getenv
from .database_service import DatabaseService
from .postgres import PostgresService
from .rqlite import RQLiteService

class UnsupportedDatabaseError(Exception):
    """Raised when an unsupported database type is provided in the environment"""
    def __init__(self, db_type: str):
        super().__init__(f"Unsupported database type: {db_type}")

def get_database_service() -> DatabaseService:
    db_type     = getenv("DB_TYPE", "postgres")
    host        = getenv("DB_HOST", "localhost")
    port        = getenv("DB_PORT", "5432" if db_type == "postgres" else "4001")
    user        = getenv("DB_USER", "")
    password    = getenv("DB_PASSWORD", "")
    dbname      = getenv("DB_NAME", "")

    match db_type:
        case "postgres":
            return PostgresService(host, port, user, password, dbname)
        case "rqlite":
            return RQLiteService(host, port)
        case _:
            raise UnsupportedDatabaseError(db_type)