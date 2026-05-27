# Codex Update Companion

macOS 14+용 비공식 Codex 업데이트 메뉴바 앱입니다. Codex 앱 실행 여부를 감지하고, 공개 GitHub `openai/codex` releases와 공식 OpenAI Codex changelog 링크를 메뉴바 팝오버에서 보여줍니다.

## 주요 기능

- `NSStatusItem` 기반 메뉴바 앱
- Dock 아이콘 기본 숨김
- `NSWorkspace`로 Codex 앱 실행/종료 감지
- GitHub 공개 Releases API 조회
- OpenAI Codex changelog 링크 표시
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

로그 확인:

```bash
./script/build_and_run.sh --logs
```

빌드 결과 앱 번들은 `dist/Codex Update Companion.app`에 생성됩니다.

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
- `https://developers.openai.com/codex/changelog` 링크 열기
- Application Support 아래 로컬 JSON 캐시 저장
- 사용자가 켠 경우 macOS 알림

## 직접 배포 체크리스트

1. Apple Developer Program 계정 준비
2. Developer ID Application 인증서로 서명
3. Hardened Runtime 활성화
4. 앱 번들 notarization
5. DMG 패키징
6. README와 Privacy Policy 포함

예시 흐름:

```bash
./script/build_and_run.sh --verify
codesign --force --deep --options runtime --sign "Developer ID Application: <Team>" "dist/Codex Update Companion.app"
ditto -c -k --keepParent "dist/Codex Update Companion.app" "dist/CodexUpdateCompanion.zip"
xcrun notarytool submit "dist/CodexUpdateCompanion.zip" --keychain-profile "<profile>" --wait
xcrun stapler staple "dist/Codex Update Companion.app"
```

## 고지

Unofficial companion app. Not affiliated with OpenAI.
