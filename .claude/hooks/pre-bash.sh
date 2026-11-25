#!/bin/sh
# Bash 명령 실행 직전에 검사한다. 파일·디렉터리 삭제 명령이 포함되면 실행을 막는다(exit 2).
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
. .claude/hooks/log.sh

# stdin JSON에서 tool_input.command 값만 추출한다. 줄바꿈(\n)은 ;로 치환한다.
cmd=$(cat | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | sed -e 's/\\n/; /g' -e 's/\\"/"/g')

B='(^|[^[:alnum:]_.-])'   # 단어 경계(앞)
E='([^[:alnum:]_.-]|$)'   # 단어 경계(뒤)

has() { printf '%s' "$cmd" | grep -Eq "$1"; }

reason=
if has "${B}rm[[:space:]]+(.*[[:space:]])?(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)${E}"; then reason="rm -r: 디렉터리 재귀 삭제"
elif has "${B}git[[:space:]]+rm${E}"; then reason="git rm: 저장소와 작업 트리에서 파일 삭제"
elif has "${B}git[[:space:]]+clean${E}"; then reason="git clean: 추적되지 않는 파일·디렉터리 삭제"
elif has "${B}find[[:space:]].*-delete${E}"; then reason="find -delete: 검색된 파일 일괄 삭제"
elif has "${B}rmdir${E}"; then reason="rmdir: 디렉터리 삭제"
elif has "${B}unlink${E}"; then reason="unlink: 파일 삭제"
elif has "${B}rm${E}"; then reason="rm: 파일 삭제"
fi

if [ -z "$reason" ]; then
  run_log PreToolUse pre-bash.sh 통과
  exit 0
fi

run_log PreToolUse pre-bash.sh 막음
fail_log "[명령 막음] $reason: $cmd"
echo "실행 막음: $reason (명령: $cmd)" >&2
exit 2
