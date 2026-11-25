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
items=$(echo "$risks" | grep -c 'class="risk[ "]')
rated=$(echo "$risks" | grep 'class="risk[ "]' | grep -cE 'data-level="(high|mid|low)"')
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

[ "$fail" -eq 0 ] && echo "통과: $f"
exit "$fail"
