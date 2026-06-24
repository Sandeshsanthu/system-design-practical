# filename: app/websocket_manager.py

from fastapi import WebSocket
from typing import Dict, List, Set
import json
import logging

logger = logging.getLogger(__name__)


class ConnectionManager:
    """
    Manages WebSocket connections for real-time updates

    Supports:
    - Multiple clients per event
    - Broadcasting seat updates
    - Connection lifecycle management
    """

    def __init__(self):
        # event_id -> list of WebSocket connections
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # Track all connections globally
        self.all_connections: Set[WebSocket] = set()

    async def connect(self, websocket: WebSocket, event_id: str):
        """Connect a client to event updates"""
        await websocket.accept()

        if event_id not in self.active_connections:
            self.active_connections[event_id] = []

        self.active_connections[event_id].append(websocket)
        self.all_connections.add(websocket)

        logger.info(
            f"Client connected to event {event_id}. Total connections: {len(self.active_connections[event_id])}")

        # Send connection confirmation
        await websocket.send_json({
            "type": "connected",
            "event_id": event_id,
            "message": f"Connected to event {event_id} updates"
        })

    def disconnect(self, websocket: WebSocket, event_id: str):
        """Disconnect a client"""
        if event_id in self.active_connections:
            if websocket in self.active_connections[event_id]:
                self.active_connections[event_id].remove(websocket)
                logger.info(f"Client disconnected from event {event_id}")

            # Clean up empty event connections
            if not self.active_connections[event_id]:
                del self.active_connections[event_id]

        self.all_connections.discard(websocket)

    async def broadcast_to_event(self, event_id: str, message: dict):
        """
        Broadcast message to all clients watching this event

        Message format:
        {
            "type": "seat_update",
            "event_id": "...",
            "seat_id": "...",
            "seat_number": "A1",
            "status": "booked",
            "booked_by": "...",
            "timestamp": "..."
        }
        """
        if event_id not in self.active_connections:
            return

        disconnected = []

        for connection in self.active_connections[event_id]:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Error sending message to client: {e}")
                disconnected.append(connection)

        # Clean up disconnected clients
        for connection in disconnected:
            self.disconnect(connection, event_id)

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        """Send message to specific client"""
        try:
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"Error sending personal message: {e}")

    def get_connection_count(self, event_id: str) -> int:
        """Get number of active connections for an event"""
        return len(self.active_connections.get(event_id, []))

    def get_total_connections(self) -> int:
        """Get total number of active connections"""
        return len(self.all_connections)


# Global connection manager instance
manager = ConnectionManager()
