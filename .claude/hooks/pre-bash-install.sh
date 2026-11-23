#!/bin/sh
# Bash 명령 실행 직전에 검사한다. 설치하는 표현이 있으면 그 설치 명령 부분만 danger-log.txt에 기록하고 막지 않는다.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
log=.claude/danger-log.txt
now=$(date '+%Y-%m-%d %H:%M:%S')

# stdin JSON에서 tool_input.command 값과 작업 폴더(cwd)를 꺼낸다. 줄바꿈(\n)은 ;로 바꾼다.
input=$(cat)
cmd=$(printf '%s' "$input" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | sed -e 's/\\n/; /g' -e 's/\\"/"/g')
cwd=$(printf '%s' "$input" | sed -nE 's/.*"cwd"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p')
cwd=${cwd:-$(pwd)}
case "$cwd" in "$HOME"*) cwd="~${cwd#"$HOME"}" ;; esac

# 설치하지 않고 정보만 보는 옵션이 붙은 조각은 기록하지 않는다.
NOINSTALL='(^|[[:space:]])(--help|-h|--version|--dry-run)([[:space:]=]|$)'

B='(^|[^[:alnum:]_.-])'   # 낱말 앞 경계
E='([^[:alnum:]_.-]|$)'   # 낱말 뒤 경계

# curl/wget 결과를 sh/bash로 넘기는 부분은 파이프째 기록한다.
printf '%s' "$cmd" | grep -oE "${B}(curl|wget)[[:space:]][^;&|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)${E}" \
  | sed -E 's/^[^[:alnum:]_.\/-]//; s/[[:space:]]*$//' | while IFS= read -r part; do
  echo "$now [설치 명령] $part (위치: $cwd)" >> "$log"
done

# 나머지는 ; && || | 로 나눈 조각 중 설치 표현이 있는 조각만 기록한다.
printf '%s\n' "$cmd" | awk '{ gsub(/[[:space:]]*(&&|\|\||;|\|)[[:space:]]*/, "\n"); print }' | while IFS= read -r part; do
  if printf '%s' "$part" | grep -Eq "${B}install${E}|${B}p?npm[[:space:]]+i${E}|${B}(yarn|pnpm|bun|uv|poetry)[[:space:]]+add${E}" \
    && ! printf '%s' "$part" | grep -Eq -- "$NOINSTALL"; then
    echo "$now [설치 명령] $part (위치: $cwd)" >> "$log"
  fi
done
exit 0
