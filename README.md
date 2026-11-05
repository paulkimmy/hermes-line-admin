# Hermes × LINE OA — แอดมินตอบลูกค้า 24 ชม.

สคริปต์ + คู่มือจากคลิป "ต่อ Hermes Agent เข้ากับ LINE OA" (paulkimmy)

## ใช้งานทันที (Hostinger VPS — template Hermes Agent)

```bash
curl -sL https://raw.githubusercontent.com/paulkimmy/hermes-line-admin/main/line-connect.sh -o line-connect.sh
bash line-connect.sh vps cloud.yourdomain.com
```

## ทดลองบน Mac (cloudflared ชั่วคราว)

```bash
curl -sL https://raw.githubusercontent.com/paulkimmy/hermes-line-admin/main/line-connect.sh -o line-connect.sh
bash line-connect.sh mac
```

สคริปต์จะถาม Channel access token + secret (จาก LINE Console) แล้ววาง everything ให้: profile, shared listener, Traefik HTTPS, ตรวจ token จริงกับ LINE API ก่อนเสมอ, ปลดอาวุธ toolset (ปลอดภัยต่อ prompt injection), รอ gateway บูต ~30 วิให้เอง

ดูสิ่งที่สคริปต์จะทำก่อนแตะเครื่องจริง: `DRY=1 bash line-connect.sh vps ...`

> คู่มือฉบับอ่านง่ายสำหรับผู้ชม (quickstart.html) แนบใน repo — เปิดผ่าน https://cdn.jsdelivr.net/gh/paulkimmy/hermes-line-admin@main/quickstart.html
