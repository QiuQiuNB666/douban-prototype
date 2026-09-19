#!/bin/zsh
# 重新截图：先保证 http://localhost:8770 在跑（worktree 里的预览配置 douban-prototype，或 python3 -m http.server 8770 --directory ../原型）
cd "$(dirname "$0")"; CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; BASE="http://localhost:8770/%E8%B1%86%E4%BC%B4.html"
curl -s -o /dev/null --max-time 4 "$BASE" || { echo "8770 上没有服务，先把预览服务起起来"; exit 1; }
shot(){ perl -e 'alarm 40; exec @ARGV' -- "$CH" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=500,800 --virtual-time-budget=4000 --user-data-dir="${TMPDIR:-/tmp}/chrome-shot" --screenshot="$PWD/$1.png" "$BASE#$2" >/dev/null 2>&1; [ -s "$1.png" ] && echo "ok   $1" || echo "FAIL $1"; }
shot 01-孩子页-先猜后看 "shot=kid-guess"
shot 02-孩子页-揭晓 "shot=kid-reveal&guess=50"
shot 03-家长页-本周提醒 "shot=par-remind"
shot 04-家长页-AI读到了什么 "shot=par-ai"
shot 05-家长页-第二轮 "shot=par-round2"
shot 06-家长页-知情与删除 "shot=par-trust"
shot 07-家长页-考试周不提醒 "shot=par-remind&case=1"
pkill -f "chrome-shot" 2>/dev/null; true
