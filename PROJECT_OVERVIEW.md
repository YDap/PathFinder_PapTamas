# PathFinder — Átfogó Projektáttekintés

> Államvizsga-dolgozat alapanyag · Készítette: Pap Tamás (YDap)
> Ez a dokumentum **kizárólag a tényleges forráskódból, konfigurációs fájlokból és
> függőséglistákból** készült. Ahol valami nem derül ki egyértelműen a kódból, az
> `[ELLENŐRIZNI]` jelölést kapott.
>
> Vizsgált repók:
> - **Frontend (Flutter):** `X:\ALLAMVIZSGA_PROJEKT\pathfinder_app` — GitHub: `YDap/PathFinder_PapTamas`
> - **Backend (Node.js/Express):** `D:\projektek\backend` — GitHub: `YDap/pathfinder_backend`

---

## 0. Modul- és mappaösszefoglaló (mi található a projektben)

A projekt **két különálló git-repóból** áll. A frontend repó tartalmazza a régi
`DOCUMENTATION.md`-t (2026. április), amely már **elavult** — azóta jelentősen
kibővült a funkciókészlet (XP/szint, badge-ek, ranglista, admin panel, barátok,
közös navigáció, posztok/kommentek, időjárás, túrajelzés-útmutató). Ez a dokumentum
a **jelenlegi** kódállapotot rögzíti.

### Frontend (`lib/`)

| Modul | Fájl | Szerep |
|---|---|---|
| Belépési pont | `main.dart` | Firebase init, app indítás |
| App váz | `src/app.dart` | `MaterialApp`, téma (sötét/világos), `SharedPreferences` témakapcsoló |
| Útvonalak | `src/routes.dart` | Named route-ok (splash/login/register/home) |
| **Képernyők** | `src/screens/` | splash, login, register, home (3014 sor!), admin, friends, leaderboard, posts, stats |
| **Szolgáltatások** | `src/services/` | places_api, auth_service, level_service, routing_service, profile_service, sos_service, weather_service |
| **Widgetek** | `src/widgets/` | places_layer, ai_chat_sheet, create_post_sheet, hiking_signs_sheet, weather_sheet, zoom_out_hint |

### Backend (`D:\projektek\backend`)

| Modul | Tartalom |
|---|---|
| `app.js`, `server.js` | Express app + middleware + route mountolás + induló DDL; HTTP szerver indítása |
| `controllers/` | 10 controller: places, ai, posts, users, admin, friends, navigate, stats, leaderboard, version |
| `routes/` | 10 hozzá tartozó route-fájl |
| `middleware/auth.js` | Firebase JWT ellenőrző middleware (`requireAuth`) |
| `db/index.js` | PostgreSQL `pg.Pool` kapcsolat (DATABASE_URL vagy különálló env-ek) |
| `scripts/` | Python POI-importálók (`import_pois.py`, `import_pois_pbf.py`), `check_schema.py`, `romania-latest.osm.pbf` |
| `migration.sql`, `add_ratings.sql` (frontend repóban) | Részleges sémamódosító scriptek |
| `uploads/` | Feltöltött kép-fájlok (profilkép, poszt-kép) — statikusan kiszolgálva |

### Új modulok az áprilisi dokumentációhoz képest

`level_service.dart` (XP/szint/badge), `weather_service.dart`, `friends_screen`,
`leaderboard_screen`, `posts_screen`, `stats_screen`, `admin_screen`,
`hiking_signs_sheet`, `weather_sheet`, `zoom_out_hint`, `create_post_sheet` a
frontenden; a backenden pedig `friendsController`, `navigateController`,
`statsController`, `leaderboardController`, `usersController`, `adminController`,
`postsController`, `versionController`.

---

## 1. Projekt célja és áttekintése

A **PathFinder** egy Android mobilalkalmazás, amely segít a felhasználóknak romániai
természeti és kulturális látnivalók (csúcsok, tavak, barlangok, romok, források,
kilátópontok), valamint hasznos szolgáltatások (szállás, étterem, üzemanyag,
gyógyszertár, piac/üzlet, kávézó, bár, múzeum) felfedezésében. Célközönség: túrázók,
természetjárók, turisták.

**Fő funkciók felhasználói szemszögből** (a kódból igazoltan):

| Funkció | Leírás |
|---|---|
| Interaktív térkép | Romániára központosított, teljes képernyős térkép (CartoCDN csempék, sötét/világos) |
| Hely-felfedezés | Markerek kategória szerinti színezéssel; csak ráközelítéskor töltődnek (zoom ≥ 9) |
| Szűrés | Kategória, magasság (min/max), távolság a jelenlegi helytől; "Show All" mód |
| Természetnyelvi kereső ("AI") | Szöveges lekérdezés → szűrőkivonás → adatbázis-keresés (lásd 8. fejezet) |
| Navigáció | Valós gyalogos útvonal OSRM-en, élő pozíciókövetés, haladásjelző |
| Közös navigáció | Barát meghívása ugyanarra a célpontra, egymás pozíciójának élő követése |
| Csillagos értékelés | 1–5 csillag helyenként, átlag megjelenítése |
| Posztok és kommentek | Helyhez kötött bejegyzések képpel, kommentekkel |
| Barátok | Keresés, kérés küldése/elfogadása, eltávolítás |
| XP, szintek, badge-ek | Tevékenység-alapú pontozás, kategória- és teljesítmény-jelvények |
| Ranglista | Top 100 felhasználó össz-XP szerint |
| Profilstatisztika | Megtett km, navigációk, posztszám, kategóriánkénti látogatások |
| Admin panel | Bejelentett posztok/helyek kezelése, törlés (csak admin) |
| SOS | 112 hívás vagy aktuális pozíció megosztása |
| Időjárás | Óránkénti előrejelzés (Open-Meteo) |
| Túrajelzés-útmutató | Magyarázó lap a hegyi jelzésekről |
| Helyjavaslat / bejelentés | Új hely beküldése, illetve hely/poszt bejelentése moderációra |
| Beépített frissítés-ellenőrzés | GitHub Releases-ből vett legújabb APK verzió |

---

## 2. Teljes technológiai stack (verziókkal)

### 2.1 Frontend (`pubspec.yaml`)

