# ShellCue

터미널을 여러 개 열어두면 어느 창에서 무슨 일을 하던 중이었는지 헷갈린다. ShellCue는 Terminal과 iTerm2의 열린 세션을 메뉴 막대에 모아두고, 이름과 메모를 붙여 다시 찾아갈 수 있게 해주는 macOS 앱이다.

세션은 작업 폴더를 기준으로 묶인다. 목록에서 세션을 누르면 원래 탭이나 분할 화면으로 이동한다. 이름과 메모는 검색할 수 있고, 메모에는 줄바꿈과 이모지를 사용할 수 있다.

## 설치와 사용

macOS 14 이상에서 사용할 수 있다. ZIP에 들어 있는 앱은 빌드한 Mac과 같은 CPU 아키텍처를 지원한다.

1. ZIP을 풀고 `ShellCue.app`을 응용 프로그램 폴더로 옮긴다.
2. 앱을 실행하고 화면 위쪽 메뉴 막대에서 ShellCue 아이콘을 누른다. Dock 아이콘이나 별도 시작 창은 없다.
3. Terminal 또는 iTerm2에 세션을 열어둔다. 터미널 제어 권한을 요청하면 사용하는 앱의 접근을 허용한다.
4. 목록에서 세션으로 이동하거나, 편집 버튼으로 이름과 메모를 적는다. 저장 단축키는 `⌘S`다.

패널은 메뉴 막대 아이콘을 다시 누르면 닫힌다. 앱을 종료하려면 패널 오른쪽의 앱 메뉴에서 **ShellCue 종료**를 선택한다.

세션이 보이지 않고 권한 안내가 나온다면 시스템 설정의 **개인정보 보호 및 보안 → 자동화 → ShellCue**에서 해당 터미널의 접근을 확인한다.

배포 파일은 아직 임시 서명만 적용한 테스트용이다. Developer ID 서명과 Apple 공증은 되어 있지 않아, 인터넷에서 받은 앱은 macOS가 실행을 차단할 수 있다.

## 데이터

이름과 메모는 Mac 안의 다음 파일에 저장된다.

```text
~/Library/Application Support/ShellCue/session-annotations.json
```

계정이나 별도 셸 스크립트 설치는 필요하지 않다. 터미널 출력과 명령 이력을 저장하지 않는다. 표시되는 실행 중·입력 대기 상태는 작업의 성공이나 실패를 뜻하지 않는다.

## 개발

Swift 6.1 이상과 호환되는 Xcode가 필요하다. 저장소 폴더에서 실행한다.

```sh
swift build
swift test
swift run ShellCue
```

`swift run ShellCue`는 개발용 앱 번들을 만들어 실행한 뒤 반환한다. 터미널에 입력창이 돌아와도 앱은 메뉴 막대에서 계속 실행된다. 코드를 바꾼 뒤에는 ShellCue를 앱 메뉴에서 종료하고 다시 실행한다.

앱과 ZIP을 만들려면 다음 명령을 사용한다.

```sh
./scripts/package-app.sh
```

결과는 `dist/ShellCue.app`과 `dist/ShellCue-0.1.0-<아키텍처>.zip`에 생성된다.

터미널 연결만 확인하려면 실행 중인 ShellCue를 종료한 뒤 `swift run ShellCue --diagnose`를 실행한다. 결과는 빌드 폴더의 `shellcue-diagnostics.log`에 남는다.

작업할 때 지킬 기준은 [AGENTS.md](AGENTS.md), 다음에 할 일은 [BACKLOG.md](docs/BACKLOG.md)에 적는다.
