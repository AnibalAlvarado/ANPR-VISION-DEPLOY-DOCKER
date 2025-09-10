# ANPR-VISION — Despliegue **TWO ENGINES** (Proxy + Front) con SSL y 3 DBs

Este paquete levanta todo con **un solo** comando y conserva **`/api`** en el reverse proxy:
- **nginx-proxy** (Ubuntu + Nginx): **puerta 80/443**, SSL y proxy `/api` → backend.
- **frontend** (Nginx propio): sirve Angular con fallback SPA.
- **backend** (.NET 9 Web API): escucha en `8080` interno.
- **DBs**: PostgreSQL, SQL Server y MySQL simultáneamente.
- **Dominio**: ejemplo listo para **anprvision.duckdns.org** (DuckDNS).

---

## 1) Requisitos previos mínimos
- Docker & Docker Compose instalados.
- Puertos **80** y **443** abiertos en el host/Router/Firewall si usarás **Let’s Encrypt (HTTP-01)**.
- Subdominio resolviendo a tu IP pública (ya tienes `anprvision.duckdns.org`).

> Para **desarrollo local** sin exponer a internet, puedes usar **certificado self‑signed** (ver §4).

---

## 2) Estructura
```
anpr-two-engines-final/
├─ docker-compose.yml
├─ backend/
│  └─ Web/Dockerfile
├─ frontend/
│  ├─ Dockerfile.two
│  └─ nginx.conf
├─ nginx/
│  └─ proxy/
│     ├─ Dockerfile
│     ├─ conf.d/
│     │  ├─ default.conf        # Self-signed (DEV)
│     │  └─ default-le.conf     # Let's Encrypt (PROD) ya con anprvision.duckdns.org
│     ├─ certs/                 # self-signed (DEV)
│     └─ ../html/               # webroot ACME (HTTP-01)
└─ scripts/
   └─ generate-dev-certs.sh
```

---

## 3) Levantar TODO (self-signed por defecto)
```bash
# (Opcional DEV) Genera self-signed para https local (si no usas LE todavía):
./scripts/generate-dev-certs.sh

# Levanta todo
docker compose up -d --build

# URLs:
# Frontend: https://localhost/         (self-signed: acepta advertencia del navegador)
# API:      https://localhost/api/health
```
> Verifica que `/api` **no** se pierda: la regla es `proxy_pass http://backend:8080;` **sin** `/` final.

---

## 4) Cambiar a **Let's Encrypt** (HTTPS real en anprvision.duckdns.org)

### 4.1. Ajustes rápidos
- Asegúrate de que **anprvision.duckdns.org** apunta a tu IP pública actual.
- Asegúrate de que puertos **80** y **443** llegan a tu host.
- El `docker-compose.yml` ya monta:
  - `./letsencrypt:/etc/letsencrypt`
  - `./nginx/html:/var/www/certbot`

### 4.2. Activar la config de LE en Nginx
```bash
# Sustituye conf DEV por la de Let's Encrypt
mv nginx/proxy/conf.d/default.conf nginx/proxy/conf.d/default.dev.backup
# default-le.conf ya viene con anprvision.duckdns.org
docker compose up -d --build nginx-proxy
```

### 4.3. Emitir el certificado (dos opciones)

**A) Webroot (recomendado, sin downtime):**
```bash
mkdir -p letsencrypt nginx/html
docker run --rm   -v $(pwd)/letsencrypt:/etc/letsencrypt   -v $(pwd)/nginx/html:/var/www/certbot   certbot/certbot certonly --webroot     -w /var/www/certbot     -d anprvision.duckdns.org     --agree-tos -m tu-email@dominio.com --non-interactive
```

**B) Standalone (downtime corto):**
```bash
docker compose stop nginx-proxy
docker run --rm -p 80:80   -v $(pwd)/letsencrypt:/etc/letsencrypt   certbot/certbot certonly --standalone     -d anprvision.duckdns.org     --agree-tos -m tu-email@dominio.com --non-interactive
docker compose up -d --build nginx-proxy
```

### 4.4. Comprobación del certificado
- Navega: `https://anprvision.duckdns.org/` y `https://anprvision.duckdns.org/api/health`
- Línea de comando:
  ```bash
  openssl s_client -connect anprvision.duckdns.org:443 -servername anprvision.duckdns.org -showcerts </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates
  curl -I https://anprvision.duckdns.org/
  ```
  Debe mostrar un cert de **Let's Encrypt** (issuer “R3”/“ISRG Root X1” según cadena).

### 4.5. Renovación automática (cron)
Programa cada día (ej. 3:12am) una renovación silenciosa:
```bash
0 12 3 * * * docker run --rm   -v $(pwd)/letsencrypt:/etc/letsencrypt   -v $(pwd)/nginx/html:/var/www/certbot   certbot/certbot renew --webroot -w /var/www/certbot > /tmp/certbot-renew.log 2>&1
```
Prueba en seco:
```bash
docker run --rm   -v $(pwd)/letsencrypt:/etc/letsencrypt   -v $(pwd)/nginx/html:/var/www/certbot   certbot/certbot renew --dry-run --webroot -w /var/www/certbot
```

---

## 5) Tips y problemas comunes
- **Se “pierde” `/api`**: revisa que en `default*.conf` sea `proxy_pass http://backend:8080;` (sin `/` final).
- **404 en rutas de Angular**: el `frontend/nginx.conf` ya incluye `try_files $uri $uri/ /index.html;`.
- **Fallo en LE con IPv6**: si publicaste AAAA pero tu host no recibe IPv6 en 80/443, elimina el AAAA o habilita IPv6.
- **RAM justa**: en máquinas pequeñas, considera dejar **solo PostgreSQL** activo para la demo pública.

---

## 6) Por qué “two engines” aquí
- **Separación de responsabilidades**: actualizas front sin tocar el proxy y viceversa.
- **Flexibilidad** para depurar cachés/headers y tiempos de build. 
- El coste de memoria de 2 Nginx suele ser **bajo**; el peso real están en DBs y el backend.

---
demo con SSL real en `anprvision.duckdns.org`.
