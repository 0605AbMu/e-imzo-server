# E-IMZO Server — Docker & Production Deployment

[![Publish Docker Image](https://github.com/0605AbMu/e-imzo-server/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/0605AbMu/e-imzo-server/actions/workflows/docker-publish.yml)
[![Docker Image](https://img.shields.io/badge/GHCR-e--imzo--server-blue?logo=docker)](https://github.com/0605AbMu/e-imzo-server/pkgs/container/e-imzo-server)
[![Java Version](https://img.shields.io/badge/Java-8%20(Amazon%20Corretto)-orange?logo=openjdk)](https://aws.amazon.com/corretto/)
[![Alpine Version](https://img.shields.io/badge/Alpine-3.22-green?logo=alpinelinux)](https://alpinelinux.org/)

Ushbu repozitoriy **E-IMZO Server** (Yangi Texnologiyalar Ilmiy-Axborot Markazi / NIC) dasturini zamonaviy konteynerlashtirish, eng kichik hajmdagi xavfsiz Docker obrazini yaratish va **GitHub Container Registry (GHCR)** orqali avtomatlashtirilgan CI/CD (Semantic Versioning & Cache) bilan yetkazib berish uchun mo'ljallangan.

---

## 📑 Mundarija
- [Imkoniyatlar va Optimallashuv](#-imkoniyatlar-va-optimallashuv)
- [Talablar](#-talablar)
- [Fayllar tuzilishi](#-fayllar-tuzilishi)
- [Tezkor ishga tushirish (Quick Start)](#-tezkor-ishga-tushirish-quick-start)
  - [1. Docker Compose orqali (Tavsiya etiladi)](#1-docker-compose-orqali-tavsiya-etiladi)
  - [2. Docker CLI orqali](#2-docker-cli-orqali)
- [Konfiguratsiyani sozlashning oson usullari](#-konfiguratsiyani-sozlashning-oson-usullari)
  - [A. Muhit o'zgaruvchilari (Environment Variables)](#a-muhit-ozgaruvchilari-environment-variables)
  - [B. Kalitlarni avtomatik aniqlash (Auto-Discovery)](#b-kalitlarni-avtomatik-aniqlash-auto-discovery)
  - [C. Tayyor config.properties faylini ulash](#c-tayyor-configproperties-faylini-ulash)
  - [D. Dinamik EIMZO_CFG_* o'zgaruvchilari](#d-dinamik-eimzo_cfg_-ozgaruvchilari)
- [Barcha sozlamalar jadvali (Reference)](#-barcha-sozlamalar-jadvali-reference)
- [Ulanishni tekshirish va Salomatlik (Healthcheck)](#-ulanishni-tekshirish-va-salomatlik-healthcheck)
- [CI/CD va Semantic Versioning (GHCR)](#-cicd-va-semantic-versioning-ghcr)
- [Xavfsizlik (Security Hardening)](#-xavfsizlik-security-hardening)

---

## 🚀 Imkoniyatlar va Optimallashuv

1. **Multi-Stage Docker Build**:
   - 1-bosqich (`builder`): ZIP arxivini ochish, kerakli resurslarni ajratish va ortiqcha kutubxonalarni tozalash.
   - 2-bosqich (`runtime`): Ishga tushirish uchun faqat sof JRE muhiti va tayyor fayllarni ko'chirish.
2. **Kichik hajm va Xavfsizlik**:
   - Baza sifatida eng yangi va xavfsiz **`amazoncorretto:8-alpine3.22-jre`** ishlatilgan.
   - Ishlab chiquvchi test/build qoldiqlari (`testcontainers` ~11.8MB, `byte-buddy` ~4MB, `docker-java` ~2.5MB, `junit`, `mockito`, `lombok` va h.k.) chiqarib tashlandi — natijada konteyner hajmi **120 MB** gacha qisqartirildi.
3. **Xavfsiz Non-Root foydalanuvchi**:
   - Konteyner `root` emas, balki maxsus cheklangan `eimzo` (`uid=10001, gid=10001`) foydalanuvchisi ostida ishlaydi.
4. **To'g'ri Signal Boshqaruvi va Vaqt mintaqasi**:
   - `dumb-init` orqali PID 1 signal boshqaruvi (graceful shutdown).
   - O'zbekiston vaqt mintaqasi (`TZ=Asia/Tashkent`) o'rnatilgan.
5. **Aqlli Entrypoint (`docker-entrypoint.sh`)**:
   - Hech qanday murakkab konfiguratsiya faylini qo'lda tahrirlash shart emas; barcha sozlamalarni oddiy `.env` orqali berish mumkin.
   - Agar `keys/` jildida bitta `.key` fayl bo'lsa, u avtomatik tarzda aniqlanadi.
   - Kalit biriktirilmagan holatda konteyner qulab tushmaydi, balki lokal tekshiruvlar uchun xavfsiz fallback holatida ishga tushadi.
6. **Maksimal Keshli GitHub Actions & SemVer**:
   - `cache-from: type=gha` va `cache-to: type=gha,mode=max` yordamida qatlamlar keshlanadi.
   - Git teglar (`v2.2.1`) orqali `2.2.1`, `2.2`, `2` va `latest` teglari avtomatlashtirilgan.

---

## 📋 Talablar

- **Docker Engine** (v20.10+) yoki **Docker Desktop**
- **Docker Compose** (v2+)
- **E-IMZO VPN Kalitlari**:
  - `*.key` — Tashkilotingiz uchun berilgan kalit fayl
  - `vpn.jks` — VPN sertifikatlar ombori
  - `truststore.jks` — Ishonchli sertifikatlar (TSP) ombori
- **Internet aloqasi**: Server faqat O'zbekiston hududidagi IP manzillardan `vpn.e-imzo.uz:3443` (yoki test uchun `testvpn.e-imzo.uz:2443`) serveriga ulanishi mumkin.

---

## 📂 Fayllar tuzilishi

```
e-imzo-server/
├── .github/
│   └── workflows/
│       └── docker-publish.yml     # GHCR ga avtomat nashr qilish va SemVer CI/CD
├── assets/
│   └── e-imzo-server-v2.2.1.zip   # Asl e-imzo server distributivi
├── config/
│   └── config.properties.example  # To'liq izohlangan namuna sozlamalar fayli
├── keys/
│   ├── README.md                  # Kalitlarni joylashtirish bo'yicha qo'llanma
│   ├── example.uz.key             # (Sizning VPN kalitingiz)
│   ├── vpn.jks                    # (VPN sertifikati)
│   └── truststore.jks             # (Ishonchli sertifikatlar)
├── docker-compose.yml             # Tayyor Compose konfiguratsiyasi
├── docker-entrypoint.sh           # Konfiguratsiya boshqaruvchisi va ishga tushirish skripti
├── Dockerfile                     # Multi-stage ixcham va xavfsiz Dockerfile
├── .dockerignore                  # Docker build context optimallashuvi
├── .gitignore                     # Maxfiy kalitlarni himoyalash
└── README.md                      # Qo'llanma
```

---

## ⚡ Tezkor ishga tushirish (Quick Start)

### 1. Docker Compose orqali (Tavsiya etiladi)

1. VPN kalitlaringizni `keys/` papkasiga joylashtiring:
   ```bash
   cp /path/to/your-company.key keys/
   cp /path/to/vpn.jks keys/
   cp /path/to/truststore.jks keys/
   ```

2. `docker-compose.yml` faylidagi parolni belgilang:
   ```yaml
   environment:
     - EIMZO_ENV=test # Agar test rejimi bo'lsa, 'test'; prod uchun 'prod'
     - VPN_KEY_PASSWORD=sizning_kalit_parolingiz
   ```

3. Konteynerni ishga tushiring:
   ```bash
   docker compose up -d
   ```

4. Loglarni kuzatish:
   ```bash
   docker compose logs -f
   ```

---

### 2. Docker CLI orqali

#### A) GHCR dan tayyor tasvirni yuklab olib ishga tushirish:
```bash
docker run -d \
  --name e-imzo-server \
  --restart unless-stopped \
  -p 8080:8080 \
  -e EIMZO_ENV=prod \
  -e VPN_KEY_PASSWORD="sizning_kalit_parolingiz" \
  -v $(pwd)/keys:/opt/e-imzo-server/keys:ro \
  ghcr.io/0605abmu/e-imzo-server:latest
```

#### B) Mahalliy koddan o'zingiz yig'ish (build):
```bash
# Obrazni yig'ish
docker build -t e-imzo-server:latest .

# Ishga tushirish
docker run -d \
  --name e-imzo-server \
  -p 8080:8080 \
  -e EIMZO_ENV=test \
  -e VPN_KEY_PASSWORD="sizning_kalit_parolingiz" \
  -v $(pwd)/keys:/opt/e-imzo-server/keys:ro \
  e-imzo-server:latest
```

---

## 🛠 Konfiguratsiyani sozlashning oson usullari

`docker-entrypoint.sh` tizimi konfiguratsiyani 4 xil usulda qabul qila oladi:

### A. Muhit o'zgaruvchilari (Environment Variables)
Eng qulay va tavsiya etiladigan usul. Sizga hech qanday fayl yaratish shart emas:
```bash
-e EIMZO_ENV=prod \
-e VPN_KEY_PASSWORD=parol123
```
- `EIMZO_ENV=prod` bo'lsa — avtomatik tarzda `vpn.e-imzo.uz:3443` ga ulanadi.
- `EIMZO_ENV=test` bo'lsa — avtomatik tarzda `testvpn.e-imzo.uz:2443` ga ulanadi.

### B. Kalitlarni avtomatik aniqlash (Auto-Discovery)
Agar siz `keys/` papkasiga o'z kalitingizni (masalan `mycompany-2026.key`) tashlasangiz va `VPN_KEY_FILE_PATH` ni ko'rsatmasangiz, entrypoint ushbu faylni **avtomatik aniqlaydi** va unga ulanadi. Shuningdek, `vpn.jks` va `truststore.jks` ham papkada bo'lsa, avtomatik ulanadi.

### C. Tayyor `config.properties` faylini ulash
Agar siz o'zingizning to'liq `config.properties` faylingizdan foydalanmoqchi bo'lsangiz:
```yaml
volumes:
  - ./config/my-config.properties:/opt/e-imzo-server/config/config.properties:ro
  - ./keys:/opt/e-imzo-server/keys:ro
```

### D. Dinamik `EIMZO_CFG_*` o'zgaruvchilari
E-IMZO serverning har qanday parametrini prefiks orqali uzatishingiz mumkin:
`EIMZO_CFG_<PARAM_NAME>` formulasi:
- `EIMZO_CFG_CACHE_LOCAL_KEY_TTL_SECONDS=600`  ➡️  `cache.local.key.ttl.seconds=600`
- `EIMZO_CFG_SCHEDULER_FIXED_THREADS_COUNT=8`  ➡️  `scheduler.fixed.threads.count=8`

---

## 📊 Barcha sozlamalar jadvali (Reference)

| Muhit o'zgaruvchisi | Standart qiymat (Default) | Tavsif |
| :--- | :--- | :--- |
| `EIMZO_ENV` / `VPN_ENV` | `prod` | `prod` (`vpn.e-imzo.uz:3443`) yoki `test` (`testvpn.e-imzo.uz:2443`) |
| `VPN_CONNECT_HOST` | `vpn.e-imzo.uz` | VPN server manzili |
| `VPN_CONNECT_PORT` | `3443` | VPN server porti |
| `VPN_TLS_ENABLED` | `yes` | TLS orqali ulanish (`yes` yoki `no`) |
| `VPN_KEY_FILE_PATH` | *Avtomatik aniqlanadi* | Kalit fayl manzili (masalan: `keys/org.uz.key`) |
| `VPN_KEY_PASSWORD` | *(Bo'sh)* | Kalit paroli |
| `VPN_TRUSTSTORE_FILE_PATH` | `keys/vpn.jks` | VPN truststore fayli |
| `VPN_TRUSTSTORE_PASSWORD` | `12345678` | VPN truststore paroli |
| `TSP_JKS_FILE_PATH` | `keys/truststore.jks` | Vaqt tamg'asi (Timestamp) truststore fayli |
| `TSP_JKS_FILE_PASSWORD` | *(Bo'sh)* | TSP truststore paroli |
| `LISTEN_IP` | `0.0.0.0` | Konteyner ichidagi tinglovchi IP |
| `LISTEN_PORT` | `8080` | Konteyner ichidagi HTTP API porti |
| `CACHE_TYPE` | `local` | Kesh turi: `local` yoki `redis` |
| `CACHE_REDIS_HOST` | *(Bo'sh)* | Redis host manzili |
| `CACHE_REDIS_PORT` | `6379` | Redis porti |
| `CACHE_REDIS_PASSWORD` | *(Bo'sh)* | Redis paroli |
| `METRICS_ENABLED` | `false` | Prometheus metrikalari (`true` / `false`) |
| `METRICS_PORT` | `8081` | Metrikalar porti |
| `JAVA_OPTS` | `-Xms256m -Xmx512m -XX:+UseG1GC` | JVM xotira va GC parametrlari |
| `TZ` | `Asia/Tashkent` | Vaqt mintaqasi |

---

## 🔍 Ulanishni tekshirish va Salomatlik (Healthcheck)

### 1. Server holatini tekshirish (`/info`):
```bash
curl -i http://localhost:8080/info
```
Muvaffaqiyatli javob:
```json
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8

{
  "version": "2.2.1",
  "serverTime": "2026.10.09 10:15:20",
  "trustedCertificates": [...]
}
```

### 2. VPN ulanishini tekshirish (`/ping`):
```bash
curl -i http://localhost:8080/ping
```
VPN serverga muvaffaqiyatli ulanganida qaytadigan javob:
```json
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8

{
  "serverDateTime": "2026-10-09 10:15:20",
  "yourIP": "127.0.0.1",
  "vpnKeyInfo": {
    "serialNumber": "3",
    "X500Name": "CN=YourOrganization",
    "validFrom": "2026-01-01 00:00:00",
    "validTo": "2027-01-01 00:00:00"
  }
}
```

### 3. Docker Healthcheck holatini tekshirish:
```bash
docker inspect --format='{{json .State.Health.Status}}' e-imzo-server
# Natija: "healthy"
```

---

## 🔄 CI/CD va Semantic Versioning (GHCR)

Repozitoriyda `.github/workflows/docker-publish.yml` orqali to'liq avtomatlashtirilgan CI/CD yo'lga qo'yilgan.

### Semantic Versioning qoidalari:
Yangi versiyani nashr qilish uchun git tag qo'yib push qilinadi:

```bash
git tag v2.2.1
git push origin v2.2.1
```

GitHub Actions avtomatik tarzda quyidagi teglarni yaratadi va GHCR ga yuboradi:
- `ghcr.io/0605abmu/e-imzo-server:2.2.1` (aniq versiya)
- `ghcr.io/0605abmu/e-imzo-server:2.2` (minor versiya)
- `ghcr.io/0605abmu/e-imzo-server:2` (major versiya)
- `ghcr.io/0605abmu/e-imzo-server:latest` (eng so'nggi barqaror versiya)

### Kesh optimallashuvi:
- Docker Buildx va GitHub Actions Cache (`type=gha,mode=max`) integratsiya qilingan.
- Baza qatlamlari, `dumb-init`, `tzdata` va distributiv fayllari keshlanadi, bu esa keyingi yig'ilishlarni bir necha soniyada yakunlanishini ta'minlaydi.

### GHCR dan foydalanish:
```bash
# Avtorizatsiya (shaxsiy omborlar uchun):
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Obrazni tortib olish:
docker pull ghcr.io/0605abmu/e-imzo-server:2.2.1
```

---

## 🛡 Xavfsizlik (Security Hardening)

1. **Non-Root Execution**: Dastur konteyner ichida `root` huquqiga ega bo'lmagan `eimzo` (UID 10001) foydalanuvchisi sifatida ishlaydi.
2. **Minimal Ataka Maydoni (Attack Surface)**: Ishlatilmaydigan test kutubxonalari, kompilyatorlar, paket menejer keshlaridan tozalanadi.
3. **Faqat O'qish Huquqi (Read-Only Keys)**: Kalitlar konteynerga `:ro` (read-only) rejimida ulanishi tavsiya etiladi.
4. **Git Xavfsizligi**: `.gitignore` fayliga `*.key` va `*.jks` qoidalari kiritilgan bo'lib, nozik parollar va kalitlarning Git omboriga chiqib ketishi oldi olingan.

---

## 📄 Litsenziya va Huquqiy Ogohlantirish

Ushbu loyiha faqat e-imzo-server dasturini ishga tushirish uchun yordamchi konteynerlashtirish vositalarini o'z ichiga oladi. E-IMZO dasturiy ta'minotining barcha mualliflik huquqlari **Davlat soliq qo'mitasi huzuridagi «Yangi texnologiyalar» ilmiy-axborot markazi**ga tegishli bo'lib, undan foydalanish uchun tegishli shartnoma talab etiladi.
