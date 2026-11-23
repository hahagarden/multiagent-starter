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

# 실습용: 절대 통과할 수 없는 조건
bad "실습용 조건 — 이 검사는 항상 실패함"

[ "$fail" -eq 0 ] && echo "통과: $f"
exit "$fail"
