#!/bin/sh
# 사용법: sh check.sh <분석 페이지.html>
f="${1:?검사할 HTML 파일을 지정하세요}"
fail=0
bad() { echo "실패: $1"; fail=1; }

[ -f "$f" ] || { echo "실패: 파일 없음 $f"; exit 1; }

for id in overview financials news risks; do
  grep -q "<section id=\"$id\"" "$f" || bad "섹션 #$id 없음"
done

[ "$(grep -c '<section id="missing"' "$f")" -eq 1 ] || bad "빠진 자료 블록이 정확히 하나가 아님"

awk '/<section id="financials"/,/<\/section>/' "$f" | grep -q '<svg' || bad "재무 요약에 차트 없음"
awk '/<section id="financials"/,/<\/section>/' "$f" | grep -q '기간:' || bad "차트 기간 표기 없음"

body=$(awk '/<footer>/{exit} {print}' "$f")
echo "$body" | grep -q 'href="http' && bad "본문에 출처 링크가 직접 달려 있음"

cited=$(echo "$body" | grep -o 'href="#src-[0-9]*"' | grep -o '[0-9]*' | sort -un)
listed=$(grep -o 'id="src-[0-9]*"' "$f" | grep -o '[0-9]*' | sort -un)
for n in $cited; do echo "$listed" | grep -qx "$n" || bad "출처 $n 번이 목록에 없음"; done
for n in $listed; do echo "$cited" | grep -qx "$n" || bad "출처 $n 번이 본문에서 쓰이지 않음"; done

awk '/<footer>/,/<\/footer>/' "$f" | grep -q 'class="asof".*작성 시점.*자료 기준일' || bad "출처 목록 옆 작성 시점·기준일 줄 없음"

grep -Eq '매수|매도|투자 ?권유|투자 ?추천|목표 ?주가|비중 ?확대|비중 ?축소' "$f" && bad "투자 판단을 권하는 문구 포함"

# 리스크 위험도: 항목마다 값이 있고, 3단계 이상이 화면에 보이고, 단계마다 다른 보라색
risks=$(awk '/<section id="risks"/,/<\/section>/' "$f")
items=$(echo "$risks" | grep -cE 'class="([^"]* )?risk( [^"]*)?"')
rated=$(echo "$risks" | grep -E 'class="([^"]* )?risk( [^"]*)?"' | grep -cE 'data-level="(high|mid|low)"')
[ "$items" -gt 0 ] && [ "$items" -eq "$rated" ] || bad "위험도 값이 없는 리스크 항목 있음 ($rated/$items)"
levels=$(echo "$risks" | grep -oE 'data-level="(high|mid|low)"' | sort -u | wc -l | tr -d ' ')
[ "$levels" -ge 3 ] || bad "리스크 블록에 보이는 위험도 단계가 3개 미만 (${levels}개)"
for lv in high mid low; do
  grep -q "\[data-level=\"$lv\"\].*var(--risk-$lv)" "$f" || bad "위험도 $lv 단계에 색 규칙 없음"
done

