# 멍냥서바이벌 (Godot 4.5 · Compatibility)

탑다운 PvE 익스트랙션 슈터 — 기획서 6장 "2주 수직 슬라이스" 구현.

## 실행
Godot 4.5에서 `project.godot` 열기 → F5. (첫 실행 때 에셋 가져오기로 몇 초 걸림)

## 조작
WASD 이동 · 마우스 조준 · 좌클릭 사격 · R 재장전 · Space 구르기(무적) · Shift 달리기
V 근접(뒤에서 치면 암습 2.5배) · E 뒤지기/상호작용 · Tab 배낭 · Q 회복 · M 지도 · 1/2 무기 · Esc 일시정지
배낭: 끌어서 이동 · R 회전 · 우클릭 사용 · 상자 쪽으로 끌면 놓고 감 · 바깥에 놓으면 버림 · F 모두 가져가기

## 폴더 구조
- `scripts/data/db.gd` — 아이템·무기·적·상자·레시피·상점 수치 (밸런스는 여기만 고치면 됨)
- `scripts/raid/level_data.gd` — 맵 (문자 지도, 기호 설명 포함)
- `scripts/art/art.gd` — 캐릭터·아이템을 코드로 그리는 곳. 직접 만든 에셋으로 바꿀 때 이 함수 호출부만 교체
- `scripts/raid/` — 원정(플레이어, 적 AI, 탄환, 상자, 발전기, 탈출구, 이펙트)
- `scripts/ui/` — HUD, 배낭, 은신처, 결과, 타이틀
- `assets/sfx/` — 효과음·배경음 (직접 합성, 저작권 문제 없음) · 같은 이름의 wav로 덮어쓰면 교체됨
- `assets/fonts/` — Noto Sans KR (SIL OFL, 상업 이용 가능 · 라이선스 파일 동봉)

## 스팀 배포 준비
1. 에디터 → 편집기 → 내보내기 템플릿 관리 → 다운로드 및 설치
2. 프로젝트 → 내보내기 → "Windows Desktop" 프리셋 → 프로젝트 내보내기 (`build/windows/`)
3. Steamworks 파트너 가입(앱 등록비 $100) → 스토어 페이지 · SteamPipe로 빌드 업로드
4. 업적·클라우드 저장이 필요하면 GodotSteam 애드온 추가

저장 파일: `%APPDATA%/Godot/app_userdata/멍냥서바이벌/save.json`
