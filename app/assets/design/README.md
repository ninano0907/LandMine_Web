# 황금의 철마 디자인

- `frontier-art-direction-v1.png`: 이미지 생성 도구로 제작한 디자인 원화. 실제 실행 화면이 아닙니다.
- `frontier-art-direction-v1.prompt.md`: 원화 생성에 사용한 최종 프롬프트.
- `frontier-preview.png`: 최신 게임의 실행 렌더링.
- `frontier-gold-seam.png`: 지면 금맥과 위로 퍼지는 광선 디자인.
- `frontier-robot-preview.png`: 실제 3D 모델의 채굴 동작 한 프레임.
- `frontier-rescue-camp.png`: 구출 캠프와 공격 예고의 실행 렌더링.
- `robot-walk-v1.gif`, `robot-mining-v1.gif`: 실제 모델의 동작 미리보기.

미리보기 이미지는 런타임 번들에 넣지 않습니다. 실제 모델은 `../models/`에 있으며, 현재는 생성 원화의 완성도와 구별되는 동작 검증용 3D 모델입니다.

## 거미 기지 채굴 동작 v2

- `robot-mining-v2.gif`, `robot-mining-v2.mp4`: 6초 / 24fps 채굴 동작 미리보기.
- 지면 굴착 → 버킷 말아 담기 → 들어 올리기 → 벨트로 회전 → 광석 쏟기 → 복귀.
- 드릴 회전·미세 이송, 굴삭기 유압 실린더, 버킷 안 광석과 낙하 광석, 벨트 가로대·롤러·광석, 지면 파편과 증기를 함께 움직입니다.
- 다리는 채굴 중 지면에 고정됩니다. 별도 보행 클립은 기존 8족 보행을 유지합니다.
- 실제 동작은 `../models/frontier_robot.glb`와 `.scene.json`에 저장됩니다. 게임 본부는 `frontier_robot_motion_v2.png` 아틀라스로 동일한 동작을 재생합니다. `frontier_robot_motion_v2.json`은 모든 포즈가 프레임 안에 들어가도록 측정한 접지 기준점과 프레임 정보를 담습니다.
- 게임의 **로봇 동작** 버튼에서 회전 가능한 3D 모델을 확인할 수 있습니다.

이 파일은 절차적으로 만든 동작 검증용 3D 모델의 렌더입니다. 생성 원화 `frontier-western-spider-base-v2.png`의 완성된 외형을 그대로 리깅한 결과는 아닙니다.

재생성:

```sh
python3 scripts/build_frontier_robot.py
python3 scripts/check_robot_model.py
cd app
flutter test tool/render_robot_motion.dart
```

GIF/MP4는 `/private/tmp/frontier-spider-motion-v2/mine-%03d.png`의 144장을 24fps로 인코딩한 것입니다. 이미지 생성 도구로 만든 정지 이미지를 흔드는 방식이 아니라 실제 관절 모델을 렌더링했습니다.

## 원화 기반 기지 v3 — 이전 시점

v2의 단순한 3D 모델 대신 승인한 원화 `frontier-western-spider-base-v2.png`를 참조해 만든 고해상도 투명 이미지를 관절로 조립합니다.

- `frontier-spider-rig-v3-preview.png`: 실제 조립 렌더링.
- `robot-mining-v3.mp4`, `robot-mining-v3.gif`: 실제 리그를 렌더링한 6초 채굴 루프.
- `frontier-spider-v3.prompt.md`: 내장 image_gen 도구에 사용한 두 생성 프롬프트.
- `../models/frontier_spider_chassis_v3.png`: 기지 본체와 지지 다리.
- `../models/frontier_spider_parts_v3.png`: 붐·스틱·버킷·드릴·컨베이어·광석의 3×2 아틀라스.
- `../../lib/frontier/spider_rig.dart`: 본체는 유지하고 굴삭기 관절, 버킷 적재/투입, 벨트 위 광석과 가로대, 드릴 이송/반사광, 증기·파편을 따로 그리는 리그.

현재 방식은 원화 재질을 보존하는 2D 관절 애니메이션입니다. 자유 회전하는 3D 모델이 아닙니다. 채굴 중 다리는 지면에 고정되며, 새 이미지의 개별 다리 보행 리깅은 포함하지 않습니다. 드릴 회전감은 원화 위에서 움직이는 반사광으로 표현합니다.

게임의 `로봇 동작` 화면은 v3를 표시하며 두 손가락 확대를 지원합니다. v2 GLB와 아틀라스는 과거 동작 검증용으로 보관합니다.

미리보기 재생성: `cd app && flutter test tool/render_spider_rig.dart --no-pub`


## 높은 카메라 / 안쪽 채집 v4 — 현재 게임 적용본

- 기지 본체와 6종 작업 부품을 모두 더 높은 사선 카메라 시점으로 재생성했습니다. 지붕·보일러 윗면·발판 상부가 더 잘 보이는 방향입니다.
- 버킷의 입구와 이빨은 화면 오른쪽, 즉 왼쪽 작업 공간에서 기지 안쪽을 향합니다. 굴착 뒤 기지 쪽으로 당기는 경로와 버킷 말아 올리기, 벨트 투입 각도를 함께 바꿨습니다.
- 새 그림의 장착 소켓에 맞춰 어깨·팔꿈치·버킷 핀과 벨트의 접점을 재배치했습니다. 붐 270 / 스틱 250의 링크 길이는 전체 루프에서 일정합니다.
- `frontier-spider-rig-v4-preview.png`: 현재 리그의 조립 화면.
- `robot-mining-v4.mp4`, `robot-mining-v4.gif`: 현재 6초 루프 미리보기.
- `frontier-spider-v4.prompt.md`: 내장 image_gen 편집 프롬프트.
- `../models/frontier_spider_chassis_v4.png`, `../models/frontier_spider_parts_v4.png`: 현재 런타임 에셋.
- `flutter test tool/render_spider_rig.dart --no-pub`는 `/private/tmp/frontier-spider-v4/`에 프레임을 출력합니다.