| Csomag | Verzió | Cél |
|---|---|---|
| Flutter SDK | Dart `>=3.3.0 <4.0.0` | UI keretrendszer |
| `flutter_map` | ^7.0.0 | Interaktív térkép (OSM csempék) |
| `latlong2` | ^0.9.0 | Földrajzi koordináta-modell |
| `geolocator` | ^14.0.2 | GPS / eszközpozíció |
| `firebase_core` | ^4.2.0 | Firebase alap |
| `firebase_auth` | ^6.1.1 | Hitelesítés (email+jelszó) |
| `firebase_storage` | ^13.0.3 | Felhőtár `[ELLENŐRIZNI: a kódban nem találtam aktív storage-hívást — lehet, hogy nincs használatban]` |
| `http` | ^1.2.2 | REST hívások |
| `share_plus` | ^12.0.1 | Natív megosztás (SOS) |
| `url_launcher` | ^6.3.1 | URL/telefonhívás (`tel:112`) |
| `shared_preferences` | ^2.2.2 | Lokális kulcs-érték tár (téma, szűrők, profilkép-cache) |
| `image_picker` | ^1.0.4 | Kamera/galéria képválasztás |
| `package_info_plus` | ^8.1.0 | Alkalmazás-verzió olvasása |
| `google_fonts` | ^6.2.1 | Inter betűtípus |

Dev: `flutter_test`, `flutter_lints ^4.0.0`, `flutter_native_splash ^2.4.1`,
`flutter_launcher_icons ^0.13.1`.

### 2.2 Backend (`package.json`)

| Csomag | Verzió | Cél |
|---|---|---|
| `express` | ^4.18.2 | HTTP szerver / routing |
| `pg` | ^8.11.3 | PostgreSQL kliens |
| `firebase-admin` | ^13.7.0 | Firebase JWT ellenőrzés szerveroldalon |
| `multer` | ^2.1.1 | Multipart fájlfeltöltés (képek) |
| `cors` | ^2.8.5 | CORS fejlécek |
| `dotenv` | ^16.4.5 | `.env` betöltés |
| `openai` | ^6.33.0 | Telepítve, de a futó kódban nincs használva |
| `@google/genai` | ^1.48.0 | Telepítve, de nincs használva |
| `@google/generative-ai` | ^0.24.1 | **AI kereső — Gemini 2.0 Flash hívása** (`aiController.js`) |
| `@supabase/supabase-js` | ^2.45.0 | **Telepítve, de a backend JS-ben nincs `createClient` hívás** |
| `nodemon` (dev) | ^3.0.0 | Auto-restart fejlesztéskor |

> **2026-06-26 frissítés:** a `@google/generative-ai` csomagot az `aiController.js`
> most már aktívan használja (Gemini 2.0 Flash). Az `openai` és `@google/genai`
> csomagok és az `OPENROUTER_API_KEY` env-változó eltávolíthatók, ha takarítani
> szeretnénk. A `@supabase/supabase-js` szintén nincs használva.

### 2.3 Adatbázis

| Technológia | Szerep |
|---|---|
| PostgreSQL | Relációs adatbázis |
| PostGIS kiterjesztés | Térbeli típusok (`geometry`/`geography`), térbeli lekérdezések és GiST index |

A kapcsolat SSL-lel megy (`ssl: { rejectUnauthorized: false }`), amelyet a kód
kommentje **Railway PostgreSQL**-hez köt, a Python import-scriptek alapértelmezett
connection stringje viszont **Supabase**-re mutat (`db.YOUR_PROJECT.supabase.co`).
`[ELLENŐRIZNI: az éles adatbázis host valójában Railway-managed Postgres vagy Supabase? A DATABASE_URL env-érték dönti el — a kódból nem egyértelmű.]`

### 2.4 Külső szolgáltatások

| Szolgáltatás | Felhasználás |
|---|---|
| Firebase Authentication | Email+jelszavas regisztráció/bejelentkezés, JWT kibocsátás |
| OpenStreetMap / CartoCDN | Térképcsempék: `dark_all` és `light_all` |
| OSRM (`router.project-osrm.org`) | Gyalogos útvonalszámítás (`/route/v1/foot`) |
| Open-Meteo (`api.open-meteo.com`) | Óránkénti időjárás-előrejelzés |
| Overpass API / Geofabrik PBF | POI-importálás OSM-ből (Python scriptek, egyszeri) |
| GitHub Releases API | Legújabb APK verzió lekérdezése app-frissítéshez |

### 2.5 Hosting / fejlesztői eszközök

- **Backend:** Railway (`pathfinderbackend-production.up.railway.app`) — ez a base URL a Flutter kódban három helyen szerepel.
- **APK build/release:** GitHub Actions (`.github/workflows/release.yml`).
- **Build célok:** Android (elsődleges), de a repó tartalmaz `ios/`, `web/`, `windows/`, `linux/`, `macos/` mappákat is (Flutter alapértelmezett).

---

## 3. Rendszerarchitektúra

### 3.1 Magas szintű felépítés

```
┌──────────────────────────────────────────────────────────┐
│                    ANDROID (Flutter app)                   │
│  Screens ── Widgets ── Services (places_api, routing, …)   │
│        │            │            │                          │
│  Firebase Auth SDK  │       http kliens                     │
└────────┼────────────┼────────────┼─────────────────────────┘
         │            │            │ HTTPS REST
         │            │            ▼
         │            │   ┌──────────────────────────┐
         │            │   │  Express backend (Railway)│
         │            │   │  /places /ai /posts /users │
         │            │   │  /admin /friends /navigate │
         │            │   │  /stats /leaderboard /ver. │
         │            │   └─────────┬─────────┬────────┘
         │            │             │         │
         │            │             ▼         ▼
         │            │   ┌──────────────┐  ┌──────────────┐
         │            │   │ PostgreSQL   │  │ firebase-admin│
         │            │   │ + PostGIS    │  │ (JWT verify) │
         │            │   └──────────────┘  └──────────────┘
         │            ▼
         │   OSRM (útvonal), Open-Meteo (időjárás), CartoCDN (csempék)
         ▼
  Firebase Auth szerverek (token kibocsátás)
```

