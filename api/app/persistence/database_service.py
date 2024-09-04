from abc import ABC, abstractmethod
from typing import Any, Dict, List

# DB Contract for the Database Service: every database implementation must provide these methods
class DatabaseService(ABC):
    @abstractmethod
    async def select(self, query: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        pass

    async def select_one(self, query: str, params: Dict[str, Any]) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def upsert(self, query: str, params: Dict[str, Any]) -> None:
        pass

    @abstractmethod
    async def delete(self, query: str, params: Dict[str, Any]) -> None:
        pass