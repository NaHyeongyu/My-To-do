# One

SwiftUI와 SwiftData로 만든 개인용 루틴/할 일 관리 앱입니다. 하단 탭으로 오늘, 주간, 월간, 기록 화면을 전환하고 루틴 실행량을 추적합니다.

## Features

- SwiftData 로컬 저장
- 오늘/주간/월간/기록 하단 탭
- 오늘 루틴 가로 타임테이블
- 루틴 시작 시간, 종료 시간, 반복 날짜 설정
- 오늘 단발성 할 일 빠른 추가
- 루틴 실행 완료 기록
- 주간/월간 예정 시간 대비 실제 실행량 대시보드
- 연속 루틴 완료 streak 표시
- 할 일 완료, 편집, 삭제
- iPhone 중심 SwiftUI 화면

## Run

```sh
open One.xcodeproj
```

Xcode에서 `One` 스킴을 선택하고 iOS 시뮬레이터 또는 실기기로 실행하면 됩니다.

## Local Build

```sh
scripts/build_latest.sh
```

로컬 빌드는 위 스크립트를 사용합니다. 빌드를 임시 위치에 먼저 만든 뒤 성공하면 `build/DerivedData`만 최신 빌드로 유지하고, 이전 `.build`, `DerivedData`, 오래된 `build` 산출물은 자동으로 삭제합니다.