### 3.2 Tipikus kérés teljes adatáramlása (példa: csillagozás)

1. A felhasználó megnyit egy helyet és rányom egy csillagra (`places_layer.dart` / detail sheet).
2. A `PlacesApi.ratePlace()` lekéri a Firebase ID tokent (`user.getIdToken()`), és
   `POST /places/:id/rate` kérést küld `Authorization: Bearer <JWT>` fejléccel,
   `{ "rating": 4 }` törzzsel.
3. Az Express a `placesRoutes`-ban a `requireAuth` middleware-re irányít, amely a
   `firebase-admin verifyIdToken()`-nel ellenőrzi a tokent, és `req.user.id`-be teszi a Firebase UID-t.
4. A `placesController.ratePlace` validálja az 1–5 értéket, ellenőrzi a hely létezését,
   majd PostgreSQL **UPSERT**-tel ír a `place_ratings` táblába.
5. `201 Created` válasz a beírt sorral; a frontend snackbart mutat és újratölti a markereket.

### 3.3 Kulcsdöntések

- A Flutter app **soha nem kapcsolódik közvetlenül az adatbázishoz** — minden adat az Express REST API-n megy át.
- A **Firebase Auth mindkét rétegben** jelen van: a kliens kibocsát/csatol JWT-t, a backend `firebase-admin`-nal ellenőrzi.
- A **térbeli logika a backendben** van (PostGIS), a kategória/magasság/távolság szűrés viszont a kliensben fut (lásd 10. fejezet).

---

## 4. Mappastruktúra

### 4.1 Frontend

```
lib/
├── main.dart                       Firebase init + runApp
└── src/
    ├── app.dart                    MaterialApp, témák, témakapcsoló
    ├── routes.dart                 named route-ok
    ├── screens/
    │   ├── splash_screen.dart      1200ms splash, auth-állapot szerinti továbblépés
    │   ├── login_screen.dart       email+jelszó bejelentkezés
    │   ├── register_screen.dart    regisztráció
    │   ├── home_screen.dart        FŐ képernyő — térkép + szinte minden funkció (3014 sor)
    │   ├── posts_screen.dart       helyhez kötött posztok + kommentek
    │   ├── friends_screen.dart     barátok, kérések, keresés
    │   ├── leaderboard_screen.dart top 100 ranglista
    │   ├── stats_screen.dart       saját statisztika, XP, badge-ek (747 sor)
    │   └── admin_screen.dart       moderáció (poszt-/hely-bejelentések)
    ├── services/
    │   ├── places_api.dart         MINDEN REST hívás + összes adatmodell (1096 sor)
    │   ├── auth_service.dart       Firebase Auth wrapper
    │   ├── level_service.dart      XP/szint/badge logika (tisztán kliensoldali)
    │   ├── routing_service.dart    OSRM hívás + polyline-matematika
    │   ├── profile_service.dart    profilkép pick/upload + cache
    │   ├── sos_service.dart        112 hívás / pozíciómegosztás
    │   └── weather_service.dart    Open-Meteo óránkénti előrejelzés
    └── widgets/
        ├── places_layer.dart       térkép-markerréteg, viewport-alapú betöltés (894 sor)
        ├── ai_chat_sheet.dart      természetnyelvi kereső UI
        ├── create_post_sheet.dart  posztkészítő lap
        ├── hiking_signs_sheet.dart túrajelzés-útmutató
        ├── weather_sheet.dart      időjárás-megjelenítő lap
        └── zoom_out_hint.dart      "közelíts rá" tipp overlay
```

### 4.2 Backend

```
backend/
├── server.js                  dotenv + app.listen(PORT)
├── app.js                      Express setup, CORS, statikus /uploads,
│                               induló DDL (CREATE TABLE IF NOT EXISTS …),
│                               GiST index, route-mountolás, 404 + hibakezelő
├── db/index.js                 pg.Pool (DATABASE_URL vagy DB_* env-ek)
├── middleware/auth.js          requireAuth — firebase-admin verifyIdToken
├── controllers/
│   ├── placesController.js     places CRUD, rating, suggest, report
│   ├── aiController.js          természetnyelvi kereső (Gemini 2.0 Flash + regex fallback)
│   ├── postsController.js       posztok, kommentek, poszt-bejelentés
│   ├── usersController.js       profilkép fel-/letöltés, user upsert
│   ├── friendsController.js     barát-kapcsolatok
│   ├── navigateController.js    közös navigáció (session + pozíciók)
│   ├── statsController.js       látogatás-/km-rögzítés, statisztika
│   ├── leaderboardController.js ranglista (XP SQL-ben kiszámolva)
│   ├── adminController.js       moderáció (admin jogosultsággal)
│   └── versionController.js     verzióinfó endpoint
├── routes/                     a fenti controllerekhez tartozó router-ek
├── scripts/                    Python POI-importálók + romania-latest.osm.pbf
├── migration.sql               place_ratings UNIQUE constraint
└── uploads/                    feltöltött képek (statikusan kiszolgálva)
```

---

## 5. Adatmodell (PostgreSQL + PostGIS)

> **Megjegyzés a forrásokról:** a teljes séma nincs egyetlen migrációs fájlban.
> Néhány táblát az `app.js` hoz létre induláskor (`CREATE TABLE IF NOT EXISTS`),
> a `place_ratings`-t az `add_ratings.sql` és a `migration.sql`, a `places` tábla
> oszlopstruktúráját pedig a Python importerek és a lekérdezésekben hivatkozott
> oszlopok alapján lehet rekonstruálni. Az alábbi mezőtípusok egy része **a
> használatból kikövetkeztetett** — a pontos DDL-t `[ELLENŐRIZNI]`.

### 5.1 `places` — látnivalók/POI-k

| Oszlop | Típus | Megjegyzés |
|---|---|---|
| `id` | text (PK) | importnál `gen_random_uuid()::text`, vagy `node/…`/`way/…` |
| `osm_id` | text | eredeti OSM azonosító (`n123`/`w456`); részleges UNIQUE index `WHERE osm_id IS NOT NULL` |
| `name` | text | hely neve |
| `category` | text | `peak,lake,cave,ruin,spring,viewpoint` (természeti) + `hotel,restaurant,fuel,pharmacy,marketplace,cafe,bar,museum` (szolgáltatás) |
| `elevation_m` | integer | magasság m-ben, lehet NULL |
| `description` | text | leírás |
| `images` | jsonb | kép-URL tömb |
| `source` | text | `'osm'` vagy `'user'` (beküldött hely) |
| `tags` | jsonb | nyers OSM kulcs-érték párok |
| `geom` | geometry(Point, 4326) | PostGIS pont; lat/lng kinyerése `ST_Y`/`ST_X` |

