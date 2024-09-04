import pyrqlite.dbapi2 as dbapi2
from typing import Any, Dict, List, Optional
from .database_service import DatabaseService

class RQLiteService(DatabaseService):
    def __init__(self, host: str, port: str):
        self._host = host
        self._port = int(port)
        self._conn: Optional[dbapi2.Connection] = None

    async def __aenter__(self) -> 'RQLiteService':
        self._conn = dbapi2.connect(host=self._host, port=self._port)
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._conn:
            self._conn.close()

    async def select(self, query: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        with self._conn.cursor() as cursor:
            cursor.execute(query, tuple(params.values()))
            rows = cursor.fetchall()
            return [dict(row) for row in rows]

    async def select_one(self, query: str, params: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        with self._conn.cursor() as cursor:
            cursor.execute(query, tuple(params.values()))
            row = cursor.fetchone()
            return dict(row) if row else None

    async def upsert(self, query: str, params: Dict[str, Any]) -> None:
        with self._conn.cursor() as cursor:
            cursor.execute(query, tuple(params.values()))
            self._conn.commit()

    async def delete(self, query: str, params: Dict[str, Any]) -> None:
        with self._conn.cursor() as cursor:
            cursor.execute(query, tuple(params.values()))
            self._conn.commit()