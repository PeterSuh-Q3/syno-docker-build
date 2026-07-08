# Synology Compiler Docker Image

GitHub Actions 워크플로우를 통해 Synology 툴체인을 Docker Hub에 자동으로 빌드 및 푸시합니다.
DSM 7.1 / 7.2 / 7.3 을 워크플로우 실행 시 선택할 수 있습니다.

## 파일 구조

```
.
├── .github/workflows/
│   ├── build-parallel.yml          # DSM 7.x GitHub Actions 워크플로우
│   └── build-6.2.yml               # DSM 6.2 전용 워크플로우
├── build-parallel.sh               # 병렬 빌드 스크립트 (DSM 7.x, 메인)
├── build-parallel-62.sh            # 병렬 빌드 스크립트 (DSM 6.2, SourceForge 소스)
├── Dockerfile.template             # Dockerfile 템플릿 (prepare 시 Dockerfile 로 생성됨)
├── files/                          # 컨테이너 루트로 복사되는 파일
│   ├── opt/do.sh                   #   컨테이너 엔트리포인트 스크립트
│   └── etc/profile.d/login.sh      #   로그인 셸 초기화
└── cache/                          # 다운로드된 툴체인 캐시 디렉토리
```

> `Dockerfile` 은 `build-parallel.sh ... prepare` 실행 시 `Dockerfile.template` 에서
> 생성됩니다. 빌드 범위(전체/단일 플랫폼)에 따라 포함 플랫폼이 자동으로 결정됩니다.

## 필수 요구사항

### GitHub Secrets 설정

워크플로우가 Docker Hub에 푸시하기 위해 다음 Secrets를 GitHub 저장소에 설정해야 합니다:

```
DOCKER_USERNAME  → Docker Hub 사용자명
DOCKER_PASSWORD  → Docker Hub 비밀번호 또는 Personal Access Token
```

**설정 방법:**
1. GitHub 저장소 → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. Name과 Secret 값 입력

## 워크플로우 사용 방법

### GitHub Actions (Workflow Dispatch)

GitHub 웹 인터페이스에서:

```
Repository → Actions → "Build and Push Synology Compiler (Performance Optimized)"
→ Run workflow 클릭
→ DSM Version, Push to Hub, Also tag latest 선택
```

각 실행은 해당 DSM 버전의 **전 플랫폼을 담은 단일 이미지** `dante90/syno-compiler:{dsm}` 를 게시합니다.

또는 GitHub CLI:

```bash
# DSM 7.3 빌드 → dante90/syno-compiler:7.3
gh workflow run build-parallel.yml -f dsm_version=7.3 -f push_to_hub=true

# DSM 7.4 빌드 (+ latest 갱신) → dante90/syno-compiler:7.4 (+ :latest)
gh workflow run build-parallel.yml -f dsm_version=7.4 -f push_to_hub=true -f tag_latest=true

# DSM 6.2 (별도 워크플로우)
gh workflow run build-6.2.yml -f push_to_hub=true
```

### 워크플로우 입력 옵션

| 입력 | 설명 | 기본값 | 옵션 |
|------|------|--------|------|
| `dsm_version` | DSM 버전 | `7.3` | `7.0`, `7.1`, `7.2`, `7.3`, `7.4` |
| `push_to_hub` | Docker Hub 푸시 여부 | `true` | `true`, `false` |
| `tag_latest` | `:latest` 태그도 갱신 | `false` | `true`, `false` |

### 로컬 CLI 사용법

```bash
# DSM 7.3 전체 빌드 → dante90/syno-compiler:7.3 (기본값)
./build-parallel.sh 7.3 all

# 다운로드(준비)만
./build-parallel.sh 7.2 prepare

# 플랫폼 목록 JSON 출력
./build-parallel.sh 7.3 platforms

# 단일 플랫폼 로컬 테스트 이미지 (게시용 아님) → :7.1-broadwell
./build-parallel.sh 7.1 build broadwell

# 환경변수로 DSM 버전 전달
DSM_VERSION=7.2 ./build-parallel.sh all
```

