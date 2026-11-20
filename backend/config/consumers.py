from channels.generic.websocket import AsyncJsonWebsocketConsumer


class LiveUpdatesConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket : positions live + notifications."""

    async def connect(self):
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            await self.close()
            return
        self.group = 'sig_sols_live'
        await self.channel_layer.group_add(self.group, self.channel_name)
        sub = self.scope.get('subprotocol')
        if sub:
            await self.accept(subprotocol=sub)
        else:
            await self.accept()
        await self.send_json({
            'type': 'connected',
            'user': user.username,
            'role': getattr(user, 'role', ''),
        })

    async def disconnect(self, code):
        if hasattr(self, 'group'):
            await self.channel_layer.group_discard(self.group, self.channel_name)

    async def receive_json(self, content):  # pyright: ignore[reportIncompatibleMethodOverride]
        if content.get('type') == 'ping':
            await self.send_json({'type': 'pong'})

    async def live_broadcast(self, event):
        await self.send_json(event.get('payload', {}))
