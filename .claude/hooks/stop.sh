#!/bin/sh
# 응답이 끝날 때 검사를 돌린다. 실패하면 종료를 막고(exit 2), 재시도가 3번을 넘으면 그냥 끝낸다.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
log=.claude/hook-log.txt
cnt=.claude/hooks/retry-count
now=$(date '+%Y-%m-%d %H:%M:%S')

n=$(cat "$cnt" 2>/dev/null); n=${n:-0}
out=$(sh check.sh google-analysis.html 2>&1); code=$?
reason=$(printf '%s' "$out" | tr '\n' ' ')

if [ "$code" -eq 0 ]; then
  echo "$now [시도 $((n + 1))] 통과" >> "$log"
  echo 0 > "$cnt"
  exit 0
fi

n=$((n + 1))
if [ "$n" -gt 3 ]; then
  echo "$now [시도 $n] 실패, 재시도 3회 초과로 종료 허용: $reason" >> "$log"
  echo 0 > "$cnt"
  exit 0
fi

echo "$n" > "$cnt"
echo "$now [시도 $n] 실패, 종료 막음: $reason" >> "$log"
echo "검사 실패 (시도 $n, 재시도는 3회까지): $reason" >&2
exit 2