# --risk-high/mid/low 색이 테마마다 서로 다르고, 보라색(색상 260~300도)이며, 연하기가 서로 다른지
colors=$(awk '
function hx(s,  i, v) { v = 0; s = tolower(s); for (i = 1; i <= length(s); i++) v = v * 16 + index("0123456789abcdef", substr(s, i, 1)) - 1; return v }
/--risk-high:/ {
  n++; split("high mid low", lv, " "); seen = ""; lights = ""
  for (k = 1; k <= 3; k++) {
    if (!match($0, "--risk-" lv[k] ":[ ]*#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]")) { print n "번째 테마에 --risk-" lv[k] " 색 없음"; continue }
    h = substr($0, RSTART + RLENGTH - 6, 6)
    r = hx(substr(h, 1, 2)) / 255; g = hx(substr(h, 3, 2)) / 255; b = hx(substr(h, 5, 2)) / 255
    mx = r; if (g > mx) mx = g; if (b > mx) mx = b
    mn = r; if (g < mn) mn = g; if (b < mn) mn = b
    d = mx - mn; l = int((mx + mn) * 50 + 0.5)
    if (d == 0) hue = -1
    else if (mx == r) hue = 60 * ((g - b) / d)
    else if (mx == g) hue = 60 * ((b - r) / d) + 120
    else hue = 60 * ((r - g) / d) + 240
    if (hue < 0 && d != 0) hue += 360
    if (hue < 260 || hue > 300) printf "%d번째 테마 --risk-%s #%s 가 보라색이 아님 (색상 %d도)\n", n, lv[k], h, hue
    if (index(seen, h)) printf "%d번째 테마 --risk-%s 색이 다른 단계와 같음\n", n, lv[k]
    if (index(lights, "|" l "|")) printf "%d번째 테마 --risk-%s 연하기가 다른 단계와 같음 (%d%%)\n", n, lv[k], l
    seen = seen " " h; lights = lights "|" l "|"
  }
}
END { if (n == 0) print "위험도 색 토큰(--risk-high/mid/low) 없음" }' "$f")
[ -n "$colors" ] && { echo "$colors" | sed 's/^/실패: /'; fail=1; }

# 모양: 섹션마다 대주제(h2) → 맨 위 한 줄 요약 → 소주제(h3) → 카드
for id in overview financials news risks missing; do
  sec=$(awk -v id="$id" 'index($0, "<section id=\"" id "\""), /<\/section>/' "$f")
  echo "$sec" | grep -q '<h2' || bad "#$id 대주제(h2) 없음"
  echo "$sec" | grep -q '<h3' || bad "#$id 소주제(h3) 없음"
  echo "$sec" | grep -q 'class="card[ "]' || bad "#$id 본문을 감싼 카드 없음"
  [ "$(echo "$sec" | grep -c 'class="summary"')" -eq 1 ] || bad "#$id 한 줄 요약이 정확히 하나가 아님"
  echo "$sec" | grep -A1 'class="sec-head"' | sed -n 2p | grep -q 'class="summary"' || bad "#$id 한 줄 요약이 맨 위에 없음"
done

# 모양: 한 문단은 두 문장까지
long=$(awk '/<body/,0' "$f" | grep -o '<p[ >].*</p>' | sed 's/<[^>]*>//g' | awk '{ t = $0; n = gsub(/[.?!]( |$)/, "", t); if (n > 2) print n "문장: " substr($0, 1, 40) "…" }')
[ -n "$long" ] && { echo "$long" | sed 's/^/실패: 문단이 두 문장을 넘음 /'; fail=1; }

# 모양: 색·여백·글자 크기는 :root 토큰으로만 (토큰 블록 밖 CSS와 style 속성 검사)
css=$(awk '/<style>/,/<\/style>/' "$f" | awk '/^[ \t]*:root/ { skip = 1 } !skip { print } skip && /^[ \t]*}/ { skip = 0 }')
inline=$(awk '/<body/,0' "$f" | grep -o 'style="[^"]*"' | sed 's/^style="//; s/"$/;/')
lit=$(printf '%s\n%s\n' "$css" "$inline" | awk '
{ buf = buf " " $0 }
END {
  gsub(/[{}]/, ";", buf); n = split(buf, d, ";")
  for (i = 1; i <= n; i++) {
    c = index(d[i], ":"); if (!c) continue
    p = d[i]; sub(/:.*/, "", p); gsub(/^[ \t]+|[ \t]+$/, "", p)
    v = substr(d[i], c + 1); gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (v ~ /#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]([^0-9a-zA-Z_-]|$)|#[0-9a-fA-F]{6}|rgba?\(|hsla?\(/) print "색 값을 직접 씀: " p ": " v
    if (p ~ /^(font-size|margin(-(top|right|bottom|left))?|padding(-(top|right|bottom|left))?|gap|row-gap|column-gap)$/) {
      m = split(v, t, /[ \t]+/)
      for (k = 1; k <= m; k++) if (t[k] !~ /^(0|auto|var\(--[a-z0-9-]+\))$/) { print "여백·글자 크기를 직접 씀: " p ": " v; break }
    }
  }
}')
[ -n "$lit" ] && { echo "$lit" | sort -u | sed 's/^/실패: /'; fail=1; }

# 토큰 값(px)을 :root 첫 블록에서 읽는다
root=$(awk '/^[ \t]*:root[ \t]*{/,/}/' "$f" | head -n 40)
px() { echo "$root" | grep -o -- "$1: *[0-9.]*px" | head -n 1 | grep -o '[0-9.]*px' | tr -d 'px'; }

# 모양: 제일 중요한 값 하나를 첫 화면에서 제일 크게
[ "$(awk '/<header>/,/<\/header>/' "$f" | grep -c 'class="hero-value"')" -eq 1 ] || bad "머리에 가장 큰 값(hero-value)이 정확히 하나가 아님"
grep -q '\.hero-value {[^}]*font-size: var(--fs-hero)' "$f" || bad ".hero-value가 --fs-hero 크기를 쓰지 않음"
hero=$(px --fs-hero); maxfs=$(echo "$root" | grep -o -- '--fs-[a-z0-9-]*: *[0-9.]*px' | grep -o '[0-9.]*px' | tr -d 'px' | sort -n | tail -n 1)
[ -n "$hero" ] && [ "$hero" = "$maxfs" ] || bad "--fs-hero(${hero:-없음})가 가장 큰 글자 크기(${maxfs:-없음})가 아님"

# 모양: 카드는 한 벌 — .card만 테두리·모서리·그림자·안쪽 여백을 정한다
card=$(grep -o '^[ \t]*\.card {[^}]*}' "$f")
for prop in border border-radius box-shadow padding; do
  echo "$card" | grep -q "[{; ]$prop:" || bad ".card 규칙에 $prop 없음"
done
echo "$css" | grep 'box-shadow' | grep -v '^[ \t]*\.card {' | grep -q . && bad ".card 말고 다른 규칙이 그림자를 정함"
for cls in $(grep -o 'class="card [^"]*"' "$f" | sed 's/class="card //; s/"//' | tr ' ' '\n' | sort -u); do
  echo "$css" | grep -E "^[ \t]*\.$cls(\[[^]]*\])? \{[^}]*(border|padding|box-shadow)" | grep -q . && bad "카드에 붙은 .$cls 규칙이 카드 모양을 바꿈"
done

# 모양: 카드 사이 여백 > 카드 안쪽 여백
pad=$(px --card-pad); gap=$(px --card-gap)
[ -n "$pad" ] && [ -n "$gap" ] && [ "$(echo "$gap > $pad" | bc)" -eq 1 ] || bad "카드 사이 여백(${gap:-없음})이 안쪽 여백(${pad:-없음})보다 넓지 않음"
echo "$card" | grep -q 'padding: var(--card-pad)' || bad ".card 안쪽 여백이 --card-pad가 아님"
grep -q '^[ \t]*\.cards {[^}]*gap: var(--card-gap)' "$f" || bad ".cards 사이 여백이 --card-gap이 아님"

# 모양: 좁은 화면(360px)에서 가로로 넘치지 않음 — Chrome headless로 측정
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$chrome" ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/narrow.XXXXXX")
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  printf '<iframe id="f" src="file://%s" style="width:360px;height:800px;border:0"></iframe><script>f.onload=function(){var d=f.contentDocument.documentElement;document.body.setAttribute("data-r",d.scrollWidth+"/"+d.clientWidth)}</script>' "$abs" > "$tmp/w.html"
  r=$("$chrome" --headless=new --disable-gpu --allow-file-access-from-files --user-data-dir="$tmp/p" --virtual-time-budget=3000 --dump-dom "file://$tmp/w.html" 2>/dev/null | grep -o 'data-r="[0-9]*/[0-9]*"' | grep -o '[0-9]*/[0-9]*')
  rm -rf "$tmp"
  if [ -z "$r" ]; then bad "좁은 화면 측정 실패 (Chrome 결과 없음)"
  elif [ "${r%/*}" -gt "${r#*/}" ]; then bad "360px 화면에서 가로로 넘침 (내용 ${r%/*}px > 화면 ${r#*/}px)"; fi
else
  echo "건너뜀: 좁은 화면 검사 (Chrome 없음)"
fi

# 글자 수: 화면에 보이는 글자, 공백 포함, 출처 목록(footer) 제외, 3,000자 이하
chars=$(awk '/<head>/,/<\/head>/ { next } /<script>/,/<\/script>/ { next } /<footer>/,/<\/footer>/ { next } { print }' "$f" \
  | sed 's/<[^>]*>//g; s/&[a-z]*;/ /g' | tr -s ' \t\n' ' ' | sed 's/^ //; s/ $//' | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')
[ "$chars" -le 3000 ] || bad "본문 글자 수 ${chars}자가 3,000자를 넘음"
echo "본문 글자 수: ${chars}자 / 3,000자"

[ "$fail" -eq 0 ] && echo "통과: $f"
exit "$fail"
