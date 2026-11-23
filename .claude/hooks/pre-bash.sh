#!/bin/sh
# Bash 명령 실행 직전에 검사한다. 파일이나 폴더를 통째로 지우는 표현이 있으면 막는다(exit 2).
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
log=.claude/hook-log.txt
now=$(date '+%Y-%m-%d %H:%M:%S')

# stdin JSON에서 tool_input.command 값만 꺼낸다. 줄바꿈(\n)은 ;로 바꾼다.
cmd=$(cat | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | sed -e 's/\\n/; /g' -e 's/\\"/"/g')

B='(^|[^[:alnum:]_.-])'   # 낱말 앞 경계
E='([^[:alnum:]_.-]|$)'   # 낱말 뒤 경계

has() { printf '%s' "$cmd" | grep -Eq "$1"; }

reason=
if has "${B}rm[[:space:]]+(.*[[:space:]])?(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)${E}"; then reason="rm -r: 폴더를 내용째 지움"
elif has "${B}git[[:space:]]+rm${E}"; then reason="git rm: 파일을 저장소와 디스크에서 지움"
elif has "${B}git[[:space:]]+clean${E}"; then reason="git clean: 추적하지 않는 파일과 폴더를 지움"
elif has "${B}find[[:space:]].*-delete${E}"; then reason="find -delete: 찾은 파일을 모두 지움"
elif has "${B}rmdir${E}"; then reason="rmdir: 폴더를 지움"
elif has "${B}unlink${E}"; then reason="unlink: 파일을 지움"
elif has "${B}rm${E}"; then reason="rm: 파일을 지움"
fi

[ -z "$reason" ] && exit 0

echo "$now [명령 막음] $reason: $cmd" >> "$log"
echo "실행 막음: $reason (명령: $cmd)" >&2
exit 2