`[ELLENŐRIZNI: a természeti kategóriák (peak/lake/cave/…) importja NEM szerepel a látható scriptekben — az import_pois*.py csak amenity/szolgáltatás POI-kat tölt. A természeti POI-k forrása/importja külön folyamat lehetett.]`

### 5.2 `place_ratings` — értékelések

| Oszlop | Típus | Megjegyzés |
|---|---|---|
| `id` | serial (PK) | |
| `place_id` | text (FK → places.id, ON DELETE CASCADE) | |
| `user_id` | text | Firebase UID |
| `rating` | integer | CHECK 1..5 |
| `created_at` | timestamp | |

**UNIQUE (place_id, user_id)** — egy felhasználó egy helyre egy értékelés; UPSERT-tel frissül.

### 5.3 `users`

`user_id` (PK, Firebase UID), `display_name`, `email`, `profile_image_url`,
`is_admin` (bool), `updated_at`. Minden bejelentkezéskor upsert szinkronizálja a
nevet/e-mailt (`usersController.getProfileImage`). `[ELLENŐRIZNI: pontos DDL nincs a repóban]`

### 5.4 `posts`, `post_comments`, `post_reports`

- `posts`: `id` (serial PK), `place_id`, `user_id`, `username`, `content`, `image_url`, `created_at`.
- `post_comments`: `id`, `post_id`, `user_id`, `username`, `content`, `created_at`.
- `post_reports`: `id`, `post_id`, `reporter_user_id`, `created_at`, UNIQUE(post_id, reporter_user_id).

`[ELLENŐRIZNI: e három tábla CREATE-je nincs a repóban — máshol jött létre.]`

### 5.5 `friendships`

`id`, `requester_id`, `addressee_id`, `status` (`'pending'`/`'accepted'`), `created_at`.
Kétirányú lekérdezés (CASE-szel a "másik fél" kiválasztása). `[ELLENŐRIZNI: pontos DDL]`

### 5.6 Induláskor létrehozott táblák (`app.js`)

Ezek **kódból, tényszerűen** vannak (CREATE TABLE IF NOT EXISTS):

- `place_reports` — `id, place_id (FK→places ON DELETE CASCADE), user_id, reason, created_at`, UNIQUE(place_id, user_id).
- `navigation_sessions` — `session_id (serial PK), creator_id, partner_id, status ('invited'/'active'/'ended'), destination_lat, destination_lng, destination_name, created_at`.
- `user_place_visits` — `id, user_id, place_id, place_name, category, visited_at`, UNIQUE(user_id, place_id).
- `user_stats` — `user_id (PK), total_km (double), total_navigations (int), updated_at`.
- `navigation_locations` — `user_id (PK), session_id, lat, lng, remaining_km, updated_at`.

Szintén induláskor: `CREATE INDEX IF NOT EXISTS places_geom_gist ON places USING GIST (geom)`.

### 5.7 PostGIS használat

- **Sugáron belüli helyek** (`GET /places`):
  ```sql
  WHERE ST_DWithin(p.geom::geography, ST_MakePoint($2,$1)::geography, $3)
  ORDER BY p.geom <-> ST_SetSRID(ST_MakePoint($2,$1), 4326)
  LIMIT 500
  ```
  A `::geography` cast valódi gömbi (méteres) távolságot ad; a `<->` a GiST-index
  által gyorsított **KNN (legközelebbi szomszéd) rendezés**.
- **Pontos távolság km-ben** (AI endpoint):
  ```sql
  ROUND((ST_Distance(p.geom::geography, ST_MakePoint($1,$2)::geography)/1000)::numeric, 1) AS distance_km
  ```
- **Lat/lng kinyerés:** `ST_Y(geom::geometry)` → szélesség, `ST_X(geom::geometry)` → hosszúság.
- **Pont létrehozás beszúráskor:** `ST_SetSRID(ST_MakePoint(lng, lat), 4326)`.

---

## 6. Backend API — teljes endpoint-lista

Base URL (éles): `https://pathfinderbackend-production.up.railway.app`
Auth: ahol jelölve, `Authorization: Bearer <Firebase ID token>` szükséges.

### 6.1 Health
- `GET /` → `{ message: "Pathfinder API is running" }` (publikus).

### 6.2 `/places`
| Metódus + útvonal | Auth | Bemenet | Mit csinál / visszaad |
|---|---|---|---|
| `GET /places` | nincs | query: `lat`, `lng`, `radius`(fok, def. 0.05) | `ST_DWithin` sugáron belüli helyek, KNN-rendezve, max 500. Visszaad: id, name, category, elevation_m, source, latitude, longitude |
| `GET /places/search` | nincs | query: `q` | név/kategória/leírás ILIKE keresés, átlag-rating-gel, max 50 |
| `GET /places/ratings/my` | **kell** (`requireAuth`) | — | a bejelentkezett user összes értékelése helyadatokkal |
| `POST /places/suggest` | **kell** (kézi token-ellenőrzés, multipart) | mezők: name, category, lat, lng, (description); fájl: image | új `source='user'` hely beszúrása, visszaadja az id-t |
| `POST /places/:id/report` | **kell** (`requireAuth`) | body: `{ reason? }` | hely bejelentése moderációra (UPSERT) |
| `POST /places/:id/rate` | **kell** (`requireAuth`) | body: `{ rating: 1..5 }` | értékelés UPSERT, `201` |
| `GET /places/:id` | nincs | — | egy hely átlag-rating-gel |

> **Megjegyzés a route-sorrendről:** a `/ratings/my`, `/search`, `/suggest` a `/:id`
> elé van regisztrálva, így nem nyeli el őket a paraméteres útvonal — ez tudatos és helyes.

