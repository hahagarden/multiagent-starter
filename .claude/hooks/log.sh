#!/bin/sh
# 훅 로그 양식을 정의한다. 각 훅이 프로젝트 폴더로 이동한 뒤 source(.)로 불러온다.
# hook-log.txt: 실패와 막음 이벤트만 기록한다 (git 추적 대상)
# hook-run-log.txt: 모든 훅 실행을 기록한다 (git 제외 대상)

# run_log 이벤트 스크립트 결과 → "날짜 시간 [이벤트] 스크립트 결과"
run_log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2 $3" >> .claude/hook-run-log.txt; }

# fail_log 내용 → "날짜 시간 내용"
fail_log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> .claude/hook-log.txt; }
