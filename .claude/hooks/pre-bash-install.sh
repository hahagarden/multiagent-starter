#!/bin/sh
# Bash 명령 실행 직전에 검사한다. 설치 명령이 포함되면 해당 명령만 danger-log.txt에 기록하고, 실행은 막지 않는다.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
. .claude/hooks/log.sh
log=.claude/danger-log.txt
now=$(date '+%Y-%m-%d %H:%M:%S')

# stdin JSON에서 tool_input.command 값과 작업 디렉터리(cwd)를 추출한다. 줄바꿈(\n)은 ;로 치환한다.
input=$(cat)
cmd=$(printf '%s' "$input" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | sed -e 's/\\n/; /g' -e 's/\\"/"/g')
cwd=$(printf '%s' "$input" | sed -nE 's/.*"cwd"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p')
cwd=${cwd:-$(pwd)}
case "$cwd" in "$HOME"*) cwd="~${cwd#"$HOME"}" ;; esac

# 정보 조회 옵션(--help 등)이 붙은 명령은 기록하지 않는다.
NOINSTALL='(^|[[:space:]])(--help|-h|--version|--dry-run)([[:space:]=]|$)'

B='(^|[^[:alnum:]_.-])'   # 단어 경계(앞)
E='([^[:alnum:]_.-]|$)'   # 단어 경계(뒤)

# curl/wget 출력을 sh/bash로 파이프하는 명령은 파이프라인 전체를 기록한다.
printf '%s' "$cmd" | grep -oE "${B}(curl|wget)[[:space:]][^;&|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)${E}" \
  | sed -E 's/^[^[:alnum:]_.\/-]//; s/[[:space:]]*$//' | while IFS= read -r part; do
  echo "$now [설치 명령] $part (위치: $cwd)" >> "$log"
done

# 그 외 명령은 ; && || | 기준으로 분리하고, 설치 명령이 포함된 명령 단위만 기록한다.
printf '%s\n' "$cmd" | awk '{ gsub(/[[:space:]]*(&&|\|\||;|\|)[[:space:]]*/, "\n"); print }' | while IFS= read -r part; do
  if printf '%s' "$part" | grep -Eq "${B}install${E}|${B}p?npm[[:space:]]+i${E}|${B}(yarn|pnpm|bun|uv|poetry)[[:space:]]+add${E}" \
    && ! printf '%s' "$part" | grep -Eq -- "$NOINSTALL"; then
    echo "$now [설치 명령] $part (위치: $cwd)" >> "$log"
  fi
done
run_log PreToolUse pre-bash-install.sh 통과
exit 0
