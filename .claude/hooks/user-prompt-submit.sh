#!/bin/sh
# 새 요청마다 Stop 훅의 재시도 횟수를 0으로 되돌린다.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
echo 0 > .claude/hooks/retry-count
echo "$(date '+%Y-%m-%d %H:%M:%S') 새 요청" >> .claude/hook-log.txt
exit 0