> 로컬 실행에는 bash 4+ 가 필요합니다 (macOS 기본 bash 3.2 불가 → `brew install bash`).

## DSM 버전별 플랫폼

### DSM 7.1 (9개 플랫폼, Toolchain 7.1-42661, gcc850/glibc226)

| 플랫폼 | 커널 버전 |
|--------|-----------|
| apollolake | 4.4.180 |
| broadwell | 4.4.180 |
| broadwellnk | 4.4.180 |
| bromolow | 3.10.108 |
| denverton | 4.4.180 |
| geminilake | 4.4.180 |
| v1000 | 4.4.180 |
| r1000 | 4.4.180 |
| epyc7002 | 5.10.55 |

### DSM 7.2 (17개 플랫폼, Toolchain 7.2-72806, gcc1220/glibc236)

| 플랫폼 | 커널 버전 |
|--------|-----------|
| apollolake | 4.4.180 |
| avoton | 3.10.108 |
| braswell | 3.10.108 |
| broadwell | 4.4.180 |
| broadwellnk | 4.4.302 |
| broadwellnkv2 | 4.4.302 |
| broadwellntbap | 4.4.302 |
| bromolow | 3.10.108 |
| denverton | 4.4.302 |
| geminilake | 4.4.302 |
| purley | 4.4.302 |
| v1000 | 4.4.302 |
| r1000 | 4.4.302 |
| epyc7002 | 5.10.55 |
| geminilakenk | 5.10.55 |
| r1000nk | 5.10.55 |
| v1000nk | 5.10.55 |

### DSM 7.3 (14개 플랫폼, Toolchain 7.3-86009, gcc1220/glibc236)

| 플랫폼 | 커널 버전 |
|--------|-----------|
| apollolake | 4.4.180 |
| broadwell | 4.4.180 |
| broadwellnk | 4.4.302 |
| broadwellnkv2 | 4.4.302 |
| broadwellntbap | 4.4.302 |
| denverton | 4.4.302 |
| geminilake | 4.4.302 |
| purley | 4.4.302 |
| r1000 | 4.4.302 |
| v1000 | 4.4.302 |
| epyc7002 | 5.10.55 |
| geminilakenk | 5.10.55 |
| r1000nk | 5.10.55 |
| v1000nk | 5.10.55 |

### DSM 7.4 (19개 플랫폼, Toolchain 7.4-90075, gcc1220/glibc236)

7.3 전 플랫폼 + `epyc7003` + `epyc7003ntb` (AMD EPYC 7003 시리즈).

| 플랫폼 | 커널 버전 |
|--------|-----------|
| apollolake | 4.4.180 |
| avoton | 3.10.108 |
| braswell | 3.10.108 |
| broadwell | 4.4.180 |
| broadwellnk | 4.4.302 |
| broadwellnkv2 | 4.4.302 |
| broadwellntbap | 4.4.302 |
| bromolow | 3.10.108 |
| denverton | 4.4.302 |
| geminilake | 4.4.302 |
| purley | 4.4.302 |
| r1000 | 4.4.302 |
| v1000 | 4.4.302 |
| epyc7002 | 5.10.55 |
| geminilakenk | 5.10.55 |
| r1000nk | 5.10.55 |
| v1000nk | 5.10.55 |
| epyc7003 | 5.10.55 |
| epyc7003ntb | 5.10.55 |

## Docker 이미지 태그 전략

**게시되는 태그는 DSM 버전당 하나의 fat 이미지뿐입니다.** 이미지 안에 해당 DSM 의 모든
플랫폼 툴체인이 들어 있고, 플랫폼은 `docker run ... compile-module <platform>` 로 런타임에 선택합니다.

```
dante90/syno-compiler:{dsm_version}   # 해당 DSM 전 플랫폼 포함 (예: 7.3, 7.4, 6.2)
dante90/syno-compiler:latest          # tag_latest=true 로 빌드한 버전을 가리킴
```

