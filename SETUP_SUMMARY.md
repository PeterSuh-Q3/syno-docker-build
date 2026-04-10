# Synology Compiler 7.3 Docker Workflow - 설정 완료 요약

## 생성된 파일 구조

```
/Users/yousuk/
├── .github/
│   └── workflows/
│       └── build-syno-compiler-7.3.yml      ✅ GitHub Actions 워크플로우
├── Dockerfile                               ✅ Docker 이미지 정의
├── .dockerignore                            ✅ Docker 빌드 제외 파일
├── opt/
│   └── do.sh                                ✅ 컨테이너 엔트리포인트 (실행 권한 설정)
├── files/
│   └── .gitkeep                             ✅ 추가 파일 디렉토리 (선택사항)
├── scripts/
│   └── build-all-platforms.sh               ✅ 다중 플랫폼 빌드 스크립트
├── SYNOLOGY_COMPILER_WORKFLOW.md            ✅ 상세 문서
├── QUICKSTART.md                            ✅ 빠른 시작 가이드
└── SETUP_SUMMARY.md                         ✅ 이 파일
```

---

## 태그 전략 결정

분석 결과 스크립트에서 `dante90/syno-compiler:${TOOLKIT_VER}` 형식을 사용하므로:

```
태그: dante90/syno-compiler:7.3
  ↓
각 플랫폼별로 더 구체적인 태그를 추가:
  - dante90/syno-compiler:7.3-{platform}
  - dante90/syno-compiler:7.3 (기본, broadwell 가리킴)
  - dante90/syno-compiler:latest (선택)
```

**예시:**
```
dante90/syno-compiler:7.3-broadwell    ← 브로드웰용 컴파일러
dante90/syno-compiler:7.3-apollolake   ← 아폴로레이크용 컴파일러
dante90/syno-compiler:7.3              ← 기본값 (broadwell)
dante90/syno-compiler:latest           ← 최신 (broadwell)
```

---

## 필수 설정 단계

### 1️⃣ GitHub Secrets 등록

GitHub 저장소에 Docker Hub 인증 정보 등록:

```
Settings → Secrets and variables → Actions → New repository secret
```

필요한 Secrets:

| 이름 | 값 | 참고 |
|-----|-----|------|
| `DOCKER_USERNAME` | Docker Hub 사용자명 | 필수 |
| `DOCKER_PASSWORD` | Docker Hub Personal Access Token | 비밀번호 대신 토큰 권장 |

**Personal Access Token 생성:**
1. Docker Hub → Account Settings → Security
2. "New Access Token" 생성
3. Permissions: Read & Write
4. GitHub Secret에 저장

---

## 사용 방법

### 방법 1️⃣: GitHub 웹 인터페이스 (추천)

```
1. GitHub 저장소 → Actions 탭
2. "Build and Push Synology Compiler 7.3" 워크플로우 선택
3. "Run workflow" 클릭
4. Platform 선택 (예: broadwell)
5. push_latest 선택:
   - "none" → 플랫폼별 태그만 생성 (7.3-{platform})
   - "{platform}" → 7.3, latest 태그도 생성
6. "Run workflow" 클릭
```

### 방법 2️⃣: GitHub CLI

```bash
# broadwell 빌드 (latest 태그도 업데이트)
gh workflow run build-syno-compiler-7.3.yml \
  -f platform=broadwell \
  -f push_latest=broadwell

# apollolake 빌드 (플랫폼별 태그만)
gh workflow run build-syno-compiler-7.3.yml \
  -f platform=apollolake \
  -f push_latest=none
```

### 방법 3️⃣: 로컬 빌드 (테스트)

```bash
# 단일 플랫폼
docker build -t dante90/syno-compiler:7.3-broadwell \
  --build-arg PLATFORM=broadwell \
  --build-arg TOOLCHAIN_VERSION=7.3 .

# 모든 플랫폼 (로컬)
./scripts/build-all-platforms.sh

# 모든 플랫폼 (Docker Hub 푸시)
./scripts/build-all-platforms.sh true
```

---

## 워크플로우 동작 흐름

```
┌─────────────────────────────────────┐
│ 1. Checkout 저장소                  │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 2. Docker Buildx 설정               │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 3. Docker Hub 로그인                │
│    (DOCKER_USERNAME, DOCKER_PASSWORD)
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 4. Synology 아카이브에서 txz 다운로드 │
│    URL: https://archive.synology... │
│    File: {platform}-gcc1220...x86_64│
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 5. Toolchain 추출 → /opt            │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 6. Docker 이미지 빌드               │
│    ARG: PLATFORM, TOOLCHAIN_VERSION │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 7. Docker Hub에 푸시                │
│    Tag: 7.3-{platform}              │
│    Tag: 7.3 (선택)                  │
│    Tag: latest (선택)               │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 8. 빌드 요약 생성 (artifact)        │
└─────────────────────────────────────┘
```

---

## 주요 파일 설명

### 🔧 `.github/workflows/build-syno-compiler-7.3.yml`
- GitHub Actions 워크플로우 정의
- workflow_dispatch로 수동 실행 지원
- 플랫폼 선택, Docker 빌드, Hub 푸시

### 📦 `Dockerfile`
- debian:11-slim 기반
- 툴체인 설치 및 환경 설정
- ENTRYPOINT: `/opt/do.sh`
- VOLUME: `/input`, `/output`

