#!/usr/bin/env bash
# =====================================================================
# line-connect.sh — Hermes × LINE OA in ONE command (v1.1)
# กลั่นจากของจริงทั้งวัน: token, profile lane, shared listener, Traefik
#
#  usage:
#    bash line-connect.sh mac            # ตั้งบน Mac (cloudflared tunnel)
#    bash line-connect.sh vps your-domain.com   # รันบน Hostinger VPS
#  non-interactive:
#    LINE_TOKEN="xxx" LINE_SECRET="yyy" bash line-connect.sh vps
#  dry-run (ดูว่าจะทำอะไรบ้าง ไม่แตะจริง):
#    DRY=1 bash line-connect.sh vps
# =====================================================================
set -euo pipefail
GREEN='\033[32m'; AMBER='\033[33m'; RED='\033[31m'; DIM='\033[2m'; NC='\033[0m'
say(){ printf "${GREEN}▸${NC} %s\n" "$*"; }
warn(){ printf "${AMBER}⚠${NC} %s\n" "$*"; }
die(){ printf "${RED}✗${NC} %s\n" "$*"; exit 1; }
run(){ if [ "${DRY:-0}" = "1" ]; then printf "${DIM}  [dry] $*${NC}\n"; else "$@"; fi; }

MODE="${1:-}"
[ -n "$MODE" ] || die "usage: bash line-connect.sh mac | vps your-domain.com"

