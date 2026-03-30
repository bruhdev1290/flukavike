# Fluxer API Reference for Mobile Client

> Based on official docs at https://docs.fluxer.app/

---

## 🔗 Base URLs

| Service | URL |
|---------|-----|
| HTTP API | `https://api.fluxer.app/v1/` |
| User Content CDN | `https://fluxerusercontent.com/` |
| Static Assets | `https://fluxerstatic.com/` |
| WebSocket Gateway | `wss://gateway.fluxer.app/` |

---

## 🔐 Authentication

Fluxer supports multiple authentication methods:

### 1. Bearer Token (User Auth)
```
Authorization: Bearer YOUR_TOKEN
```

### 2. Bot Token
```
Authorization: Bot YOUR_BOT_TOKEN
```

### 3. Session Token
```
Authorization: YOUR_SESSION_TOKEN
```

### 4. OAuth2
- Authorization URL: `/oauth2/authorize`
- Token URL: `/oauth2/token`
- Scopes: `identify`, `email`, `guilds`, `connections`, `bot`, `admin`

---

## 👤 Users

### Get Current User
```
GET /users/@me
```

**Response:**
```json
{
  "id": "123456789012345678",
  "username": "alice",
  "discriminator": "0001",
  "global_name": "Alice Chen",
  "avatar": "a1b2c3d4...",
  "banner": "e5f6g7h8...",
  "accent_color": 16711680,
  "bot": false,
  "system": false,
  "mfa_enabled": true,
  "locale": "en-US",
  "email": "alice@example.com",
  "verified": true,
  "flags": 0,
  "premium_type": 2,
  "public_flags": 0
}
```

### Get User
```
GET /users/{user_id}
```

### Modify Current User
```
PATCH /users/@me
```

**Body:**
```json
{
  "username": "newname",
  "global_name": "New Display Name",
  "avatar": "data:image/png;base64,..."
}
```

### Get User Guilds
```
GET /users/@me/guilds
```

### Leave Guild
```
DELETE /users/@me/guilds/{guild_id}
```

### Get User DMs
```
GET /users/@me/channels
```

### Create DM
```
POST /users/@me/channels
```

**Body:**
```json
{
  "recipient_id": "123456789012345678"
}
```

---

## 🏰 Guilds (Servers)

### Get Guild
```
GET /guilds/{guild_id}
```

**Response:**
```json
{
  "id": "123456789012345678",
  "name": "Fluxer HQ",
  "icon": "a1b2c3d4...",
  "banner": "e5f6g7h8...",
  "owner_id": "123456789012345678",
  "region": "us-west",
  "afk_channel_id": null,
  "afk_timeout": 300,
  "verification_level": 1,
  "default_message_notifications": 0,
  "explicit_content_filter": 0,
  "roles": [...],
  "emojis": [...],
  "features": [...],
  "mfa_level": 0,
  "system_channel_id": "123456789012345678",
  "system_channel_flags": 0,
  "rules_channel_id": null,
  "max_presences": null,
  "max_members": 250000,
  "vanity_url_code": null,
  "description": "Official Fluxer community",
  "premium_tier": 0,
  "premium_subscription_count": 0,
  "preferred_locale": "en-US",
  "public_updates_channel_id": null,
  "max_video_channel_users": 25,
  "approximate_member_count": 15420,
  "approximate_presence_count": 4231,
  "welcome_screen": {...},
  "nsfw_level": 0
}
```

### Create Guild
```
POST /guilds
```

### Modify Guild
```
PATCH /guilds/{guild_id}
```

### Delete Guild
```
DELETE /guilds/{guild_id}
```

### Get Guild Channels
```
GET /guilds/{guild_id}/channels
```

### Create Guild Channel
```
POST /guilds/{guild_id}/channels
```

**Body:**
```json
{
  "name": "general",
  "type": 0,
  "topic": "General discussion",
  "bitrate": 64000,
  "user_limit": 0,
  "rate_limit_per_user": 0,
  "position": 0,
  "permission_overwrites": [],
  "parent_id": null,
  "nsfw": false
}
```

---

## 💬 Channels

### Get Channel
```
GET /channels/{channel_id}
```

