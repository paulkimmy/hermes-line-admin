# Hermes × LINE OA — สคริปต์แอดมิน 24 ชม.

ตัวต่อ LINE OA เข้ากับ Hermes Agent บน **Hostinger VPS template "Hermes Agent"** — จากคลิป "แอดมิน 24 ชม." (paulkimmy)

## เริ่มใช้งาน

1. **LINE Console** (developers.line.biz/console) → สร้าง Messaging API channel เชื่อมกับ OA ของคุณ → ปุ่ม **Issue** เอา Channel access token + copy Channel secret → ปิด **Auto-reply** ทั้งใน Console และ OA Manager
2. **เตรียมเครื่อง**:โดเมนคุณชี้ A record มาที่ VPS (เช่น `cloud.yourdomain.com`) และเข้า dashboard ของ template ตั้ง AI — *เชื่อมต่อแล้วต้องกดเลือก model ที่จะให้บอทใช้ด้วย ไม่งั้นบอทเงียบทั้งที่ health เขียว*
3. เปิด **Browser Terminal** ใน hPanel แล้วรัน:

```bash
curl -sL https://raw.githubusercontent.com/paulkimmy/hermes-line-admin/main/line-connect.sh -o line-connect.sh
bash line-connect.sh vps cloud.yourdomain.com
```

4. วาง token + secret เมื่อถูกถาม → คำถาม "ให้ลูกค้าทักจากทุกบัญชีได้ไหม" ตอบ `y` → รอ 🟢 (gateway บูต ~30 วิ)
5. คัด **URL ที่สคริปต์พิมพ์ให้บรรทัดสุดท้าย** ไปวางในช่อง Webhook URL ของ LINE Console → **Verify** → Use webhook ON → ทัก OA พิมพ์ `/new` แล้ว `hello` 🎉

## สคริปต์ทำอะไรให้

- ตรวจ token จริงกับ `api.line.me` ก่อนแตะเครื่อง (token ผิด = จบทันทีไม่ทำต่อ)
- สร้าง profile `adminbot` แยก + **ปลดอาวุธ toolset** (terminal/browser/code exec ปิด = ปลอดภัยต่อ prompt injection จากคนแปลกหน้า) + ปิด memory
- ตั้ง shared listener, Traefik router + Let's Encrypt HTTPS เอง (รวมการผูก router→service ที่ template มักพลาด)
- ถ้าเครื่องมีหลาย project จะให้เลือกระบบ (หรือระบุเอง: `PROJECT=/docker/hermes-agent-xxxx bash line-connect.sh vps ...`)
- รันซ้ำได้เสมอ = ทับของเก่าอย่างปลอดภัย (เปลี่ยน token/โดเมนใหม่只需รันใหม่)
-ดูก่อนโดยไม่แตะเครื่อง: `DRY=1 bash line-connect.sh vps your-domain.com`

## อาการที่เจอจริง

- **ตอบว่า Rate limited (429)** → โควตา AI หมด ไม่เกี่ยวกับระบบ: พิมพ์ `/model` สลับตัวที่ยังมีโควตา
- **เงียบสนิท health เขียว** → ยังไม่ได้เลือก model ให้บอท (ขั้น 2)
- **Verify ไม่ผ่าน 404/502** → gateway เพิ่ง restart รอ ~30 วิแล้วกดใหม่
- **ลูกค้าทักไม่ตอบทั้งที่บอทตอบเรา** → ตั้ง `LINE_ALLOW_ALLOWED_USERS` เป็น ID ตัวเองไว้ ตอบทุกคนด้วย `LINE_ALLOW_ALL_USERS=true` ใน `/docker/<project>/data/profiles/adminbot/.env` แล้ว `docker restart <container>`
