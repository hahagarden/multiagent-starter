#!/bin/sh
# 응답 종료 시점에 검사를 실행한다. 실패하면 종료를 막고(exit 2), 재시도가 3회를 넘으면 종료를 허용한다.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
. .claude/hooks/log.sh
cnt=.claude/hooks/retry-count

n=$(cat "$cnt" 2>/dev/null); n=${n:-0}
out=$(sh check.sh google-analysis.html 2>&1); code=$?
reason=$(printf '%s' "$out" | tr '\n' ' ')

if [ "$code" -eq 0 ]; then
  run_log Stop stop.sh "통과 (시도 $((n + 1)))"
  # 직전 시도가 실패였을 때만 실패 로그에 통과 결과를 기록한다.
  [ "$n" -gt 0 ] && fail_log "[시도 $((n + 1))] 재시도 후 통과"
  echo 0 > "$cnt"
  exit 0
fi

n=$((n + 1))
run_log Stop stop.sh "실패 (시도 $n)"
if [ "$n" -gt 3 ]; then
  fail_log "[시도 $n] 실패, 재시도 3회 초과로 종료 허용: $reason"
  echo 0 > "$cnt"
  exit 0
fi

echo "$n" > "$cnt"
fail_log "[시도 $n] 실패, 종료 막음: $reason"
echo "검사 실패 (시도 $n, 재시도는 3회까지): $reason" >&2
exit 2