### 6.3 `/ai`
| `POST /ai/query` | nincs | body: `{ message, lat, lng }` | természetnyelvi keresés (Gemini 2.0 Flash + regex fallback), visszaad: `{ message, filters, places[] }` |

### 6.4 `/posts`
| Metódus | Auth | Leírás |
|---|---|---|
| `GET /posts?place_id=` | nincs | hely posztjai, szerző profilképpel |
| `POST /posts` | **kell** (multipart, kézi token) | poszt létrehozás (content + opcionális kép), `201` |
| `POST /posts/:postId/report` | **kell** | poszt bejelentése (UNIQUE constraint dedup) |
| `GET /posts/:postId/comments` | nincs | komment-lista |
| `POST /posts/:postId/comments` | **kell** | komment létrehozás, `201` |

### 6.5 `/users`
| `POST /users/profile-image` | **kell** (multipart) | profilkép feltöltés + user upsert |
| `GET /users/profile-image` | **kell** | `{ profile_image_url, is_admin }`; közben upsertel név/e-mail |

### 6.6 `/friends`
| `GET /friends/search?q=` | **kell** | felhasználókeresés + kapcsolat státusz |
| `GET /friends/requests` | **kell** | bejövő (pending) kérések |
| `GET /friends` | **kell** | elfogadott barátok |
| `POST /friends/request` | **kell** | kérés küldése (`{ targetUserId }`) |
| `POST /friends/accept/:requesterId` | **kell** | kérés elfogadása |
| `DELETE /friends/:otherUserId` | **kell** | barát eltávolítása / kérés elutasítása |

### 6.7 `/navigate` (közös navigáció)
| `POST /navigate/invite` | **kell** | session létrehozás (előbb törli a régieket); `{ partnerUserId, destinationLat?, destinationLng?, destinationName? }` |
| `GET /navigate/pending` | **kell** | a usernek szóló legutóbbi `invited` meghívó |
| `POST /navigate/accept/:sessionId` | **kell** | session `active`-ra állítása |
| `POST /navigate/decline/:sessionId` | **kell** | session + pozíciók törlése |
| `PUT /navigate/location` | **kell** | saját pozíció UPSERT (`invited`/`active` alatt is); `{ sessionId, lat, lng, remainingKm? }` |
| `GET /navigate/partner-location/:sessionId` | **kell** | partner pozíció + cél; 15 perc inaktivitás után auto-`ended` |
| `DELETE /navigate/session/:sessionId` | **kell** | session lezárása |

### 6.8 `/stats`
| `POST /stats/visit` | **kell** | látogatás rögzítés (UNIQUE → `isNew` jelzés) |
| `POST /stats/km` | **kell** | megtett km + navigációszám növelése (UPSERT) |
| `GET /stats/me` | **kell** | saját statisztika (km, nav, posztok, kategória-látogatások) |
| `GET /stats/user/:userId` | **kell** | másik felhasználó publikus profilja + statisztikája |

### 6.9 `/leaderboard`
| `GET /leaderboard` | nincs | top 100 user össz-XP szerint, rangsorral (XP **SQL-ben** számolva) |

### 6.10 `/version`
| `GET /version` | nincs | `{ version, download_url, release_notes }` |

> A globális 404- és hibakezelő minden ismeretlen route-ra strukturált JSON-t ad
> (`Route <method> <path> not found`, illetve `Internal server error`).

---

## 7. Authentikáció és jogosultságkezelés

**Folyamat (kódból):**

1. **Regisztráció/bejelentkezés** kliensoldalon a `AuthService`-en keresztül
   (`FirebaseAuth.createUserWithEmailAndPassword` / `signInWithEmailAndPassword`).
   A Firebase JWT ID tokent bocsát ki.
2. **Védett híváskor** a kliens `user.getIdToken()`-nel lekéri a tokent, és
   `Authorization: Bearer <JWT>` fejlécben küldi (`PlacesApi._authHeaders`).
3. **Szerveroldali ellenőrzés** két mintával:
   - `middleware/auth.js` → `requireAuth`: kiveszi a Bearer tokent,
     `admin.auth().verifyIdToken()`, beállítja `req.user = { id: uid, email }`,
     hiba esetén `401`.
   - Több controller (posts, users, friends, navigate, stats, admin, places/suggest,
     places/report) **kézzel** ismétli ugyanezt a token-ellenőrzést egy helyi
     `verifyToken`/`verifyUser` segédfüggvénnyel. `[ELLENŐRIZNI/MEGFONTOLANDÓ: a
     duplikált auth-logika kiszervezhető lenne a meglévő requireAuth middleware-be.]`
4. **Admin jogosultság:** az `adminController.verifyAdmin` a token-ellenőrzés után
   lekéri a `users.is_admin` mezőt; ha nem admin → `403`. Az admin státusz tehát
   **adatbázis-alapú**, nem Firebase custom claim.
5. A `firebase-admin` inicializálása: `FIREBASE_SERVICE_ACCOUNT` env JSON-ból
   (`admin.credential.cert`), vagy `applicationDefault()` + `FIREBASE_PROJECT_ID`.

A `splash_screen.dart` indításkor a `FirebaseAuth.instance.currentUser` alapján dönt:
bejelentkezett → Home, különben → Login (perzisztens munkamenet).

---

## 8. AI-integráció — Gemini 2.0 Flash (2026-06-26)

A `POST /ai/query` endpoint a **Google Gemini 2.0 Flash** modelljét hívja
természetes nyelven megadott helykereső lekérdezések értelmezéséhez.

### Működési folyamat

1. A `aiController.js` a `parseWithGemini(message)` async függvényt hívja először.
2. A Gemini rendszerprompt (SYSTEM_PROMPT) utasítja a modellt, hogy a felhasználói
   szöveget **kizárólag nyers JSON**-ként adja vissza (nincs markdown blokk) a
   következő struktúrával:

   ```json
   {
     “category”: “peak” | “lake” | ... | null,
     “maxDistanceKm”: 50 | null,
     “minElevation”: 1000 | null,
     “maxElevation”: null,
     “minRating”: null,
     “sortByRating”: false,
     “name”: null,
     “message”: “Searching for peaks above 1000m within 50km!”
   }
   ```