> ⚠️ `{dsm}-{platform}` 형태의 접미사 태그는 **게시하지 않습니다.** 소비 측 프로그램들이
> `:{dsm}` (예: `:7.3`) 만 참조하므로 규칙을 통일합니다. `build-parallel.sh ... build <platform>`
> 은 로컬 테스트용 이미지를 만들 뿐이며 워크플로우에서 푸시되지 않습니다.

## 워크플로우 상세 동작

```
[build]  단일 잡 (DSM 버전당 fat 이미지 1개)
  a. Checkout / Buildx / Docker Hub 로그인 / 캐시 복원 (Docker layers + toolkits)
  b. build-parallel.sh {dsm} all
     └─ 전 플랫폼 dev toolkit + toolchain 을 병렬 다운로드 (MAX_PARALLEL_JOBS)
     └─ 다운로드 목록/크기 출력, 필수 파일 존재/비어있음 검증 (실패 시 abort)
     └─ Dockerfile.template → Dockerfile 생성 (전 플랫폼)
     └─ Docker 이미지 빌드 (alpine:3.19 stage → debian:12-slim final)
     └─ tag_latest=true 이면 :latest 도 함께 태깅
  c. Docker Hub 에 :{dsm} (+ :latest) 푸시
```

> DSM 6.2 는 `build-6.2.yml` + `build-parallel-62.sh` 를 사용합니다 (toolchain 은 SourceForge 에서 받음).
> 6.2 스크립트는 버전 인자를 받지 않으며 첫 인자가 곧 커맨드입니다 (`platforms`/`build`/`all`).

## Dockerfile 상세

### Multi-stage 빌드
- **Stage 1** (`alpine:3.19`): 툴체인 txz 압축 해제 및 정리
- **Stage 2** (`debian:12-slim`): 최종 이미지, 빌드 도구 설치

### 환경 변수
```bash
SHELL=/bin/bash
ARCH=x86_64
```

### 주요 구성
- `/opt/{platform}/` - 플랫폼별 Synology 툴체인
- `/opt/platforms` - 플랫폼:커널버전 목록 파일
- `/input` - 소스 코드 입력 (VOLUME)
- `/output` - 컴파일 결과 출력 (VOLUME)
- ENTRYPOINT: `/opt/do.sh`
- 사용자: `arpl` (UID 1000, sudo 가능)

## 사용 예제

### 모듈 컴파일

```bash
# apollolake 플랫폼용 모듈 컴파일 (DSM 7.3 이미지에서 플랫폼은 런타임 인자로 선택)
docker run -u $(id -u) --rm -t \
  -v "/path/to/source:/input" \
  -v "/path/to/output:/output" \
  dante90/syno-compiler:7.3 \
  compile-module apollolake

# DSM 7.4 (epyc7003ntb)
docker run -u $(id -u) --rm -t \
  -v "/path/to/source:/input" \
  -v "/path/to/output:/output" \
  dante90/syno-compiler:7.4 \
  compile-module epyc7003ntb
```

## 문제 해결

### 1. Docker Hub 로그인 실패
```
Error response from daemon: unauthorized: authentication required
```
- `DOCKER_USERNAME`, `DOCKER_PASSWORD` Secrets 확인
- 비밀번호 대신 Personal Access Token 사용 권장

### 2. Toolchain 다운로드 실패
```
❌ Failed to download {platform} toolchain
❌ Verification failed: N file(s) missing or empty!
```
- 빌드 로그에서 누락된 파일명 확인
- Synology 아카이브 사이트 접근 가능 여부 확인
- URI 경로의 커널 버전이 실제 서버 경로와 일치하는지 확인

### 3. DSM 버전 미지원
```
❌ Unsupported DSM version: X.X
```
- `build-parallel.sh`의 `PLATFORMS`, `TOOLCHAIN_VERS`, `GCCLIB_VERS` 에 해당 버전 추가 필요

## 참고

- **Synology 툴체인 다운로드**: https://global.synologydownload.com/download/ToolChain/
- **Docker Hub 저장소**: https://hub.docker.com/repository/docker/dante90/syno-compiler

## 라이선스

Synology 툴체인은 GPL 라이선스입니다. Docker 이미지 사용 시 Synology 라이선스 조건을 준수하시기 바랍니다.