**Response:**
```json
{
  "id": "123456789012345678",
  "type": 0,
  "guild_id": "123456789012345678",
  "position": 0,
  "permission_overwrites": [],
  "name": "general",
  "topic": "General discussion",
  "nsfw": false,
  "last_message_id": "123456789012345678",
  "bitrate": 64000,
  "user_limit": 0,
  "rate_limit_per_user": 0,
  "recipients": [],
  "icon": null,
  "owner_id": null,
  "application_id": null,
  "managed": false,
  "parent_id": null,
  "last_pin_timestamp": null,
  "rtc_region": null,
  "video_quality_mode": 1,
  "message_count": 0,
  "member_count": 0,
  "thread_metadata": null,
  "member": null,
  "default_auto_archive_duration": null,
  "permissions": null
}
```

### Modify Channel
```
PATCH /channels/{channel_id}
```

### Delete Channel
```
DELETE /channels/{channel_id}
```

### Get Channel Messages
```
GET /channels/{channel_id}/messages?limit=50&before={message_id}
```

**Query Parameters:**
- `around` - get messages around this id
- `before` - get messages before this id
- `after` - get messages after this id
- `limit` - max 100

### Create Message
```
POST /channels/{channel_id}/messages
```

**Body (JSON):**
```json
{
  "content": "Hello, world!",
  "nonce": "12345",
  "tts": false,
  "embeds": [],
  "allowed_mentions": {
    "parse": ["users", "roles", "everyone"],
    "roles": [],
    "users": [],
    "replied_user": false
  },
  "message_reference": {
    "message_id": "123456789012345678",
    "channel_id": "123456789012345678",
    "guild_id": "123456789012345678",
    "fail_if_not_exists": false
  },
  "components": [],
  "sticker_ids": [],
  "attachments": []
}
```

**Body (Multipart for files):**
```
--boundary
Content-Disposition: form-data; name="content"

Hello with attachment!
--boundary
Content-Disposition: form-data; name="file"; filename="image.png"
Content-Type: image/png

<binary data>
--boundary--
```

### Get Message
```
GET /channels/{channel_id}/messages/{message_id}
```

### Edit Message
```
PATCH /channels/{channel_id}/messages/{message_id}
```

### Delete Message
```
DELETE /channels/{channel_id}/messages/{message_id}
```

### Bulk Delete Messages
```
POST /channels/{channel_id}/messages/bulk-delete
```

**Body:**
```json
{
  "messages": ["123", "456", "789"]
}
```

### Create Reaction
```
PUT /channels/{channel_id}/messages/{message_id}/reactions/{emoji}/@me
```

### Delete Own Reaction
```
DELETE /channels/{channel_id}/messages/{message_id}/reactions/{emoji}/@me
```

### Delete User Reaction
```
DELETE /channels/{channel_id}/messages/{message_id}/reactions/{emoji}/{user_id}
```

### Get Reactions
```
GET /channels/{channel_id}/messages/{message_id}/reactions/{emoji}
```

### Delete All Reactions
```
DELETE /channels/{channel_id}/messages/{message_id}/reactions
```

---

## 📨 Messages

### Message Structure
```json
{
  "id": "123456789012345678",
  "channel_id": "123456789012345678",
  "guild_id": "123456789012345678",
  "author": {
    "id": "123456789012345678",
    "username": "alice",
    "global_name": "Alice",
    "avatar": "a1b2c3d4...",
    "bot": false
  },
  "member": {...},
  "content": "Hello, world!",
  "timestamp": "2024-01-15T12:34:56.789Z",
  "edited_timestamp": null,
  "tts": false,
  "mention_everyone": false,
  "mentions": [],
  "mention_roles": [],
  "mention_channels": [],
  "attachments": [],
  "embeds": [],
  "reactions": [
    {
      "count": 3,
      "me": true,
      "emoji": {
        "id": null,
        "name": "👍"
      }
    }
  ],
  "nonce": "12345",
  "pinned": false,
  "webhook_id": null,
  "type": 0,
  "activity": null,
  "application": null,
  "application_id": null,
  "message_reference": null,
  "flags": 0,
  "referenced_message": null,
  "interaction": null,
  "thread": null,
  "components": [],
  "sticker_items": [],
  "stickers": [],
  "position": null
}
```

---

## 🔔 Notifications

### Mark Channel as Read
```
POST /channels/{channel_id}/messages/{message_id}/ack
```

### Mark Guild as Read
```
POST /guilds/{guild_id}/ack
```

### Get Read States (WebSocket)
Comes through Gateway `READY` event.

---