3. A modellhívásra **8 másodperc timeout** vonatkozik (`Promise.race`).
4. Ha a kulcs (`GEMINI_API_KEY`) hiányzik, a hívás fail-safe módban **fallback
   regex-parserre** vált (`parseQuery`) — a szerver soha nem adhat 500-as hibát
   kizárólag AI-hiba miatt.
5. A kinyert szűrőkből **dinamikus, paraméterezett SQL** épül (PostGIS `ST_DWithin`,
   kategória/magasság WHERE, `HAVING AVG(rating) >=`, rendezés rating/távolság szerint,
   `LIMIT 5/10`). Válasz: `{ message, filters, places[] }`.

### Modell és konfiguráció

| | |
|---|---|
| Modell | `gemini-2.0-flash` (ingyenes tier) |
| API csomag | `@google/generative-ai` ^0.24.1 |
| Env változó | `GEMINI_API_KEY` (Railway + `.env`) |
| Timeout | 8 s (utána keyword-fallback) |
| Rendszer-prompt | System instruction — kategória-lista, output-szabályok, RO/HU támogatás |

### Fallback keyword parser

A régi regex-alapú parser (`parseQuery` + `buildMessage`) **megmarad tartalékként**.
Aktiválódik, ha: (a) nincs `GEMINI_API_KEY`, (b) a Gemini API hibát dob vagy timeout-ol,
(c) a modell érvénytelen JSON-t ad vissza.

A frontend oldalon az `ai_chat_sheet.dart` jeleníti meg a beszélgetést és a
találati kártyákat; a `PlacesApi.queryAI()` küldi a kérést 45 s timeouttal.

---

## 9. Útvonaltervezés (OSRM)

A `routing_service.dart` a **publikus OSRM** gyalogos profilját használja:

```
GET https://router.project-osrm.org/route/v1/foot/{lng1},{lat1};{lng2},{lat2}
    ?geometries=geojson&overview=full
```

- A válaszból a `routes[0].geometry.coordinates` GeoJSON pontsorból `List<LatLng>`
  polyline készül (a GeoJSON `[lng,lat]` sorrendet a kód `LatLng(lat,lng)`-re fordítja),
  és a `routes[0].distance` (méter) is kinyerésre kerül.
- Helyi geometriai segédfüggvények (statikus, `latlong2` `Distance`-szel):
  - `calculateDistance` — két pont közti táv (m).
  - `calculatePolylineDistance` — polyline teljes hossza.
  - `distanceAlongPolyline` — adott célponthoz legközelebbi polyline-pontig mért táv (waypoint-pozícióhoz a haladásjelzőn).
  - `findClosestPointAndRemovePath` — a felhasználóhoz legközelebbi polyline-pont
    megkeresése és a már megtett szakasz levágása (élő navigációhoz).
- A `home_screen` navigáció közben 1 mp-enként frissülő GPS-stream-re iratkozik
  (`AndroidSettings`, `bestForNavigation`), és minden fix-nél újraszámolja a
  hátralévő utat, frissíti a polyline-t és a haladásjelzőt.

---

## 10. Kulcsfontosságú algoritmusok és megoldások

### 10.1 Viewport-alapú, gyorsítótárazott betöltés (`places_layer.dart`)
- A markerek **csak zoom ≥ 9** esetén töltődnek (egyébként túl sok adat lenne).
- A térkép-események (`MapEventMoveEnd`, `RotateEnd`, `FlingAnimationEnd`,
  `DoubleTapZoomEnd`) **300 ms debounce**-szal váltanak ki egy `_loadNow()`-t.
- **Cache-fedés:** ha az aktuális látható terület egy korábbi (paddinggel bővített)
  lekérés `_coveredBounds`-ján belül van és még friss (`_refetchTtl`), a hálózati
  kérés **kimarad**.
- **Negyedelt párhuzamos betöltés:** zoom < 11 esetén a viewport 4 kvadránsra oszlik,
  amelyeket `Future.wait` párhuzamosan tölt (id szerint deduplikál) — így a képernyő
  széle is lefedett. Zoom ≥ 11-nél egyetlen, 25%-kal bővített lekérés elég.
- **Cache-méret korlát:** `_maxCacheSize` felett a legrégebbi bejegyzések törlődnek.

### 10.2 GPS-zaj szűrése (`home_screen._isPlausibleFix`)
A GPS időnként durva (cella-torony) fixet vagy "teleportot" ad. A szűrő:
- Első fix: `accuracy ≤ 150 m`.
- Későbbiek: `accuracy ≤ 100 m`, és ha két fix között a sebesség **> 55 m/s
  (~200 km/h)** és > 100 m a táv, akkor GPS-glitchnek minősül és eldobja.
- **Beragadás-védelem:** 5 egymást követő elutasítás után a következő fixet
  elfogadja, hogy a marker sose ragadjon be.
- `_getAccuratePosition`: ha az első fix rossz (>50 m), rövid ideig a stream-ből
  mintáz a legpontosabbért (≤25 m vagy 6 minta/6 s).

### 10.3 XP/szint/badge rendszer — kétszer is implementálva
- **Kliensoldal** (`level_service.dart`): `computeXp(stats)` = látogatás×10 +
  km×2 + poszt×25 + jelvény-bónuszok (tier-enként kumulatív: bronz 50, ezüst +150,
  arany +300, platina +600). Szintküszöb: `xpForLevel(L)=200(L-1)+25(L-1)(L-2)`,
  azaz szintenként `200+50(L-1)` XP. 19 elnevezett szint + "Grand Pathfinder" 20-tól.
  Badge-tierek: helykategóriánként `[5,15,25,40]`, posztok `[5,15,25,50]`, explorer
  (különböző természeti kategóriák) `[2,4,5,6]`, navigáció `[5,15,30,60]`, km
  `[10,50,150,500]`.
- **Szerveroldal** (`leaderboardController.js`): **ugyanaz a képlet SQL-ben**
  (CTE-kkel: visit-XP, place-badge-XP, poszt/km/explorer/navigátor badge-XP), hogy a
  ranglista a teljes felhasználói körre egyetlen lekérdezésből számolható legyen.
  `[ELLENŐRIZNI/KOCKÁZAT: a két XP-képletet (Dart és SQL) kézzel kell szinkronban
  tartani — eltérés esetén a profil és a ranglista más XP-t mutathat.]`

