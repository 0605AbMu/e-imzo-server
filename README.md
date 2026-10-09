# E-IMZO Server — Docker Foydalanuvchi Qo'llanmasi

[![Docker Image](https://img.shields.io/badge/GHCR-ghcr.io%2F0605abmu%2Fe--imzo--server-blue?logo=docker)](https://github.com/0605AbMu/e-imzo-server/pkgs/container/e-imzo-server)
[![Version](https://img.shields.io/badge/version-2.2.1-green)](https://github.com/0605AbMu/e-imzo-server/releases)
[![Java](https://img.shields.io/badge/Java-8%20(Amazon%20Corretto)-orange)](https://aws.amazon.com/corretto/)
[![Alpine](https://img.shields.io/badge/Alpine-3.22-brightgreen)](https://alpinelinux.org/)

Ushbu qo'llanma **E-IMZO Server** (elektron raqamli imzolarni tekshirish va vaqt tamg'asi olish xizmati)ning tayyor Docker obrazidan foydalanish uchun mo'ljallangan.

> 💡 **Muhim:** Sizdan dasturni yig'ish (build qilish) yoki Java o'rnatish talab etilmaydi! Obraz allaqachon tayyor holda **GitHub Container Registry (GHCR)** ga joylangan:
> **`ghcr.io/0605abmu/e-imzo-server:latest`**

---

## 📌 Talablar

1. Serveringizda **Docker** va **Docker Compose** o'rnatilgan bo'lishi.
2. **Internet aloqasi:** Server faqat O'zbekiston hududidagi IP-manzildan bo'lishi shart (chunki E-IMZO VPN serverlari faqat milliy tarmoqdan qabul qiladi).
3. **E-IMZO Kalitlari:** Davlat soliq qo'mitasi / NIC tomonidan berilgan fayllar:
   - `*.key` — Tashkilotingizning VPN mijoz kaliti
   - `vpn.jks` — VPN sertifikatlar ombori
   - `truststore.jks` — TSP (vaqt tamg'asi) sertifikatlar ombori

---

## ⚡ Tezkor ishga tushirish (2 ta qadam)

### 1-usul: Docker Compose orqali (Tavsiya etiladi)

Bu eng oson va qulay usuldir.

#### 1-qadam. Papka va kalitlarni tayyorlang:
Serveringizda yangi papka oching va ichiga `keys` papkasini yaratib, kalit fayllaringizni joylashtiring:
```bash
mkdir -p my-eimzo/keys
cd my-eimzo

# Kalit fayllaringizni keys papkasiga nusxalang:
cp /path/to/my-company.key keys/
cp /path/to/vpn.jks keys/
cp /path/to/truststore.jks keys/
```

#### 2-qadam. `docker-compose.yml` faylini yarating:
Quyidagi mazmunda `docker-compose.yml` faylini saqlang:

```yaml
services:
  e-imzo-server:
    image: ghcr.io/0605abmu/e-imzo-server:latest
    container_name: e-imzo-server
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      # Muhit turi: 'test' (testvpn.e-imzo.uz:2443) yoki 'prod' (vpn.e-imzo.uz:3443)
      - EIMZO_ENV=prod

      # Kalitingiz paroli (.key fayl paroli):
      - VPN_KEY_PASSWORD=sizning_kalit_parolingiz

      # (Ixtiyoriy) Agar vpn.jks yoki truststore.jks paroli bo'lsa:
      # - VPN_TRUSTSTORE_PASSWORD=12345678
      # - TSP_JKS_FILE_PASSWORD=12345678

      # Kesh turi ('local' yoki 'redis')
      - CACHE_TYPE=local

      # JVM xotirasi (standart: 256MB min, 512MB max)
      - JAVA_OPTS=-Xms256m -Xmx512m -XX:+UseG1GC
      - TZ=Asia/Tashkent
    volumes:
      # Kalitlar papkasi (faqat o'qish rejimida - ro)
      - ./keys:/opt/e-imzo-server/keys:ro
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/info > /dev/null || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
```

#### 3-qadam. Ishga tushiring:
```bash
docker compose up -d
```

Loglarni tekshirish:
```bash
docker compose logs -f
```

---

### 2-usul: Oddiy `docker run` orqali

Hech qanday fayl yaratmasdan to'g'ridan-to'g'ri terminal orqali ishga tushirish:

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

> **Eslatma:** Test muhiti uchun shunchaki `-e EIMZO_ENV=test` qilib o'zgartirsangiz kifoya. Server avtomatik tarzda `testvpn.e-imzo.uz:2443` ga ulanadi.

---

## 🛠 Konfiguratsiyani oson sozlash usullari

Siz hech qanday murakkab `.properties` konfiguratsiya fayllarini yozishingiz shart emas.

### 1. Kalitlarni avtomatik aniqlash (Auto-Discovery)
`keys/` papkangizga `.key` kengaytmali faylni tashlasangiz bo'ldi. Konteyner ishga tushganda o'sha faylni avtomatik aniqlaydi va `vpn.key.file.path` ga o'zi biriktiradi. Shuningdek `vpn.jks` va `truststore.jks` fayllari ham mavjud bo'lsa, o'z-o'zidan ulanadi.

*(Faqatgina `keys/` ichida bir nechta `.key` fayl bo'lsa, `VPN_KEY_FILE_PATH=keys/aniq-nom.key` deb ko'rsatishingiz kerak).*

### 2. Test va Production rejimlari (`EIMZO_ENV`)
- `EIMZO_ENV=prod` (standart) ➡️ `vpn.connect.host=vpn.e-imzo.uz`, `port=3443`
- `EIMZO_ENV=test` ➡️ `vpn.connect.host=testvpn.e-imzo.uz`, `port=2443`

### 3. Tayyor `config.properties` faylini ulash (Ixtiyoriy)
Agar avvaldan tayyorlangan `config.properties` faylingiz bo'lsa, uni konteynerga to'g'ridan-to'g'ri ulashingiz mumkin:
```yaml
volumes:
  - ./my-config.properties:/opt/e-imzo-server/config/config.properties:ro
  - ./keys:/opt/e-imzo-server/keys:ro
```

### 4. Istalgan parametrni dinamik uzatish (`EIMZO_CFG_*`)
E-IMZO serverining har qanday maxsus parametrini `EIMZO_CFG_<PARAM_NAME>` orqali uzatishingiz mumkin:
- `-e EIMZO_CFG_CACHE_LOCAL_KEY_TTL_SECONDS=600` ➡️ `cache.local.key.ttl.seconds=600`
- `-e EIMZO_CFG_SCHEDULER_FIXED_THREADS_COUNT=8` ➡️ `scheduler.fixed.threads.count=8`

---

## 🔍 Ulanish va Ishlashni Tekshirish

Server ishga tushgach, uni `curl` orqali tekshirib ko'ring:

### 1. Server salomatligi va versiyasini tekshirish (`/info`):
```bash
curl http://localhost:8080/info
```
**Kutilayotgan javob:**
```json
{
  "version": "2.2.1",
  "serverTime": "2026.10.09 10:20:00",
  "trustedCertificates": [...]
}
```

### 2. VPN ulanishi holatini tekshirish (`/ping`):
```bash
curl http://localhost:8080/ping
```
VPN serverga muvaffaqiyatli ulanganida qaytadigan javob:
```json
{
  "serverDateTime": "2026-10-09 10:20:00",
  "yourIP": "127.0.0.1",
  "vpnKeyInfo": {
    "serialNumber": "3",
    "X500Name": "CN=SizningTashkilotingiz",
    "validFrom": "2026-01-01 00:00:00",
    "validTo": "2027-01-01 00:00:00"
  }
}
```
> `HTTP 200` — VPN ulanishi muvaffaqiyatli o'rnatilganini bildiradi.

---

## 🏷 Obraz Versiyalari (Semantic Versioning)

Obraz GHCR da SemVer qoidalariga binoan teglanadi:

| Teg (Tag) | Tavsif | Foydalanish holati |
| :--- | :--- | :--- |
| `ghcr.io/0605abmu/e-imzo-server:latest` | Eng so'nggi barqaror versiya | Doim yangilanib turuvchi ishlab chiqish muhiti |
| `ghcr.io/0605abmu/e-imzo-server:2.2.1` | Aniq (pinned) versiya | Production (barqarorlik uchun qat'iy tavsiya etiladi) |
| `ghcr.io/0605abmu/e-imzo-server:2.2` | 2.2 filialidagi eng oxirgi reliz | Kichik xatolik tuzatishlarini avtomat olish uchun |
| `ghcr.io/0605abmu/e-imzo-server:2` | 2.x vagonidagi eng oxirgi reliz | Asosiy yangilanishlar doirasida |

---

## ⚙️ Barcha Sozlamalar Ma'lumotnomasi

| O'zgaruvchi | Standart qiymat | Tavsif |
| :--- | :--- | :--- |
| `EIMZO_ENV` | `prod` | `prod` yoki `test` muhiti |
| `VPN_KEY_PASSWORD` | *(Bo'sh)* | VPN `.key` faylining paroli |
| `VPN_KEY_FILE_PATH` | *Avtomatik* | Agar bir nechta kalit bo'lsa, aniq fayl manzili (masalan: `keys/tashkilot.key`) |
| `VPN_CONNECT_HOST` | `vpn.e-imzo.uz` | VPN server manzili (`EIMZO_ENV` orqali boshqariladi) |
| `VPN_CONNECT_PORT` | `3443` | VPN server porti (`prod` uchun 3443, `test` uchun 2443) |
| `VPN_TLS_ENABLED` | `yes` | TLS rejimi |
| `VPN_TRUSTSTORE_FILE_PATH`| `keys/vpn.jks` | VPN truststore manzili |
| `VPN_TRUSTSTORE_PASSWORD` | `12345678` | VPN truststore paroli |
| `TSP_JKS_FILE_PATH` | `keys/truststore.jks` | Vaqt tamg'asi sertifikatlari ombori |
| `TSP_JKS_FILE_PASSWORD` | *(Bo'sh)* | TSP truststore paroli |
| `LISTEN_PORT` | `8080` | Konteyner ichidagi HTTP port |
| `LISTEN_IP` | `0.0.0.0` | Konteyner ichidagi IP |
| `CACHE_TYPE` | `local` | Kesh turi: `local` yoki `redis` |
| `CACHE_REDIS_HOST` | *(Bo'sh)* | Redis hosti (agar `CACHE_TYPE=redis` bo'lsa) |
| `CACHE_REDIS_PORT` | `6379` | Redis porti |
| `JAVA_OPTS` | `-Xms256m -Xmx512m -XX:+UseG1GC` | Java JVM xotira parametrlari |
| `TZ` | `Asia/Tashkent` | Konteyner vaqt mintaqasi |

---

## 🔒 Xavfsizlik bo'yicha tavsiyalar

1. **Kalitlar himoyasi:** Kalitlaringiz turgan `keys/` papkasini konteynerga faqat o'qish uchun (`:ro`) rejimida ulang:
   ```yaml
   volumes:
     - ./keys:/opt/e-imzo-server/keys:ro
   ```
2. **Konteyner foydalanuvchisi:** Obraz `root` huquqlarisiz, alohida `eimzo` (`UID 10001`) foydalanuvchisi ostida ishlaydi.
3. **Parollarni saqlash:** `VPN_KEY_PASSWORD` kabi parollarni ochiq fayllarda qoldirmaslik uchun `.env` faylidan foydalaning va uni `.gitignore` ga qo'shing.

---

## 👨‍💻 Loyiha Boshqaruvchilari (Maintainerlar) uchun

Yangi versiya reliz qilib, GHCR ga yangi Docker obraz chiqarish tartibi:

1. `assets/` papkasiga yangi versiya arxivini joylashtiring (masalan: `assets/e-imzo-server-v2.2.1.zip`).
2. O'zgarishlarni Git ga commit qilib, teg qo'ying va push qiling:
   ```bash
   git add assets/
   git commit -m "chore: add e-imzo-server v2.2.1 distribution"
   git push origin master

   # Teg qo'yish va push qilish:
   git tag v2.2.1
   git push origin v2.2.1
   ```

> ⚠️ **Qat'iy CI tekshiruvi (Asset Validation):**
> Teg push qilinganda (`v2.2.1`), GitHub Actions avtomatik tarzda `assets/` papkasidan teg versiyasiga mos keluvchi arxivni (`*2.2.1*.zip`) qidiradi:
> - **Agar mos arxiv mavjud bo'lsa:** O'sha asset asosida multi-stage Docker build boshlanadi va GHCR ga `2.2.1`, `2.2`, `2`, `latest` teglari muvaffaqiyatli publish qilinadi.
> - **Agar mos arxiv topilmasa:** CI darhol **FAIL** bo'ladi va xatolik chiqaradi (`CI failed: No asset archive found in assets/ for release tag v2.2.1`). Bu xato yoki bo'sh relizlar chiqib ketishining oldini oladi.