## 🌐 WebSocket Gateway

### Get Gateway URL
```
GET /gateway
```

**Response:**
```json
{
  "url": "wss://gateway.fluxer.app/"
}
```

### Gateway Payload Structure
```json
{
  "op": 0,
  "d": {},
  "s": 42,
  "t": "EVENT_NAME"
}
```

### Gateway Opcodes
| Code | Name | Description |
|------|------|-------------|
| 0 | Dispatch | Receive event |
| 1 | Heartbeat | Keep connection alive |
| 2 | Identify | Authenticate |
| 3 | Presence Update | Update status |
| 4 | Voice State Update | Join/leave voice |
| 6 | Resume | Resume connection |
| 7 | Reconnect | Reconnect immediately |
| 8 | Request Guild Members | Get member list |
| 9 | Invalid Session | Re-identify needed |
| 10 | Hello | Connection established |
| 11 | Heartbeat ACK | Server response |

### Gateway Events (Client Receives)
- `READY` - Initial connection
- `MESSAGE_CREATE` - New message
- `MESSAGE_UPDATE` - Edited message
- `MESSAGE_DELETE` - Deleted message
- `CHANNEL_CREATE` - New channel
- `CHANNEL_UPDATE` - Channel updated
- `CHANNEL_DELETE` - Channel deleted
- `GUILD_CREATE` - Guild info
- `TYPING_START` - User typing
- `PRESENCE_UPDATE` - Status change
- `MESSAGE_REACTION_ADD` - Reaction added
- `MESSAGE_REACTION_REMOVE` - Reaction removed
- `NOTIFICATION_CREATE` - New notification

---

## 🖼 CDN Endpoints

### User Avatar
```
GET /avatars/{user_id}/{avatar_hash}.{format}
```

### Guild Icon
```
GET /icons/{guild_id}/{icon_hash}.{format}
```

### Guild Banner
```
GET /banners/{guild_id}/{banner_hash}.{format}
```

### Custom Emoji
```
GET /emojis/{emoji_id}.{format}
```

### Attachments
```
GET /attachments/{channel_id}/{attachment_id}/{filename}
```

### Query Parameters
- `size` - 16, 32, 64, 128, 256, 512, 1024, 2048
- `format` - png, jpg, webp, gif
- `quality` - high, medium, low
- `animated` - true/false

### Default Avatar
```
GET https://fluxerstatic.com/avatars/{index}.png
```
where `index = user_id % 6`

---

## ⚠️ Error Codes

| Code | Meaning |
|------|---------|
| `UNKNOWN_ACCOUNT` | Unknown account |
| `UNKNOWN_APPLICATION` | Unknown application |
| `UNKNOWN_CHANNEL` | Unknown channel |
| `UNKNOWN_GUILD` | Unknown guild |
| `UNKNOWN_INTEGRATION` | Unknown integration |
| `UNKNOWN_INVITE` | Unknown invite |
| `UNKNOWN_MEMBER` | Unknown member |
| `UNKNOWN_MESSAGE` | Unknown message |
| `UNKNOWN_ROLE` | Unknown role |
| `UNKNOWN_USER` | Unknown user |
| `UNKNOWN_EMOJI` | Unknown emoji |
| `BOT_PROHIBITED_ENDPOINT` | Bot cannot use endpoint |
| `BOTS_CANNOT_USE_THIS_ENDPOINT` | Bot restricted |
| `RATE_LIMITED` | Too many requests |
| `UNAUTHORIZED` | Invalid token |
| `ACCESS_DENIED` | Missing permissions |

---

## 📱 Mobile Client Implementation Notes

### 1. Authentication Flow
```swift
// 1. User enters instance + credentials
// 2. POST /auth/login
// 3. Store bearer token in Keychain
// 4. Connect WebSocket with token
// 5. Receive READY event with user data
```

### 2. Real-time Messages
```swift
// WebSocket connection
// - Auto-reconnect on disconnect
// - Heartbeat every 30s
// - Resume after reconnect
```

### 3. Media Loading
```swift
// Use CDN URLs with size optimization
// - Avatars: size=128 for list, 512 for profile
// - Images: size=800 for preview
// - Support WebP format
```

### 4. Rate Limiting
```swift
// Handle 429 responses
// - Retry-After header
// - Exponential backoff
// - Queue requests
```

---

*For complete API reference, visit https://docs.fluxer.app/*