### 10.4 Közös navigáció ("Navigate Together") állapotgép
- `navigation_sessions.status`: `invited → active → ended`.
- A `home_screen` **8 mp-enként** kérdez rá a függő meghívóra
  (`_invitePollTimer`), és aktív session esetén **3 mp-enként** (`_navPollTimer`)
  küldi a saját pozícióját és kéri le a partnerét.
- **Stale-védelem:** a `getPartnerLocation` 15 perc inaktivitás után `ended`-re állít;
  frissen elfogadott (még pozíció nélküli) sessionnél a `created_at`-re esik vissza,
  hogy ne járjon le idő előtt (lásd a kódbeli kommenteket — több hibajavítás nyoma).
- **Race-védelem:** a poll a `sessionId`-t lokálisan "snapshotolja"; ha közben a
  session megváltozik/lezárul, a régi válasz nem írhatja felül a tiszta állapotot.

### 10.5 Jutalmazási logika a navigáció végén (`_updateNavigationPolyline`)
- Cél elérése `< 15 m`-nél. XP/km csak akkor jár, ha a teljes útvonal `≥ 0.3 km`.
- **Ismételt látogatás nem ér XP-t:** a `recordVisit` az `isNew` jelzéssel tér
  vissza (UNIQUE constraint a `user_place_visits`-en), és csak új helyért (vagy
  közös `nav_*` session esetén) ír km-t.
- Megszakított navigációnál is rögzíti a már megtett km-t (`_clearActiveNavigation`).

### 10.6 Beépített frissítés-ellenőrzés
A `PlacesApi.fetchVersionInfo()` a **GitHub Releases** API-ból olvassa a legújabb
tag-et és a `.apk` asset URL-jét; a `/version` backend-endpoint egy statikus
fallback verziót ad. `warmUp()` indításkor "felébreszti" az esetleg alvó Railway-t.

### 10.7 Robusztus hálózati hibakezelés (frontend)
Minden `PlacesApi` hívás `TimeoutException`/`SocketException` ágat kezel, beszédes
üzenetekkel; a közös navigáció poll átmeneti `error` státuszt különböztet meg a
végleges `ended`-től, hogy egy hálózati zökkenő ne zárja le a sessiont.

---

## 11. Állapotkezelés és adatfolyam a frontenden

- **Nincs külső state-management** (sem Provider, sem Bloc, sem Riverpod). Minden
  képernyő `StatefulWidget` + `setState()` mintát használ. A `_HomeScreenState`
  tartja a fő állapotot: `_currentLatLng`, `_selectedCategories`, `_minElevation`/
  `_maxElevation`, `_maxDistanceKm`, `_showAllLocations`, navigációs mezők
  (`_isNavigating`, `_routePolyline`, `_navigationDestination`, …), közös-navigációs
  mezők (`_navSessionId`, `_partnerLocation`, …), cache-elt statisztika.
- **Téma** globálisan az `app.dart` `_PathfinderAppState`-jében, `SharedPreferences`
  (`isDarkMode`) perzisztálva; a `PathfinderApp.of(context).toggleTheme()` váltja.
- **Perzisztencia:** `SharedPreferences` a témához, szűrőkhöz és a profilkép-cache-hez
  (`profile_service.dart`); a Firebase Auth munkamenet maga is perzisztens.
- **Backend-kommunikáció:** kizárólag a `PlacesApi` (és néhol `ProfileService`)
  osztályon át, `http` csomaggal; a base URL **hardcode-olt** három helyen
  (`home_screen.dart` ×2, `profile_service.dart`).
  `[ELLENŐRIZNI/MEGFONTOLANDÓ: a base URL kiszervezhető lenne egyetlen konstansba
  vagy `--dart-define` build-konfigba.]`
- **Navigáció (route- olás):** named route-ok (`routes.dart`), `Navigator.push…`.
  A részfunkciók többsége `showModalBottomSheet` lapokon jelenik meg.

---

## 12. Deployment és infrastruktúra

- **Backend:** Railway-en fut (`pathfinderbackend-production.up.railway.app`), a
  `server.js` a `process.env.PORT`-ra (vagy 3000-re) figyel. Az adatbázis-kapcsolat
  `DATABASE_URL`-lel, SSL-lel (`rejectUnauthorized: false`).
- **Adatbázis:** managed PostgreSQL + PostGIS. `[ELLENŐRIZNI: Railway Postgres vagy
  Supabase — a kód kommentje Railway-t mond, az import-scriptek Supabase-t.]`
- **Statikus fájlok:** a feltöltött képek a backend `uploads/` mappájából, az
  `/uploads` útvonalon (`express.static`). `[ELLENŐRIZNI/KOCKÁZAT: Railway-n a
  fájlrendszer jellemzően nem perzisztens újradeploykor — érdemes felhőtárat
  (pl. a már függőségként meglévő Firebase Storage) használni a feltöltött képekhez.]`
- **Környezeti változók (`.env`, értékek nélkül):** `PORT`, `DB_USER`, `DB_HOST`,
  `DB_NAME`, `DB_PASSWORD`, `DB_PORT`, `FIREBASE_PROJECT_ID`,
  `GOOGLE_APPLICATION_CREDENTIALS`, `OPENROUTER_API_KEY`. Az éles kapcsolathoz a
  `db/index.js` a `DATABASE_URL`-t részesíti előnyben; a `firebase-admin` a
  `FIREBASE_SERVICE_ACCOUNT` JSON-t is el tudja fogadni env-ből.
- **Titkok kizárása gitből** (`.gitignore`): `node_modules/`, `.env`,
  `firebase-service-account.json`, `uploads/*` (kivéve `.gitkeep`).
  `[ELLENŐRIZNI: a `firebase-service-account.json` jelen van a backend munkapéldányban;
  a git-history `6afbb7e "Remove secrets from git tracking"` commitja jelzi, hogy
  korábban követve volt — ellenőrizni kell, hogy a kulcs nem szivárgott-e ki a
  history-ban, és szükség esetén rotálni.]`
