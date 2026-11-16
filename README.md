# 광맥 PWA

상위 LandMine Flutter + Flame 게임을 웹으로 옮긴 프로젝트입니다. 원본 앱은 수정하지 않습니다.

- 게임 소스: `app/lib/`
- 웹 설치, 탐지음, 로딩 화면: `app/web/`
- 배포 주소: https://ninano0907.github.io/LandMine_Web/
- `main` 루트에 빌드 결과를 함께 커밋합니다. 기존 Pages의 브랜치 배포를 그대로 사용합니다. GitHub Actions는 소스 검사·테스트·재빌드 결과를 별도로 보관합니다.
- Pages 설정은 **Deploy from a branch → main → / (root)** 입니다.

## 개발과 빌드

Flutter 3.38.9 / Dart 3.10 이상.

```sh
cd app
flutter pub get
flutter run -d chrome
```

저장소 루트에서 `bash scripts/build.sh`로 배포 파일을 만듭니다. `/LandMine_Web/` 경로에 맞춰 빌드하며 렌더러를 포함해 오프라인 자산을 미리 저장합니다. 다른 저장소 이름을 사용하면 스크립트의 base-href를 변경합니다.

## 조작과 설치

탐사인 구매 → 광맥 발견·채굴 → 공장과 갱도를 레일로 연결 → 수레 운반·정련 → 중개인에게 금 판매.

- 터치: 기존 게임과 같은 탭·레일 드래그, 두 손가락 지도 이동·확대.
- PC: 휠 확대·축소, 오른쪽/가운데 버튼 또는 스페이스를 누른 채 드래그로 지도 이동. 미니맵 클릭도 가능합니다.
- Android/PC: 지원 브라우저에서 ‘앱 설치’ 버튼 또는 브라우저 설치 메뉴.
- iPhone/iPad: Safari의 공유 → 홈 화면에 추가. 가로 화면 권장.
- 처음 온라인으로 로딩과 캐시 저장을 마치면 오프라인 실행 가능. 업데이트는 앱을 닫았다 다시 열어 반영합니다.
- 탐지음은 화면을 한 번 누른 뒤 재생됩니다. 진행과 해금은 원본처럼 실행 세션 동안만 유지됩니다.

## 검증

```sh
cd app
dart analyze lib test tool
flutter test
dart tool/check_mining.dart
```

## RTS 브랜치 PWA 테스트

`feature/rts-starcraft-style` 브랜치를 푸시하면 RTS 맵 테스트와 웹 빌드 후
`https://ninano0907.github.io/LandMine_Web/rts/`에 미리보기를 배포합니다.
GitHub Actions의 `Deploy RTS preview` 작업 완료 후 접속하세요.

지원 브라우저의 앱 설치 또는 Safari의 공유 → 홈 화면에 추가로 설치합니다.
첫 온라인 실행에서 오프라인 캐시 저장을 마친 후 오프라인 실행이 가능합니다.
RTS 캐시는 기존 광산 게임과 별도로 관리됩니다. 업데이트 후 앱을 완전히 닫고 다시 열어 주세요.
화면 왼쪽 위 빌드 번호로 버전을 확인할 수 있습니다.
