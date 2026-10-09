# Xavfsizlik Siyosati (Security Policy)

## 📌 Qo'llab-quvvatlanadigan Versiyalar (Supported Versions)

Faqat eng so'nggi barqaror versiyalar uchun xavfsizlik yangilanishlari chiqariladi:

| Versiya | Qo'llab-quvvatlanadi |
| :--- | :--- |
| `2.2.x` / `latest` | :white_check_mark: Ha |
| `< 2.2.0` | :x: Yo'q |

---

## 🚨 Zaifliklar haqida xabar berish (Reporting a Vulnerability)

Agar ushbu loyihada (Docker packaging, skriptlar yoki konfiguratsiyalarda) xavfsizlik zaifligini aniqlasangiz:

> ⚠️ **Iltimos, xavfsizlik muammolari haqida hammaga ochiq GitHub Issues ochmang!**

Xavfsizlik zaifliklari haqida xabar berish uchun:
1. **GitHub Security Advisory** orqali: [Report a vulnerability](https://github.com/0605AbMu/e-imzo-server/security/advisories/new)
2. Yoki to'g'ridan-to'g'ri elektron pochta orqali: **0605AbMu@gmail.com**

Xabarda quyidagi ma'lumotlarni taqdim etishingizni so'raymiz:
- Zaiflik tavsifi va uning turi
- Zaiflikni takrorlash (reproduce) bo'yicha qadamlar (PoC)
- Xavf darajasi va potensial oqibatlari

Biz xabaringizni **48 soat** ichida ko'rib chiqishga va zaiflik tasdiqlansa, imkon qadar tezroq tuzatish (patch) chiqarishga harakat qilamiz.

---

## 🛡️ Javobgarlik doirasi (Scope of Responsibility)

### Loyiha doirasiga kiruvchi (In Scope):
- Dockerfile va uning asosiy qatlamlari (Alpine, Corretto runtime)
- Konteyner ishga tushirish skripti (`docker-entrypoint.sh`)
- Standart foydalanuvchi huquqlari (Non-root `eimzo` user)
- GitHub Actions CI/CD pipeline xavfsizligi

### Loyiha doirasidan tashqari (Out of Scope):
- **E-IMZO asosiy binar taqsimoti:** E-IMZO xizmatining o'zi (upstream JAR/binar fayllari) davlat organi (Yangi Texnologiyalar IAM / DSQ) tomonidan tuzilgan va taqdim etilgan.
- **Mijoz kalitlari xavfsizligi:** Foydalanuvchining shaxsiy/tashkilot `.key` kalitlari, sertifikatlari va parollari.
- **Server infratuzilmasi:** Foydalanuvchi serveri yoki tarmog'idagi xavfsizlik kamchiliklari (masalan, `8080` portini ochiq internetga himoyasiz chiqarib qo'yish).

---

## 🔒 Foydalanuvchilar uchun xavfsizlik bo'yicha tavsiyalar

1. **Kalitlar katalogini faqat o'qish (`:ro`) rejimida ulang:**
   ```yaml
   volumes:
     - ./keys:/opt/e-imzo-server/keys:ro
   ```
2. **Portni ochiq internetga qaratmang:**
   E-IMZO server portini (`8080`) faqat ichki tarmoqda (masalan, `127.0.0.1:8080:8080` yoki ichki Docker network) qoldiring. Tashqi so'rovlar uchun doimo autentifikatsiyaga ega Reverse Proxy (Nginx, Traefik va h.k.) dan foydalaning.
3. **Parollarni kodda saqlamang:**
   `VPN_KEY_PASSWORD` va boshqa maxfiy parametrlarni versiyalar nazorati (Git) tizimiga kiritmang, ularni `.env` yoki maxsus Secret Manager orqali uzating.
