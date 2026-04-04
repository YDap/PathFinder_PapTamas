# Pathfinder App — Technical Documentation
> Prepared for university submission  
> Project by: YDap (Pap Tamás)  
> Date: April 2026

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Database Layer](#4-database-layer)
5. [Backend — Node.js / Express](#5-backend--nodejs--express)
6. [Frontend — Flutter](#6-frontend--flutter)
7. [Feature Deep-Dives](#7-feature-deep-dives)
8. [Data Flow Diagrams](#8-data-flow-diagrams)
9. [API Reference](#9-api-reference)
10. [Key Technical Decisions](#10-key-technical-decisions)
11. [Development Environment & Setup](#11-development-environment--setup)

---

## 1. Project Overview

**Pathfinder** is a mobile application for Android designed to help users discover and explore natural and historical points of interest in Romania. It targets hikers, nature enthusiasts, and tourists.

### Core Capabilities

| Capability | Description |
|---|---|
| Interactive map | Full-screen map centered on Romania with real-time tile loading |
| Place discovery | Browse lakes, caves, ruins, peaks, springs, and viewpoints |
| Filtering | Filter by category, elevation range, and distance from current location |
| AI Assistant | Natural language search ("show me ruins within 60km, best rated") |
| Navigation | Turn-by-turn route calculation to any place |
| Star rating | Users can rate places 1–5 stars; average shown on every marker |
| SOS | Share current GPS coordinates via any messaging app in an emergency |
| Profile | User account with profile picture management |

### Data Origin

Place data was sourced from **OpenStreetMap (OSM)** — a free, open geographic database. The data was imported, cleaned, and stored in a local PostgreSQL database with PostGIS geometry support.

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ANDROID PHONE                            │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              Flutter App (Dart)                     │   │
│   │                                                     │   │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │   │
│   │  │  Screens │  │ Widgets  │  │    Services       │  │   │
│   │  │          │  │          │  │                   │  │   │
│   │  │ home     │  │ places   │  │ places_api.dart   │  │   │
│   │  │ login    │  │ _layer   │  │ auth_service.dart │  │   │
│   │  │ register │  │          │  │ routing_service   │  │   │
│   │  │ splash   │  │ ai_chat  │  │ sos_service       │  │   │
│   │  │          │  │ _sheet   │  │ profile_service   │  │   │
│   │  └──────────┘  └──────────┘  └──────────────────┘  │   │
│   └──────────────────────┬──────────────────────────────┘   │
│                          │ HTTP via USB tunnel               │
│                          │ (adb reverse tcp:3001 tcp:3001)   │
└──────────────────────────┼──────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │   Node.js / Express     │
              │   Backend  :3001        │
              │                         │
              │  ┌─────────────────┐    │
              │  │  placesRoutes   │    │
              │  │  aiRoutes       │    │
              │  └────────┬────────┘    │
              │           │             │
              │  ┌────────▼────────┐    │
              │  │ placesController│    │
              │  │ aiController    │    │
              │  └────────┬────────┘    │
              └───────────┼─────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
┌────────▼───────┐  ┌─────▼──────┐  ┌─────▼──────────┐
│  PostgreSQL 17 │  │  Firebase  │  │  OpenRouter AI  │
│  + PostGIS     │  │  Auth      │  │  (OpenAI API    │
│                │  │            │  │   compatible)   │
│  places        │  │  Verifies  │  │                 │
│  place_ratings │  │  JWT tokens│  │  LLM model:     │
│                │  │            │  │  liquid/lfm-2.5 │
└────────────────┘  └────────────┘  └────────────────┘
```

### 2.2 Key Architectural Decisions

- **Flutter → Backend only**: The Flutter app never connects directly to the database. All data goes through the Express REST API.
- **USB tunnel (adb reverse)**: During development, the phone connects to the local backend via a USB tunnel. `adb reverse tcp:3001 tcp:3001` forwards requests from the phone's `127.0.0.1:3001` to the developer's PC port 3001.
- **Firebase Auth in both layers**: Firebase issues a JWT token on login. The Flutter app sends this token with protected API requests. The backend verifies it using the Firebase Admin SDK.
- **AI logic in backend**: The AI API key is never sent to the phone — all LLM calls happen server-side.

---

## 3. Technology Stack

### 3.1 Frontend

| Technology | Version | Purpose |
|---|---|---|
| Flutter | 3.x | Cross-platform mobile UI framework |
| Dart | 3.3+ | Programming language for Flutter |
| flutter_map | ^7.0.0 | Interactive map widget (OpenStreetMap) |
| latlong2 | ^0.9.0 | Geographic coordinate model |
| geolocator | ^14.0.2 | GPS / device location |
| firebase_auth | ^6.1.1 | User authentication |
| firebase_storage | ^13.0.3 | Cloud file storage |
| http | ^1.2.2 | HTTP client for REST calls |
| image_picker | ^1.0.4 | Camera / gallery image selection |
| share_plus | ^12.0.1 | Native share sheet (SOS feature) |
| url_launcher | ^6.3.1 | Open URLs / maps |
| shared_preferences | ^2.2.2 | Local key-value cache |
| google_fonts | ^6.2.1 | Custom typography |

### 3.2 Backend

| Technology | Version | Purpose |
|---|---|---|
| Node.js | 22.x | JavaScript runtime |
| Express | ^4.18.2 | HTTP server / routing framework |
| pg | ^8.11.3 | PostgreSQL client for Node.js |
| firebase-admin | ^13.7.0 | Verify Firebase JWTs server-side |
| openai | ^4.x | OpenRouter API client (OpenAI-compatible) |
| dotenv | ^16.4.5 | Load environment variables from `.env` |
| nodemon | ^3.0.0 | Auto-restart server on file changes (dev) |
| cors | ^2.8.5 | Enable cross-origin HTTP requests |

### 3.3 Database

| Technology | Purpose |
|---|---|
| PostgreSQL 17 | Relational database |
| PostGIS extension | Spatial/geographic data types and queries |
| pgAdmin 4 | GUI database management tool |

### 3.4 External Services

| Service | Usage | Cost |
|---|---|---|
| Firebase Authentication | User login / registration (email+password) | Free (Spark plan) |
| OpenStreetMap / CartoCDN | Map tiles (dark + light theme) | Free |
| OSRM (osrm-project.org) | Route calculation between two GPS points | Free public API |
| OpenRouter | AI API gateway (routes to free LLMs) | Free tier |
| liquid/lfm-2.5-1.2b-instruct | Language model for NL filter extraction | Free on OpenRouter |

---

## 4. Database Layer

### 4.1 PostgreSQL + PostGIS

The database runs locally on the developer's machine (PostgreSQL 17, port 5432). PostGIS is an extension that adds support for geographic objects — it allows the database to store GPS coordinates as geometry types and perform spatial queries like "find all places within X km of a point."

### 4.2 Schema

#### Table: `places`

```
┌─────────────────────────────────────────────────────────────┐
│                         places                              │
├──────────────┬──────────────────┬────────────────────────── ┤
│ Column       │ Type             │ Description                │
├──────────────┼──────────────────┼────────────────────────── ┤
│ id           │ text (PK)        │ Unique identifier          │
│ osm_id       │ text             │ Original OpenStreetMap ID  │
│ name         │ text             │ Place name                 │
│ category     │ text             │ lake/cave/ruin/peak/       │
│              │                  │ spring/viewpoint           │
│ elevation_m  │ integer          │ Altitude in meters (NULL   │
│              │                  │ if unknown)                │
│ description  │ text             │ Human-readable description │
│ images       │ jsonb            │ Array of image URLs        │
│ source       │ text             │ Data source label          │
│ tags         │ jsonb            │ Raw OSM key-value tags     │
│ geom         │ geometry (PostGIS│ Geographic point (lat/lng) │
└──────────────┴──────────────────┴────────────────────────── ┘
```

> Latitude and longitude are extracted from the geometry column using PostGIS functions:
> `ST_Y(geom::geometry)` → latitude, `ST_X(geom::geometry)` → longitude

#### Table: `place_ratings`

```
┌──────────────────────────────────────────────────────────────┐
│                       place_ratings                          │
├──────────────┬──────────────┬───────────────────────────────┤
│ Column       │ Type         │ Description                    │
├──────────────┼──────────────┼───────────────────────────────┤
│ id           │ serial (PK)  │ Auto-increment primary key     │
│ place_id     │ text (FK)    │ References places.id           │
│ user_id      │ text         │ Firebase UID of the voter      │
│ rating       │ integer      │ 1 to 5 star rating             │
│ created_at   │ timestamp    │ When the rating was submitted  │
└──────────────┴──────────────┴───────────────────────────────┘

Unique constraint: (place_id, user_id) — one rating per user per place.
Uses PostgreSQL UPSERT (INSERT ... ON CONFLICT DO UPDATE) to update
existing ratings instead of creating duplicates.
```

#### Entity-Relationship Diagram

```
┌──────────────────┐          ┌──────────────────────┐
│     places       │          │    place_ratings      │
│──────────────────│          │──────────────────────│
│ id  (PK)         │◄─────────│ place_id  (FK)        │
│ osm_id           │  1     N │ id        (PK)        │
│ name             │          │ user_id               │
│ category         │          │ rating  (1-5)         │
│ elevation_m      │          │ created_at            │
│ description      │          └──────────────────────┘
│ images (jsonb)   │
│ tags   (jsonb)   │
│ geom   (PostGIS) │
└──────────────────┘
```

### 4.3 Key PostGIS Queries

**Find places within a radius** (used by GET /places):
```sql
WHERE ST_DWithin(
  p.geom::geography,
  ST_MakePoint(longitude, latitude)::geography,
  radiusInMeters
)
```

**Calculate exact distance** (used by AI endpoint):
```sql
ST_Distance(p.geom::geography, ST_MakePoint($1, $2)::geography) / 1000
-- Result is in kilometers
```

> **Note:** `::geography` cast makes PostGIS use spherical Earth calculations (accurate in meters), rather than flat-plane degree-based calculations.

---

## 5. Backend — Node.js / Express

### 5.1 File Structure

```
backend/
├── app.js                    ← Express app setup, middleware, route mounting
├── server.js                 ← HTTP server, loads dotenv, starts on port 3001
├── .env                      ← Secret keys (not committed to git)
├── .gitignore                ← Excludes .env, node_modules, firebase key
├── package.json
│
├── controllers/
│   ├── placesController.js   ← All business logic for /places endpoints
│   └── aiController.js       ← AI query logic (OpenRouter + DB query)
│
├── routes/
│   ├── placesRoutes.js       ← Route definitions for /places
│   └── aiRoutes.js           ← Route definitions for /ai
│
├── middleware/
│   └── auth.js               ← Firebase JWT verification middleware
│
└── db/
    └── index.js              ← PostgreSQL connection pool (pg.Pool)
```

### 5.2 Request Lifecycle

```
Phone
  │
  │  HTTP Request
  ▼
app.js
  │
  ├─► cors()          — Adds CORS headers (allows cross-origin requests)
  ├─► express.json()  — Parses JSON request bodies
  │
  ├─► /places  ──► placesRoutes.js
  │       │
  │       ├─ Public:   GET /         → getPlaces
  │       ├─ Public:   GET /search   → searchPlaces
  │       ├─ Public:   GET /:id      → getPlaceById
  │       ├─ Protected: GET /ratings/my  → getMyRatings
  │       └─ Protected: POST /:id/rate   → ratePlace
  │              │
  │              └─► requireAuth middleware
  │                    │
  │                    ├─ Reads Authorization: Bearer <token>
  │                    ├─ Calls firebase-admin verifyIdToken()
  │                    ├─ Sets req.user.id = Firebase UID
  │                    └─ Calls next() or returns 401
  │
  └─► /ai  ──► aiRoutes.js
          │
          └─ POST /query  → queryAI
```

### 5.3 Environment Variables (.env)

```
PORT=3001
DB_USER=postgres
DB_HOST=localhost
DB_NAME=pathfinder
DB_PASSWORD=***
DB_PORT=5432
FIREBASE_PROJECT_ID=pathfinder-a57af
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json
OPENROUTER_API_KEY=sk-or-v1-***
```

### 5.4 Database Connection Pool

```javascript
// db/index.js
const { Pool } = require('pg');
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});
module.exports = pool;
```

A **connection pool** is used instead of individual connections. It maintains multiple persistent database connections and assigns them to incoming requests, avoiding the overhead of opening/closing a connection per request.

---

## 6. Frontend — Flutter

### 6.1 File Structure

```
lib/
├── main.dart                          ← App entry point, Firebase init
└── src/
    ├── app.dart                       ← MaterialApp, theme (dark/light)
    ├── routes.dart                    ← Named route definitions
    │
    ├── screens/
    │   ├── splash_screen.dart         ← Initial loading screen
    │   ├── login_screen.dart          ← Email/password sign-in
    │   ├── register_screen.dart       ← New account creation
    │   └── home_screen.dart           ← Main screen (map + all features)
    │
    ├── services/
    │   ├── places_api.dart            ← All HTTP calls to Express backend
    │   ├── auth_service.dart          ← Firebase Auth (login, register, logout)
    │   ├── routing_service.dart       ← OSRM route calculation
    │   ├── sos_service.dart           ← Emergency location sharing
    │   └── profile_service.dart       ← Profile image pick/upload
    │
    └── widgets/
        ├── places_layer.dart          ← Map markers, filtering, place detail sheet
        └── ai_chat_sheet.dart         ← AI assistant bottom sheet UI
```

### 6.2 State Management

The app uses **Flutter's built-in StatefulWidget** pattern — no external state management library (no Provider, Bloc, Riverpod, etc.). Each screen manages its own state with `setState()`.

Key state variables in `_HomeScreenState`:

```dart
LatLng? _currentLatLng           // User's GPS position
Set<String> _selectedCategories  // Active category filters
int? _minElevation               // Elevation filter lower bound
int? _maxElevation               // Elevation filter upper bound
double? _maxDistanceKm           // Max distance filter
bool _showAllLocations           // Show all pins without filter
Place? _navigationDestination    // Current nav target
List<LatLng> _routePolyline      // Route line on map
bool _isNavigating               // Nav mode active
String? _profileImageUrl         // Cached profile pic URL
```

### 6.3 Data Model — Place

```dart
class Place {
  final String id;
  final String name;
  final String category;       // lake, cave, ruin, peak, spring, viewpoint
  final int? elevationM;       // null if unknown
  final double latitude;
  final double longitude;
  final double? averageRating; // computed by SQL AVG()
  final int ratingCount;
  final String? description;
  final dynamic images;        // JSON array of image URLs
  final Map<String, dynamic>? tags;  // raw OSM tags
  final double? distanceKm;   // populated by AI endpoint only
}
```

### 6.4 Theme System

The app supports **dark and light mode**, detected from the device system setting:

```dart
// CartoCDN provides both dark and light tile sets
urlTemplate: Theme.of(context).brightness == Brightness.dark
    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'
```

The theme uses Material 3 with a custom green color scheme matching the app's hiking/nature identity.

---

## 7. Feature Deep-Dives

### 7.1 Authentication Flow

```
User enters email + password
          │
          ▼
   auth_service.dart
   FirebaseAuth.instance.signInWithEmailAndPassword()
          │
          ▼
   Firebase Auth servers validate credentials
          │
   ┌──────┴──────┐
   │ Success     │ Failure
   │             │
   ▼             ▼
Firebase      Show error
issues JWT    snackbar
token
   │
   ▼
App navigates to HomeScreen
   │
   ▼
For protected API calls (rating, my ratings):
   flutter app calls user.getIdToken()
   sends: Authorization: Bearer <JWT>
          │
          ▼
   Express backend: requireAuth middleware
   firebase-admin.verifyIdToken(token)
          │
   ┌──────┴──────┐
   │ Valid       │ Invalid
   │             │
   ▼             ▼
req.user.id   401 Unauthorized
= Firebase UID
   │
   ▼
Controller uses req.user.id
as the user identifier in DB queries
```

### 7.2 Map & Place Loading

The map uses the **flutter_map** package, which renders OpenStreetMap tiles from CartoCDN. Places are shown as colored circle markers.

**Loading strategy:** Places are loaded lazily — only when a filter is active or "Show All Locations" is toggled on. This prevents unnecessary API calls on app open.

**Viewport-based fetching:**
```
User pans/zooms map
        │
        ▼ (350ms debounce)
_loadNow() in PlacesLayerState
        │
        ▼
Calculate center + radius from visible bounds
        │
        ▼
GET /places?lat=&lng=&radius=
        │
        ▼
Backend: ST_DWithin spatial query
        │
        ▼
Client-side filtering applied:
  - Category filter
  - Distance from user filter
  - Elevation min/max filter
  (places with null elevation excluded
   when elevation filter is active)
        │
        ▼
Render markers on map
```

**Category color coding:**

| Category | Color | Icon |
|---|---|---|
| Lake | Blue Accent | pool |
| Cave | Brown | terrain |
| Ruin | Red Accent | account_balance |
| Peak | Deep Purple | landscape |
| Spring | Teal | water_drop |
| Viewpoint | Indigo | visibility |

### 7.3 Star Rating System

```
User taps marker → Place detail sheet opens
        │
        ▼
Sheet shows: name, category, elevation,
             average rating (★), description
        │
        ▼
User taps a star (1-5)
        │
        ▼
Flutter: getIdToken() → Authorization header
        │
        ▼
POST /places/:id/rate  { rating: 4 }
        │
        ▼
Backend: requireAuth validates token
        │
        ▼
PostgreSQL UPSERT:
INSERT INTO place_ratings (place_id, user_id, rating)
VALUES ($1, $2, $3)
ON CONFLICT (place_id, user_id)
DO UPDATE SET rating = EXCLUDED.rating
        │
        ▼
201 Created → snackbar "Rated 4 stars!"
→ places reload to show updated average
```

### 7.4 Navigation / Routing

When the user taps "Navigate" on a place, the app calculates a real road route using the **OSRM (Open Source Routing Machine)** public API — a free, open-source routing engine based on OpenStreetMap road data.

```
User taps "Navigate" on a place
        │
        ▼
_startNavigation(destination)
        │
        ▼
RoutingService.getRoute(currentLatLng, destinationLatLng)
        │
        ▼
HTTP GET to OSRM public API:
router.project-osrm.org/route/v1/driving/
  {lng1},{lat1};{lng2},{lat2}
  ?overview=full&geometries=polyline
        │
        ▼
Response: encoded polyline + distance in meters
        │
        ▼
Decode polyline → List<LatLng>
Draw blue route line on map
        │
        ▼
GPS position listener starts:
Geolocator.getPositionStream()
        │
        ▼
Every GPS update:
- Recalculate distance to destination
- Update progress bar
- Update distance display
        │
        ▼
User taps "Stop Navigation"
- Clear polyline
- Cancel position listener
```

### 7.5 AI Assistant Feature

This is the most technically complex feature. It bridges natural language input to structured database queries.

```
┌─────────────────────────────────────────────────────────────┐
│                    COMPLETE AI FLOW                         │
└─────────────────────────────────────────────────────────────┘

User types: "show me ruins within 60km, best rated"
+ current GPS coordinates (lat, lng)
        │
        ▼ POST /ai/query
        │ { message, lat, lng }
        │
        ▼
aiController.js
        │
        ▼
OpenRouter API call
Model: liquid/lfm-2.5-1.2b-instruct:free
        │
System prompt instructs model to extract:
  - category (ruin)
  - maxDistanceKm (60)
  - sortByRating (true)
  - minElevation, maxElevation, minRating (null)
        │
        ▼
Model returns raw JSON:
{
  "filters": {
    "category": "ruin",
    "maxDistanceKm": 60,
    "minElevation": null,
    "maxElevation": null,
    "minRating": null,
    "sortByRating": true
  },
  "message": "Searching for the best rated ruins within 60km!"
}
        │
        ▼
Backend builds dynamic SQL:
SELECT p.*, AVG(r.rating), distance_km
FROM places p
LEFT JOIN place_ratings r ON p.id = r.place_id
WHERE ST_DWithin(geom::geography, point::geography, 60000)
  AND p.category = 'ruin'
GROUP BY p.id
ORDER BY avg_rating DESC
LIMIT 10
        │
        ▼
Returns: { message, filters, places[] }
        │
        ▼
Flutter: AiChatSheet displays
  - AI message bubble
  - Place cards (name, category, elevation, rating, distance)
  - "Show on map" button → pans map to place
```

**Why the AI logic lives in the backend:**  
The LLM API key must stay secret — if it were in the Flutter app, anyone could extract it from the APK and use it. The backend acts as a secure proxy.

**LLM prompt engineering:**  
The system prompt uses few-shot examples (showing input→output pairs) to teach the model the exact JSON format required, even though it's a small 1.2B parameter model. Temperature is set to 0.1 (near-deterministic) to ensure consistent JSON structure.

### 7.6 SOS Feature

```
User taps SOS button
        │
        ▼
Geolocator.getCurrentPosition()
        │
        ▼
Builds message:
"🆘 SOS! I need help!
My location: https://maps.google.com/?q=45.123,24.456
Coordinates: 45.123°N, 24.456°E"
        │
        ▼
share_plus: Share.share(message)
        │
        ▼
Android native share sheet opens
User picks: WhatsApp / SMS / Telegram / etc.
```

---

## 8. Data Flow Diagrams

### 8.1 Regular Place Search (Filter Mode)

```
Flutter App                 Express Backend           PostgreSQL
    │                             │                       │
    │  GET /places                │                       │
    │  ?lat=45.77                 │                       │
    │  &lng=24.97                 │                       │
    │  &radius=0.5     ──────────►│                       │
    │                             │  SELECT places WHERE  │
    │                             │  ST_DWithin(...)  ───►│
    │                             │                       │
    │                             │◄── rows (JSON) ───────│
    │◄── JSON array of places ────│                       │
    │                             │                       │
    │  (Client-side filtering)    │                       │
    │  - category                 │                       │
    │  - elevation                │                       │
    │  - distance                 │                       │
    │                             │                       │
    │  Render markers on map      │                       │
```

### 8.2 AI Query Flow

```
Flutter App           Express Backend        OpenRouter       PostgreSQL
    │                       │                    │                │
    │  POST /ai/query        │                    │                │
    │  {message, lat, lng}   │                    │                │
    │  ────────────────────► │                    │                │
    │                        │  POST chat/        │                │
    │                        │  completions  ────►│                │
    │                        │  (with system      │                │
    │                        │   prompt +         │                │
    │                        │   user message)    │                │
    │                        │                    │ LLM inference  │
    │                        │◄── JSON filters ───│                │
    │                        │                    │                │
    │                        │  Dynamic SQL query              ───►│
    │                        │  (built from filters)              │
    │                        │◄────────────────── matching places ─│
    │◄── {message, places} ──│                    │                │
    │                        │                    │                │
    │  Show AI bubble +       │                    │                │
    │  place cards            │                    │                │
```

### 8.3 Authentication Flow

```
Flutter App          Firebase Auth         Express Backend    PostgreSQL
    │                     │                      │                │
    │  signIn(email, pw)  │                      │                │
    │  ─────────────────► │                      │                │
    │◄── JWT token ───────│                      │                │
    │                     │                      │                │
    │  POST /places/:id/rate                      │                │
    │  Authorization: Bearer <JWT>                │                │
    │  ──────────────────────────────────────────►│                │
    │                     │  verifyIdToken(JWT)   │                │
    │                     │◄─────────────────────│                │
    │                     │─── UID ─────────────►│                │
    │                     │                      │  INSERT rating │
    │                     │                      │  ─────────────►│
    │◄── 201 Created ─────────────────────────── │                │
```

---

## 9. API Reference

Base URL: `http://127.0.0.1:3001` (via USB tunnel during development)

### 9.1 Places Endpoints

#### GET /places
Fetch places within a geographic area.

**Query parameters:**

| Param | Type | Required | Description |
|---|---|---|---|
| lat | float | Yes | Center latitude |
| lng | float | Yes | Center longitude |
| radius | float | No | Radius in degrees (default 0.05 ≈ 5.5km) |

**Response:** Array of Place objects
```json
[
  {
    "id": "node/123456",
    "name": "Lacul Roșu",
    "category": "lake",
    "elevation_m": 983,
    "latitude": 46.773,
    "longitude": 25.817,
    "avg_rating": "4.2",
    "rating_count": "15",
    "description": "...",
    "images": [],
    "tags": {}
  }
]
```

---

#### GET /places/search
Full-text search across name, category, and description.

**Query parameters:**

| Param | Type | Required | Description |
|---|---|---|---|
| q | string | Yes | Search term |

---

#### GET /places/:id
Single place by ID.

---

#### POST /places/:id/rate *(requires auth)*
Submit or update a star rating.

**Headers:** `Authorization: Bearer <Firebase JWT>`

**Body:**
```json
{ "rating": 4 }
```

**Response:** `201 Created` with the rating row.

---

#### GET /places/ratings/my *(requires auth)*
All places rated by the currently logged-in user.

**Headers:** `Authorization: Bearer <Firebase JWT>`

---

### 9.2 AI Endpoint

#### POST /ai/query
Natural language place search.

**Body:**
```json
{
  "message": "show me ruins within 60km, best rated",
  "lat": 45.7489,
  "lng": 21.2087
}
```

**Response:**
```json
{
  "message": "Looking for the best rated ruins within 60km of you!",
  "filters": {
    "category": "ruin",
    "maxDistanceKm": 60,
    "minElevation": null,
    "maxElevation": null,
    "minRating": null,
    "sortByRating": true
  },
  "places": [
    {
      "id": "...",
      "name": "Cetatea Devei",
      "category": "ruin",
      "elevation_m": 371,
      "latitude": 45.879,
      "longitude": 22.908,
      "avg_rating": 4.5,
      "rating_count": 8,
      "distance_km": 43.2
    }
  ]
}
```

---

## 10. Key Technical Decisions

### 10.1 Why Flutter?
Flutter compiles to native ARM code and provides a single codebase for Android (and potentially iOS in the future). The widget-based UI model allowed rapid development of the custom map interface with overlaid filters, navigation panel, and bottom sheets.

### 10.2 Why Express over a full framework?
The backend requirements are straightforward REST endpoints with database access. Express provides exactly what's needed with minimal boilerplate. Django, Spring, or Laravel would add unnecessary complexity.

### 10.3 Why PostGIS?
Geographic distance calculations on a sphere (Earth) cannot be done accurately with plain SQL. PostGIS provides:
- Proper spherical distance calculation (`ST_DWithin` with `::geography`)
- Efficient spatial indexing (GiST index on geometry columns)
- Industry-standard spatial SQL functions

### 10.4 Why adb reverse instead of a deployed server?
During development/testing, running a local server avoids cloud hosting costs and latency. The `adb reverse` technique tunnels the phone's TCP connection through the USB cable to the developer's machine, simulating a real server without any internet round-trip.

### 10.5 Why OpenRouter for AI?
- Free tier with no credit card required
- Aggregates many open-source LLMs under a single OpenAI-compatible API
- Switching models requires changing one string (the model ID)
- The OpenAI-compatible format means the `openai` npm package works without modification

### 10.6 Client-side vs Server-side filtering
The places endpoint returns all places in the viewport; filtering (category, elevation, distance) is done **client-side** in Flutter. This simplifies the backend and allows instant filter changes without a new API call. The trade-off is that the backend sends more data than needed, but for the scale of this app (Romania, ~few thousand POIs) this is acceptable.

The **AI endpoint** uses server-side filtering because it needs to search the entire database (not just the viewport), and the LLM determines the filter criteria dynamically.

---

## 11. Development Environment & Setup

### 11.1 Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Flutter SDK | 3.x | Build and run Flutter app |
| Android Studio / VS Code | Latest | IDE |
| Node.js | 22.x | Run backend |
| PostgreSQL | 17 | Database |
| pgAdmin 4 | Latest | DB management |
| Android SDK (adb) | Latest | USB device communication |

### 11.2 Starting the Backend

```bash
cd D:\projektek\backend
npm run dev          # starts nodemon → auto-restarts on file changes
# Output: "Pathfinder server running on port 3001"
```

### 11.3 Connecting Phone for Development

Run every time you reconnect USB or open a new terminal:

```powershell
$adb = 'C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe'
& $adb kill-server
& $adb start-server
& $adb devices                    # verify phone is listed
& $adb reverse tcp:3001 tcp:3001  # tunnel backend to phone
```

### 11.4 Running the Flutter App

```bash
cd X:\ALLAMVIZSGA_PROJEKT\pathfinder_app
flutter run           # deploys to connected Android device
```

Hot reload shortcuts during development:
- `r` — hot reload (preserves state)
- `R` — hot restart (resets state)
- `q` — quit

### 11.5 Project Repositories

| Repository | URL | Branch |
|---|---|---|
| Flutter App | github.com/YDap/PathFinder_PapTamas | main |
| Backend | github.com/YDap/pathfinder_backend | main |

### 11.6 Sensitive Files (Not in Git)

| File | Why excluded |
|---|---|
| `backend/.env` | Contains DB password and API keys |
| `backend/firebase-service-account.json` | Private Firebase admin credentials |
| `backend/node_modules/` | Regenerated via `npm install` |

---

## Appendix: Quick Reference

### Category Icons & Colors

```
lake       → 🔵 Blue Accent    (pool icon)
cave       → 🟤 Brown          (terrain icon)
ruin       → 🔴 Red Accent     (account_balance icon)
peak       → 🟣 Deep Purple    (landscape icon)
spring     → 🟢 Teal           (water_drop icon)
viewpoint  → 🔷 Indigo         (visibility icon)
```

### Elevation Behavior

- If no elevation filter is set: all places shown regardless of elevation data
- If elevation filter is active: **only places with confirmed elevation data that meet the threshold are shown** — places with unknown elevation are excluded

### AI Assistant Example Queries

```
"best rated lake nearby"
→ category: lake, sortByRating: true, maxDistanceKm: 30

"ruins within 80km"
→ category: ruin, maxDistanceKm: 80

"peaks above 2000m elevation"
→ category: peak, minElevation: 2000

"viewpoints with rating above 4"
→ category: viewpoint, minRating: 4, sortByRating: true

"something interesting close to me"
→ category: null, maxDistanceKm: 30, sortByRating: true
```

---

*Documentation generated April 2026. Project: Pathfinder — Romania Nature Discovery App.*
