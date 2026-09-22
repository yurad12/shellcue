# ShellCue 로컬 백로그

GitHub Issues를 사용하기 전까지 이 문서를 로컬 작업 보드로 사용한다. 한 번에 `진행 중` 작업은 하나만 둔다.

## 진행 중

- `SPIKE-001` Terminal과 iTerm2 세션을 읽어 메뉴 막대 목록에 표시
  - Terminal 메타데이터 읽기와 포커스 이동 검증 완료
  - iTerm2 메타데이터 읽기와 포커스 이동 검증 완료
  - SwiftUI 목록 구현 완료
  - 호환 Xcode 설치 후 전체 빌드·실행 확인 필요

## 다음

- `SPIKE-003` zsh의 명령 시작·종료·경로 이벤트 수집
- `SPIKE-004` TTY, 셸 PID, 세션 ID를 이용한 세션 재연결
- `APP-002` 용도 이름과 다음 할 일 저장

## 나중

- 프로젝트 자동 그룹
- 안전한 최근 명령 요약
- 최근 닫힌 세션
- 온보딩과 zsh 연동 설치·제거
- 서명·공증·DMG 배포

## 완료

- 제품명 ShellCue 확정
- 제품 기획서 작성
- MVP 개발 계획 작성
- Swift Package와 메뉴 막대 앱 골격 작성
- Terminal/iTerm2 어댑터 초안 작성
- Terminal/iTerm2 AppleScript 발견·포커스 실환경 검증

## 현재 장애물

- 현재 Command Line Tools의 Swift 컴파일러는 6.3.3, SDK Swift 인터페이스는 6.3.2라 전체 빌드가 실패한다.
- Xcode 전체 앱이 설치되어 있지 않다. 호환되는 Xcode 또는 Command Line Tools 설치 후 빌드·테스트를 다시 실행해야 한다.
