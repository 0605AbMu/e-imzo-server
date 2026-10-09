# E-IMZO Server Kalitlari (VPN Keys & Certificates)

Ushbu papka e-imzo-server uchun zarur bo'lgan VPN kalitlari va sertifikatlarni joylashtirish uchun mo'ljallangan.

### Joylashtirilishi kerak bo'lgan fayllar:
1. **`*.key`** — Tashkilotingiz uchun E-IMZO / NIC tomonidan berilgan VPN mijoz kaliti (masalan: `example.uz-2026-10-24.key`).
2. **`vpn.jks`** — VPN ulanishining ishonchli sertifikatlar ombori.
3. **`truststore.jks`** — Davlat soliq qo'mitasi / NIC E-IMZO sertifikatlari ombori (TSP / Timestamp uchun).

### Eslatma:
- Ushbu papka konteynerga `/opt/e-imzo-server/keys:ro` sifatida ulanadi (volume mount).
- Agar papkada bitta `*.key` fayl bo'lsa, konteyner uni avtomatik aniqlaydi.
- Xavfsizlik yuzasidan shaxsiy kalitlarni (`*.key`, `*.jks`) hech qachon ommaviy Git omboriga yuklamang (`.gitignore` ga kiritilgan).
