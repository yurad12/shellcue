# ShellCue

ShellCue는 macOS Terminal과 iTerm2에서 열어둔 작업의 용도, 상태, 다음 할 일을 한곳에서 기억하는 메뉴 막대 앱이다.

## 현재 상태

기술 스파이크 단계다. SwiftUI 메뉴 막대 앱, Terminal 어댑터, iTerm2 어댑터의 초안이 구현되어 있다. 현재 개발 Mac의 Command Line Tools 컴파일러와 SDK 버전이 일치하지 않아 전체 빌드 검증은 보류 중이다.

## 문서

- [제품 기획서](docs/PRODUCT_SPEC.md)
- [개발 계획](docs/DEVELOPMENT_PLAN.md)
- [로컬 백로그](docs/BACKLOG.md)
- [개발 일지](docs/DEVLOG.md)
- [기술 결정 기록](docs/decisions/0001-terminal-independent-architecture.md)

## 로컬 개발

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
