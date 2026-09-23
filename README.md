# ShellCue

ShellCue는 macOS Terminal과 iTerm2에서 열어둔 작업의 용도, 상태, 다음 할 일을 한곳에서 기억하는 메뉴 막대 앱이다.

## 현재 상태

SwiftUI 메뉴 막대에서 Terminal과 iTerm2 세션을 프로젝트별로 모아 보고, 상태를 확인하고, 원래 세션으로 이동할 수 있다. 세션별 용도 이름과 다음 할 일을 로컬에 저장한다.

## 문서

- [제품 기획서](docs/PRODUCT_SPEC.md)
- [개발 계획](docs/DEVELOPMENT_PLAN.md)
- [로컬 백로그](docs/BACKLOG.md)
- [개발 일지](docs/DEVLOG.md)
- [기술 결정 기록](docs/decisions/0001-terminal-independent-architecture.md)

## 로컬 개발

설치용 로컬 테스트 앱과 ZIP 생성:

```sh
bash scripts/package-app.sh
```

`dist/ShellCue.app`을 응용 프로그램 폴더로 복사해 실행한다. 기존 `swift run` 프로세스는 먼저 종료한다. 우측 앱 메뉴에서 ShellCue를 종료할 수 있다. ZIP 파일은 `dist/`에 생성되며 빌드한 Mac의 CPU 아키텍처만 지원한다. macOS 14 이상이 필요하다. 현재 패키지는 로컬 임시 서명만 적용하며 Developer ID 서명·Apple 공증과 커스텀 앱 아이콘은 포함하지 않는다. 다운로드한 Mac에서는 Gatekeeper가 실행을 차단할 수 있다.

요구 사항:

- macOS 14 이상
- 호환되는 최신 Xcode
- Swift 6

```sh
swift build
swift test
swift run ShellCue
```

첫 실행 시 Terminal과 iTerm2를 제어하기 위한 macOS 자동화 권한을 요청할 수 있다.

세션 이름과 다음 할 일은 `~/Library/Application Support/ShellCue/session-annotations.json`에만 저장된다.
