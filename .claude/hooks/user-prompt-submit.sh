#!/bin/sh
# 요청 제출 시 Stop 훅의 재시도 횟수를 0으로 초기화한다.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
. .claude/hooks/log.sh
echo 0 > .claude/hooks/retry-count
run_log UserPromptSubmit user-prompt-submit.sh 통과
exit 0
