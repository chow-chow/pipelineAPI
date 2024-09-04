import asyncpg
from asyncpg import Connection, Record
from typing import List, Dict, Any, Optional
from .database_service import DatabaseService

def _build_dsn(host: str, port: str, user: str, password: str, dbname: str) -> str:
    return f"postgresql://{user}:{password}@{host}:{port}/{dbname}"

class PostgresService(DatabaseService):
    def __init__(self, host: str, port: str, user: str, password: str, dbname: str):
        self._dsn = _build_dsn(host, port, user, password, dbname)
        self._conn: Optional[Connection] = None

    async def __aenter__(self) -> 'PostgresService':
        self._conn = await asyncpg.connect(self._dsn)
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._conn:
            await self._conn.close()

    async def select(self, query: str, params: Dict[str, Any]) -> List[Record]:
        return await self._conn.fetch(query, *params.values())

    async def select_one(self, query: str, params: Dict[str, Any]) -> Optional[Record]:
        return await self._conn.fetchrow(query, *params.values())

    async def upsert(self, query: str, params: Dict[str, Any]) -> None:
        await self._conn.execute(query, *params.values())

    async def delete(self, query: str, params: Dict[str, Any]) -> None:
        await self._conn.execute(query, *params.values())