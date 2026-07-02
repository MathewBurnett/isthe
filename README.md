# Is the …

A tiny status board. The landing page asks **“Is the …”**; each item is a yes/no
thing (e.g. the fridge) that an admin toggles between two states, each with its
own word and background colour. Visiting `/<slug>` (e.g. `/fridgeclosed`) shows
that word full-screen on the chosen colour.

- **Zero dependencies** — pure Node.js (built-in `http`), no `npm install`, no build step.
- **Shared state** — everyone sees the same status; persisted to one JSON file.
- **Designed to sit behind nginx** on a private network.

## Layout

```
server.js                     the whole backend (~250 lines, no deps)
data/items.json               persisted state (created/updated at runtime)
public/
  index.html                  landing page ("Is the …") + item grid
  admin.html                  password-gated management UI
  style.css                   shared styles
deploy/
  isthe.nginx.conf nginx site config
  isthe.service               systemd unit
```

## Run locally

```bash
ADMIN_PASSWORD=secret node server.js
# -> http://127.0.0.1:8080   (admin at /admin)
```

### Environment variables

| Var              | Default             | Meaning                          |
| ---------------- | ------------------- | -------------------------------- |
| `PORT`           | `8080`              | Port to listen on                |
| `HOST`           | `127.0.0.1`         | Bind address                     |
| `ADMIN_PASSWORD` | `changeme`          | Password for `/admin` and writes |
| `DATA_FILE`      | `./data/items.json` | Where state is stored            |

## Deploy on your server (nginx + systemd)

1. Copy the app to the server:
   ```bash
   sudo mkdir -p /opt/isthe
   sudo cp -r server.js public data /opt/isthe/
   sudo useradd --system --home /opt/isthe isthe || true
   sudo chown -R isthe:isthe /opt/isthe
   ```
2. Install the service (edit `ADMIN_PASSWORD` in the file first!):
   ```bash
   sudo cp deploy/isthe.service /etc/systemd/system/isthe.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now isthe
   journalctl -u isthe -f     # check it started
   ```
3. Install the nginx site for **isthe.domain**:
   ```bash
   sudo cp deploy/isthe.nginx.conf /etc/nginx/sites-available/isthe
   sudo ln -s /etc/nginx/sites-available/isthe /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```
4. Make sure `isthe.domain` resolves to the server (DNS or `/etc/hosts`), then
   visit `http://isthe.domain/` and manage items at `http://isthe.domain/admin`.

## How it works

- **Landing** (`/`) fetches `/api/items` and renders a card per item, coloured by
  its current state.
- **Item page** (`/<slug>`) is server-rendered so the colour fills the screen with
  no white flash. Slugs are `[a-z0-9]` only, derived from the label unless overridden.
- **Admin** (`/admin`) is a static page gated by the admin password. The password
  is sent as an `x-admin-token` header and held in `sessionStorage` for the tab.
  All write endpoints (`POST`/`PUT`/`DELETE`/toggle) require it; reads are public.

### Data model

```json
[
  {
    "slug": "fridgeclosed",
    "label": "fridge",
    "active": 1,
    "options": [
      { "word": "Open", "bg": "#16a34a" },
      { "word": "Closed", "bg": "#dc2626" }
    ]
  }
]
```

`active` is the index (0 or 1) of the currently shown option; toggling flips it.
Text colour (black/white) is chosen automatically for contrast against `bg`.

### API

| Method + path                  | Auth | Purpose                   |
| ------------------------------ | ---- | ------------------------- |
| `GET /api/items`               | no   | List all items            |
| `GET /api/items/:slug`         | no   | One item                  |
| `POST /api/auth`               | yes  | Verify the admin password |
| `POST /api/items`              | yes  | Create an item            |
| `PUT /api/items/:slug`         | yes  | Update an item            |
| `POST /api/items/:slug/toggle` | yes  | Flip its state            |
| `DELETE /api/items/:slug`      | yes  | Delete an item            |

## Notes / security

- The admin password is a shared secret sent over the connection — fine on a
  trusted LAN. If you expose this beyond your network, terminate **TLS** in nginx
  (a commented HTTPS block is in the site config) and/or restrict `/admin` by IP
  (also commented in the config).
- State is a single JSON file written atomically (temp file + rename), so a crash
  mid-write won't corrupt it. Back it up by copying `data/items.json`.