### 🔗 `opt/do.sh`
- 컨테이너 엔트리포인트 스크립트
- `compile-module {platform}` 지원
- `shell` 대화형 모드 지원
- 실제 컴파일 로직은 프로젝트에 맞게 커스터마이즈 필요

### ⚡ `scripts/build-all-platforms.sh`
- 19개 플랫폼을 한 번에 빌드
- 로컬 또는 Docker Hub 푸시
- 빌드 성공/실패 요약 출력
- `./scripts/build-all-platforms.sh [push]`

---

## 지원 플랫폼 (x86_64)

| 플랫폼 | CPU | 예시 |
|--------|-----|------|
| apollolake | Intel Atom | |
| avoton | Intel Atom | |
| braswell | Intel Pentium | |
| **broadwell** | Intel Core i7 | ⭐ 권장 기본값 |
| broadwellnk | Intel Core | |
| broadwellnkv2 | Intel Core | |
| broadwellntbap | Intel Core | |
| bromolow | Intel Pentium | |
| denverton | Intel Atom | |
| epyc7002 | AMD EPYC | |
| geminilake | Intel Celeron | |
| geminilakenk | Intel Celeron | |
| grantley | Intel Xeon | |
| kvmx64 | QEMU/KVM | |
| purley | Intel Xeon | |
| r1000 | AMD Ryzen | |
| r1000nk | AMD Ryzen | |
| v1000 | AMD Radeon | |
| v1000nk | AMD Radeon | |

---

## 사용 예제

### Docker 이미지 실행

```bash
# 모듈 컴파일 (broadwell)
docker run -u $(id -u) --rm -t \
  -v "/path/to/source:/input" \
  -v "/path/to/output:/output" \
  dante90/syno-compiler:7.3-broadwell \
  compile-module broadwell

# 최신 버전 사용 (broadwell)
docker run -u $(id -u) --rm -t \
  -v "/path/to/source:/input" \
  -v "/path/to/output:/output" \
  dante90/syno-compiler:7.3 \
  compile-module broadwell

# 대화형 쉘
docker run --rm -it \
  -v "/path/to/work:/input" \
  dante90/syno-compiler:7.3-apollolake \
  shell
```

---

## 빌드 후 확인

### Docker Hub에서 확인

```
https://hub.docker.com/r/dante90/syno-compiler/tags
```

### 로컬에서 확인

```bash
# 이미지 확인
docker images | grep syno-compiler

# 이미지 정보
docker inspect dante90/syno-compiler:7.3-broadwell
```

### GitHub Actions 로그

```
GitHub 저장소 → Actions → 워크플로우 → 해당 실행 선택
```

---

## 문제 해결

### ❌ Docker Hub 로그인 실패

```
Error response from daemon: unauthorized: authentication required
```

**원인:** Secrets 설정 오류

**해결:**
```bash
# 1. GitHub Secrets 재확인
#    - DOCKER_USERNAME: 정확한 사용자명
#    - DOCKER_PASSWORD: 유효한 토큰
#    - 비밀번호 아닌 Personal Access Token 사용

# 2. Docker Hub에서 직접 테스트
docker login
# 대화형으로 토큰 입력하여 확인
```

### ❌ Toolchain 다운로드 실패

```
Failed to download toolchain
```

**해결:**
```bash
# 1. URL 유효성 확인
curl -I "https://archive.synology.com/download/ToolChain/toolchain/7.3-86009"

# 2. 플랫폼명 확인 (대소문자 구분)
# 3. 네트워크 연결 확인
```

### ❌ Docker 빌드 실패

**해결:**
```bash
# 로컬에서 빌드 테스트
docker build -t test:latest \
  --build-arg PLATFORM=broadwell \
  --build-arg TOOLCHAIN_VERSION=7.3 .

# 에러 메시지 상세 확인
docker build --verbose ... 2>&1 | tee build.log
```

---

## 다음 단계

1. **GitHub Secrets 설정**: DOCKER_USERNAME, DOCKER_PASSWORD 추가
2. **워크플로우 테스트**: broadwell 플랫폼으로 첫 빌드 실행
3. **entrypoint 커스터마이즈**: `/opt/do.sh` 실제 컴파일 로직 구현
4. **다중 플랫폼 빌드**: `./scripts/build-all-platforms.sh` 활용 또는 워크플로우 매트릭스 설정

---

## 참고 자료

- 📖 **상세 문서**: `SYNOLOGY_COMPILER_WORKFLOW.md`
- 🚀 **빠른 시작**: `QUICKSTART.md`
- 🔗 **Synology 아카이브**: https://archive.synology.com/download/ToolChain/
- 🐳 **Docker Hub 저장소**: https://hub.docker.com/r/dante90/syno-compiler

---

## 체크리스트

- [ ] GitHub Secrets 설정 완료 (DOCKER_USERNAME, DOCKER_PASSWORD)
- [ ] 워크플로우 파일 `.github/workflows/build-syno-compiler-7.3.yml` 확인
- [ ] Dockerfile 확인 및 필요시 커스터마이즈
- [ ] `/opt/do.sh` 커스터마이즈 (실제 컴파일 로직)
- [ ] 첫 번째 빌드 테스트 (GitHub Actions)
- [ ] Docker Hub 태그 확인
- [ ] 사용 설명서 문서화

---

**생성 일시**: 2026-04-10
**버전**: 1.0