PROFILE="${BOT_PROFILE:-adminbot}"
if [ "$MODE" = "vps" ]; then [ $# -ge 2 ] || die "usage: bash line-connect.sh vps your-domain.com (A record ชี้มา VPS แล้ว)"; DOMAIN="$2"; fi

# ---------- credentials ----------
ask(){ local v="$1" p="$2"; if [ -n "${!v:-}" ]; then :; else read -rsp "$p" x; eval "$v='$x'"; echo; fi; }
ask LINE_TOKEN "LINE Channel access token (จาก Console → Issue): "
ask LINE_SECRET "LINE Channel secret: "
[ ${#LINE_TOKEN} -ge 30 ] || die "token สั้นผิดปกติ (ได้ ${#LINE_TOKEN} ตัว) — ไป Issue ใหม่ยาวๆ นะ"

# ---------- verify token ก่อนเสมอ (บทเรียน: อย่าเดาจาก length) ----------
say "ตรวจ token กับ LINE API ..."
AUTHH="Bearer ***"
BOTNAME=$(curl -sf -m 15 https://api.line.me/v2/bot/info -H "Authorization: ${AUTHH}" | sed -n 's/.*"displayName":"\([^"]*\)".*/\1/p') || die "LINE ปฏิเสธ token นี้ — ลอง copy ใหม่ทั้งก้อน (ห้ามตัดต่อ)"
say "OK — พบ OA «$BOTNAME» 🎉"

env_block(){ # $1 = path to .env
  if [ "${DRY:-0}" = "1" ]; then printf "${DIM}  [dry] write LINE_ keys → $1${NC}"; else
    touch "$1"; grep -v '^LINE_' "$1" > "$1.tmp" 2>/dev/null || true
    { echo "LINE_CHANNEL_ACCESS_TOKEN=$LINE_TOKEN"; echo "LINE_CHANNEL_SECRET=$LINE_SECRET"; cat "$1.tmp" 2>/dev/null; } > "$1"
    rm -f "$1.tmp"; fi; }

wait_health(){ # $1 url
  local url="$1" i
  say "ตรวจ webhook lane (gateway บูตช้า ~30 วิ อดทนหน่อย) ..."
  for i in $(seq 1 10); do
    if [ "${DRY:-0}" = "1" ]; then printf "${DIM}  [dry] curl $url${NC}\n"; return 0; fi
    if curl -k -sf -m 8 "$url" | grep -q '"ok"'; then say "🟢 lane พร้อมแล้ว!"; return 0; fi
    sleep 6
  done
  warn "ยัง health ไม่ผ่าน — ดู log: gateway ของ profile $PROFILE แล้วลอง /new"
}

# =====================================================================
if [ "$MODE" = "mac" ]; then
  H=~/.hermes
  say "โหมด MAC — bot = profile '$PROFILE' (แปะหลัง default listener :8644)"
  hermes profile create "$PROFILE" --description "LINE customer bot" 2>/dev/null || warn "(profile มีอยู่แล้ว)"
  mkdir -p "$H/profiles/$PROFILE"; env_block "$H/profiles/$PROFILE/.env"
  CH() { HERMES_HOME="$1" hermes config set "$2" "$3" >/dev/null; }
  CH "$H/profiles/$PROFILE" platforms.line.enabled true
  CH "$H"                     platforms.webhook.enabled true
  CH "$H"                     platforms.line.enabled false
  CH "$H/profiles/$PROFILE" agent.disabled_toolsets '["terminal","code_execution","browser","computer_use","delegation","cronjob","kanban"]'
  CH "$H/profiles/$PROFILE" memory.memory_enabled false
  say "restart gateway (ถ้าคำสั่งค้าง ~15 วิ = ปกติ กด Ctrl+C ได้ log บอกเอง)"
  run hermes gateway restart
  wait_health "http://127.0.0.1:8644/p/$PROFILE/line/webhook/health"

  say "ให้ลูกค้าทักจากทุกบัญชีได้เลยไหม? (แนะนำ y สำหรับบอทหน้าร้าน) [y/n]"
  read -r ANY; if [ "$ANY" = "y" ]; then
    echo "LINE_ALLOW_ALL_USERS=true" >> "$H/profiles/$PROFILE/.env"
    say "บันทึกแล้ว — กำลัง restart gateway"
    run hermes gateway restart
    wait_health "http://127.0.0.1:8644/p/$PROFILE/line/webhook/health"
  fi

  if command -v cloudflared >/dev/null 2>&1; then
    say "เปิด cloudflared ให้เลย? (y/n)"; read -r YN
    if [ "$YN" = "y" ]; then
      nohup cloudflared tunnel --url http://localhost:8644 > ~/cloudflared.log 2>&1 &
      sleep 8; URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' ~/cloudflared.log | head -1)
      [ -n "$URL" ] || die "อ่าน URL จาก ~/cloudflared.log ไม่เจอ — เปิด log ดูเอง"
      say "public URL: $URL"
      wait_health "$URL/p/$PROFILE/line/webhook/health"
      echo; printf "  ${GREEN}เอา URL นี้ไปใส่ LINE Console:${NC}\n  %s/p/%s/line/webhook\n\n" "$URL" "$PROFILE"
    fi
  else
    warn "ยังไม่มี cloudflared → brew install cloudflared แล้วรัน: cloudflared tunnel --url http://localhost:8644"
  fi
fi

# =====================================================================
if [ "$MODE" = "vps" ]; then
  [ "$(id -u)" = "0" ] || die "รันบน VPS ด้วย root นะครับ (ssh root@...)"
  [ -d /docker ] || die "ไม่พบ /docker — สคริปต์นี้ออกแบบให้ Hostinger 'Hermes Agent' template"
  PROJ=$(find /docker -maxdepth 1 -type d -name 'hermes-agent-*' | head -1)
  C=$(docker ps --format '{{.Names}}' | grep 'hermes-agent' | head -1)
  say "โหมด VPS — project=$PROJ container=$C domain=$DOMAIN"
  run docker exec -u hermes -e HERMES_HOME=/opt/data "$C" hermes profile create "$PROFILE" --description "LINE customer bot"
  mkdir -p "$PROJ/data/profiles/$PROFILE"; env_block "$PROJ/data/profiles/$PROFILE/.env"
  CH() { run docker exec -u hermes -e "HERMES_HOME=$1" "$C" hermes config set "$2" "$3" >/dev/null; }
  CH /opt/data/profiles/$PROFILE platforms.line.enabled true
  CH /opt/data/profiles/$PROFILE agent.disabled_toolsets '["terminal","code_execution","browser","computer_use","delegation","cronjob","kanban"]'
  CH /opt/data/profiles/$PROFILE memory.memory_enabled false
  CH /opt/data                     platforms.webhook.enabled true
  CH /opt/data                     platforms.line.enabled false
  say "ต่อ Traefik router '/p/$PROFILE/line' → :8644"
  CF="$PROJ/docker-compose.yml"
  if [ "${DRY:-0}" = "1" ]; then printf "${DIM}  [dry] patch labels ใน %s${NC}\n" "$CF"; else
    cp "$CF" "$CF.bak.$(date +%s)"
    grep -q 'traefik.http.routers.line' "$CF" || {
      sed -i "/env_file:/i \\      - traefik.enable=true\n      - traefik.http.routers.line.rule=Host(\`${DOMAIN}\`) \&\& PathPrefix(\`/p/${PROFILE}/line\`)\n      - traefik.http.routers.line.entrypoints=websecure\n      - traefik.http.routers.line.tls.certresolver=letsencrypt\n      - traefik.http.services.line.loadbalancer.server.port=8644" "$CF"; }
    sed -i "s|PathPrefix(\`/line\`)|PathPrefix(\`/p/${PROFILE}/line\`)|; s|PathPrefix(\`/p/[^\`]*\`)|PathPrefix(\`/p/${PROFILE}/line\`)|; s|traefik.http.services.line.loadbalancer.server.port=.*|traefik.http.services.line.loadbalancer.server.port=8644|" "$CF"
    fi
  run bash -c "cd $PROJ && docker compose up -d && docker restart $C"
  wait_health "https://$DOMAIN/p/$PROFILE/line/webhook/health"

  say "ให้ลูกค้าทักจากทุกบัญชีได้เลยไหม? (แนะนำ y สำหรับบอทหน้าร้าน) [y/n]"
  read -r ANY; if [ "$ANY" = "y" ]; then
    echo "LINE_ALLOW_ALL_USERS=true" >> "$PROJ/data/profiles/$PROFILE/.env"
    say "บันทึกแล้ว — กำลัง restart gateway"
    run docker restart "$C"
    wait_health "https://$DOMAIN/p/$PROFILE/line/webhook/health"
  fi

  echo; printf "  ${GREEN}✅ เสร็จ! เอา URL นี้ไป Verify ใน LINE Console:${NC}\n  https://%s/p/%s/line/webhook\n\n" "$DOMAIN" "$PROFILE"
  printf "${DIM}  (ถ้าเปลี่ยน OA ภายหลัง: token ใหม่ Issue แล้วรันสคริปต์นี้ซ้ำ = ทับของเก่าอย่างปลอดภัย)${NC}\n"
fi
