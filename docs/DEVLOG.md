# ShellCue 개발 일지

## 2026-09-22

### 결정

- 제품명을 ShellCue로 확정했다.
- GitHub 연결 전에는 `docs/BACKLOG.md`를 로컬 작업 보드로 사용한다.
- Swift Package 안에 코어 라이브러리, 메뉴 막대 실행 파일, 테스트 타깃을 분리했다.

### 구현

- SwiftUI `MenuBarExtra` 기반 메뉴 막대 목록
- Terminal 탭 발견 어댑터
- iTerm2 세션 및 분할 pane 발견 어댑터
- Terminal/iTerm2 포커스 이동
- AppleScript 레코드 파서와 단위 테스트 초안

### 실환경 검증

- iTerm2에서 세션 ID, TTY, 세션 이름, 처리 상태, 프롬프트 상태를 읽었다.
- 읽은 iTerm2 세션 ID를 이용해 해당 세션으로 포커스 이동했다.
- Terminal을 테스트용으로 실행해 창 ID, TTY, busy 상태를 읽었다.
- 선택한 Terminal 탭으로 포커스한 뒤, 테스트 전 실행 중이 아니었던 Terminal을 종료했다.

### 장애물

- 설치된 Command Line Tools의 Swift 컴파일러는 6.3.3이고 SDK Swift 인터페이스는 6.3.2여서 전체 빌드가 실패한다.
- Xcode 전체 앱이 설치되어 있지 않다.
- 모든 Swift 파일의 구문 파싱은 통과했다. 타입 검사, 링크, 테스트 실행은 호환되는 Xcode 설치 후 다시 수행해야 한다.

### 다음 작업

1. 호환되는 Xcode 설치 후 `swift build`와 `swift test` 실행
2. 메뉴 막대 앱을 실행해 두 터미널의 동시 목록 표시 확인
3. zsh 이벤트 수집기 구현

