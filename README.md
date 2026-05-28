# Codex Update Companion

macOS 14+용 비공식 Codex 업데이트 메뉴바 앱입니다. Codex 앱 실행 여부와 설치 버전을 확인하고, 공식 OpenAI Codex changelog, Codex Mac 앱 업데이트 피드, 공개 GitHub `openai/codex` releases를 메뉴바 팝오버에서 보여줍니다.

## 주요 기능

- `NSStatusItem` 기반 메뉴바 앱
- Dock 아이콘 기본 숨김
- `NSWorkspace`로 Codex 앱 실행/종료 감지
- Codex Mac 앱 배포 버전과 최신 앱 업데이트 피드 비교
- GitHub 공개 Releases API 조회
- OpenAI Codex changelog 항목 수집 및 앱/CLI/IDE/GitHub/모델/플러그인/보안 영역 분류
- 릴리즈 카드: 버전, 날짜, 제목, 규칙 기반 한글 요약, 중요도, 원문 링크
- 상세보기 창: 풀어쓴 한글 설명, 사용자 영향, 주의할 점, 원문 릴리즈 노트
- 로컬 JSON 캐시 저장 및 재실행 후 유지
- 읽음/읽지 않음 처리
- 새 릴리즈 알림 토글
- 로그인 시 자동 실행 토글
- 네트워크 실패 시 크래시 없이 에러/빈 상태 표시

## 빌드

터미널:

```bash
swift build
```

Xcode:

1. Xcode에서 `Package.swift`를 연다.
2. `CodexUpdateCompanion` scheme을 선택한다.
3. macOS 대상으로 Build 또는 Run을 실행한다.

## 실행

개발용 앱 번들을 만들고 실행하려면:

```bash
./script/build_and_run.sh
```

검증 실행:

```bash
./script/build_and_run.sh --verify
```

CI용 번들 구조 검증:

```bash
./script/build_and_run.sh --verify-bundle
```

로그 확인:

```bash
./script/build_and_run.sh --logs
```

빌드 결과 앱 번들은 `dist/Codex Update Companion.app`에 생성됩니다.

## 스크립트 구분

- `script/build_and_run.sh`: 개발용. 디버그 번들을 만들고 실행/로그/검증을 수행합니다.
- `script/build_bundle.sh`: 디버그 또는 릴리즈 앱 번들만 생성합니다.
- `script/verify_bundle.sh`: 앱 번들 구조를 검증합니다. `--strict-signing`을 붙이면 서명/Gatekeeper 검증도 수행합니다.
- `script/package_dmg.sh`: 앱 번들을 DMG로 패키징합니다. `hdiutil`을 사용하므로 샌드박스나 CI 환경에서는 실패할 수 있고, 실제 배포 전에는 로컬 macOS 서명 환경에서 한 번 검증해야 합니다.
- `script/notarize.sh`: notarization 제출과 stapling을 수행합니다.

## CI

`.github/workflows/release-gate.yml`은 `main` push와 PR마다 다음을 실행합니다.

```bash
swift build
swift test
./script/build_bundle.sh debug
./script/verify_bundle.sh "dist/Codex Update Companion.app"
```

## 데이터와 권한

이 앱은 다음을 하지 않습니다.

- OpenAI 로그인 정보 요청
- GitHub personal access token 요청
- Codex 앱 내부 파일 읽기/수정
- 사용자 프로젝트 폴더 스캔
- Accessibility 권한 요청
- Screen Recording 권한 요청

이 앱은 다음만 사용합니다.

- 실행 중인 앱 목록에서 Codex 앱 여부 확인
- `https://api.github.com/repos/openai/codex/releases?per_page=20` 공개 API 조회
- `https://developers.openai.com/codex/changelog` 공식 changelog 조회
- `https://persistent.oaistatic.com/codex-app-prod/appcast.xml` Codex Mac 앱 업데이트 피드 조회
- CLI 버전 확인을 위해 `/usr/bin/env codex --version` 실행. 이 실행은 3초 timeout이 적용됩니다.
- Application Support 아래 로컬 JSON 캐시 저장
- 사용자가 켠 경우 macOS 알림

## 배포

이 저장소는 MIT 라이선스로 공개됩니다. 배포 파일은 GitHub Releases에서 notarized DMG로 제공합니다.

현재 베타 릴리즈:

- `v0.1.0-beta.1`
- 배포 파일: `CodexUpdateCompanion.dmg`
- SHA-256: `e4a1ae5a8683f9e978d1b5620f7a7f889fc75e9feb5895c3a17ebc3c22deab13`
- Apple notarization: Accepted
- Stapling: 완료

## 직접 배포 체크리스트

초기 베타 릴리즈 노트 초안은 `docs/releases/v0.1.0-beta.1.md`에 있습니다.

1. Apple Developer Program 계정 준비
2. Developer ID Application 인증서로 서명
3. Hardened Runtime 활성화
4. 앱 번들 notarization
5. DMG 패키징
6. README와 Privacy Policy 포함

예시 흐름:

```bash
./script/build_bundle.sh release
./script/verify_bundle.sh "dist/Codex Update Companion.app"
codesign --force --deep --options runtime --sign "Developer ID Application: <Team>" "dist/Codex Update Companion.app"
./script/verify_bundle.sh "dist/Codex Update Companion.app" --strict-signing
./script/package_dmg.sh
./script/notarize.sh "dist/CodexUpdateCompanion.dmg" "<profile>"
```

## 고지

Unofficial companion app. Not affiliated with OpenAI.

## License

MIT. See `LICENSE`.