- **CI/CD:** a **frontend** repóban `.github/workflows/release.yml` — `v*.*.*` tag
  push-ra Ubuntu runneren `flutter build apk --release`, átnevezés `pathfinder.apk`-ra,
  majd GitHub Release publikálás (auto release-notes). A **backendhez** nincs
  GitHub Actions workflow (Railway jellemzően push-ra auto-deployol). `[ELLENŐRIZNI:
  Railway deploy-trigger pontos módja.]`

---

## 13. Nevezetes tervezési döntések

- **Kétrétegű architektúra, titkok a szerveren:** a kliens soha nem éri el közvetlenül
  az adatbázist; a Firebase admin kulcs és bármilyen API-kulcs a backenden marad.
- **PostGIS a térbeli logikára:** gömbi távolság (`::geography`), GiST-index és KNN
  (`<->`) rendezés — pontos és gyors "X km-en belüli helyek" lekérdezés.
- **Hibrid szűrés:** a backend a viewporton belüli helyeket adja vissza (egyszerű,
  azonnali kliensoldali szűrés kategóriára/magasságra/távolságra), míg az "AI"
  endpoint szerveroldalon, a teljes adatbázison szűr (mert nem viewport-függő).
- **LLM-alapú NLP (Gemini 2.0 Flash):** a természetnyelvi kereső Gemini 2.0 Flash
  modellt használ szűrőkivonáshoz, regex-fallbackkel a megbízhatóságért (lásd 8. fejezet).
- **Egyszerű állapotkezelés:** `setState` minden, külső lib nélkül — kis csapatnak/
  egyéni projektnek kevesebb boilerplate.
- **Gamifikáció:** XP, szintek és négyfokú (bronz/ezüst/arany/platina) badge-rendszer
  a megtartásért; a ranglista XP-jét a szerver számolja, hogy konzisztens és
  skálázható legyen.
- **Robusztusság a valós terepen:** GPS-zajszűrés, debounce-olt és cache-elt
  marker-betöltés, stale-/race-védett közös navigáció, beszédes hálózati hibakezelés.
- **Automatizált kiadás:** tag-vezérelt GitHub Actions APK-build + in-app
  verzióellenőrzés a GitHub Releases-ből.

---

## (a) Mit érdemes a dolgozatban kiemelni (erősségek/érdekességek)

1. **PostGIS térbeli lekérdezések** — `ST_DWithin` geography-casttal, GiST-index és
   `<->` KNN-rendezés; pontos km-távolság `ST_Distance`-szel. Akadémiailag jól védhető.
2. **Viewport-alapú, debounce-olt, negyedelt párhuzamos és cache-fedéses
   marker-betöltés** — konkrét teljesítmény-optimalizálás valós kompromisszumokkal.
3. **GPS-zaj és „teleport” szűrés** sebesség-küszöbbel és beragadás-védelemmel — valós
   mobilfejlesztési probléma elegáns kezelése.
4. **Közös navigáció elosztott állapotgépe** (`invited/active/ended`) stale- és
   race-condition védelemmel, polling-alapú szinkronizálással.
5. **Gamifikáció kétrétegű XP-modellje** — ugyanaz a képlet kliensen (Dart) és
   szerveren (egyetlen összetett SQL CTE-lánc a ranglistához).
6. **Biztonsági modell** — Firebase JWT mindkét rétegben, adatbázis-alapú admin
   jogosultság, kulcsok kizárólag szerveroldalon.
7. **CI/CD és in-app frissítés** — tag-triggerelt automatikus APK-kiadás és
   GitHub Releases-alapú verzióellenőrzés.
8. **LLM-alapú természetnyelvi szűrőkivonás** — Gemini 2.0 Flash (ingyenes tier),
   regex-fallbackkel a megbízhatóságért, paraméterezett dinamikus SQL-lel (SQL-injection
   ellen védett).

## (b) Mit kell még pontosítani vagy ellenőrizni (`[ELLENŐRIZNI]` összegyűjtve)

1. **Adatbázis host:** Railway-managed Postgres **vagy** Supabase? (db/index.js
   kommentje vs. import-scriptek connection stringje ellentmond.)
2. **AI-integráció:** Gemini 2.0 Flash (ingyenes) beépítve (2026-06-26). A `GEMINI_API_KEY`
   env-változót Railway-en is be kell állítani. Az `openai` és `@google/genai` csomagok
   és az `OPENROUTER_API_KEY` eltávolíthatók (nem használtak).
3. **Teljes adatbázis-séma:** a `users`, `posts`, `post_comments`, `post_reports`,
   `friendships` táblák pontos DDL-je nincs a repóban — dokumentálni kell.
4. **Természeti POI-k importja:** a `peak/lake/cave/ruin/spring/viewpoint` kategóriák
   importja nem szerepel a látható scriptekben (azok csak szolgáltatás-POI-kat töltenek).
   Honnan/hogyan kerültek be?
5. **Feltöltött képek perzisztenciája:** Railway efemer fájlrendszerén az `uploads/`
   túléli-e az újradeployt? Felhőtárra (pl. Firebase Storage) érdemes-e váltani?
6. **Titokszivárgás:** a `firebase-service-account.json` korábban git-tracked volt
   (`6afbb7e` commit) — ellenőrizni a history-t, szükség esetén kulcsrotáció.
7. **`firebase_storage` használata:** a függőség benne van a `pubspec.yaml`-ban, de
   nem találtam aktív hívást — valóban használatban van?
8. **XP-képlet szinkron:** a Dart (`level_service.dart`) és az SQL
   (`leaderboardController.js`) képletének kézi egyezősége — egyetlen forrásból
   származtatás megfontolandó.
9. **Duplikált auth-logika:** több controller kézzel ismétli a token-ellenőrzést a
   meglévő `requireAuth` middleware helyett — egységesíthető.
10. **Base URL hardcode:** három helyen szerepel a Railway-URL — konstansba/
    `--dart-define`-ba kiszervezhető.
11. **Backend deploy/CI:** a Railway deploy pontos triggere (auto a `main`-re?) nincs
    a repóban dokumentálva.

---

*Ez a dokumentum a forráskód aktuális állapotából készült. A `[ELLENŐRIZNI]` pontok
azokat a részeket jelölik, ahol a kód önmagában nem adott egyértelmű választ.*
