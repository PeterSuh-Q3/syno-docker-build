# Synology Compiler 7.3 Docker Image - GitHub Workflow

GitHub Actions 워크플로우를 통해 Synology 툴체인 7.3를 Docker Hub에 자동으로 빌드 및 푸시합니다.

## 파일 구조

```
.
├── .github/workflows/
│   └── build-syno-compiler-7.3.yml    # GitHub Actions 워크플로우
├── Dockerfile                           # Docker 이미지 정의
├── opt/
│   └── do.sh                           # 컨테이너 엔트리포인트 스크립트
├── files/                               # 추가 파일 (필요시)
└── SYNOLOGY_COMPILER_WORKFLOW.md       # 이 파일
```

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

### 로컬 테스트 (선택사항)

```bash
# Docker 이미지 로컬 빌드
docker build -t dante90/syno-compiler:7.3-broadwell \
  --build-arg PLATFORM=broadwell \
  --build-arg TOOLCHAIN_VERSION=7.3 .

# 컨테이너 실행
docker run -v /path/to/source:/input -v /path/to/output:/output \
  dante90/syno-compiler:7.3-broadwell compile-module broadwell
```

## 워크플로우 사용 방법

### 1. 자동 빌드 (Workflow Dispatch)

GitHub 웹 인터페이스에서:

```
Repository → Actions → "Build and Push Synology Compiler 7.3"
→ Run workflow 클릭
```

또는 GitHub CLI:

```bash
gh workflow run build-syno-compiler-7.3.yml \
  -f platform=broadwell \
  -f push_latest=broadwell
```

### 2. 사용 가능한 플랫폼

- apollolake
- avoton
- braswell
- broadwell ⭐ (권장 기본값)
- broadwellnk
- broadwellnkv2
- broadwellntbap
- bromolow
- denverton
- epyc7002
- geminilake
- geminilakenk
- grantley
- kvmx64
- purley
- r1000
- r1000nk
- v1000
- v1000nk

### 3. 워크플로우 입력 옵션

| 입력 | 설명 | 필수 |
|------|------|------|
| `platform` | 빌드할 Synology 플랫폼 | ✅ |
| `push_latest` | 'latest' 태그도 업데이트할 플랫폼 ('none'이면 스킵) | ❌ |

## Docker 이미지 태그 전략

워크플로우는 다음과 같은 태그로 이미지를 푸시합니다:

```
dante90/syno-compiler:7.3-{platform}      # 항상 푸시
dante90/syno-compiler:7.3                 # push_latest={platform}일 때만
dante90/syno-compiler:latest              # push_latest={platform}일 때만
```

### 예시

```bash
# broadwell 플랫폼 빌드, latest 태그 업데이트
platform: broadwell
push_latest: broadwell

# 결과 태그:
# - dante90/syno-compiler:7.3-broadwell
# - dante90/syno-compiler:7.3
# - dante90/syno-compiler:latest
```

## 사용 예제

### 모듈 컴파일

```bash
# apollolake 플랫폼용 모듈 컴파일
docker run -u $(id -u) --rm -t \
  -v "/path/to/source:/input" \
  -v "/path/to/output:/output" \
  dante90/syno-compiler:7.3-apollolake \
  compile-module apollolake
```

### 대부분의 플랫폼 빌드 자동화

`.github/workflows/build-all-platforms.yml` (선택사항) 추가:

```yaml
name: Build all platforms

on:
  schedule:
    - cron: '0 2 * * 0'  # 주 1회 (일요일 2AM UTC)
  workflow_dispatch:

jobs:
  build-matrix:
    strategy:
      matrix:
        platform: [apollolake, broadwell, avoton, braswell, denverton]
    uses: ./.github/workflows/build-syno-compiler-7.3.yml
    with:
      platform: ${{ matrix.platform }}
      push_latest: none
    secrets: inherit
```

## 워크플로우 상세 동작

```
1. Checkout 저장소
2. Docker Buildx 설정
3. Docker Hub 로그인 (SECRETS 사용)
4. Synology 아카이브에서 toolchain txz 다운로드
   └─ 플랫폼별 디렉토리에서 {platform}-gcc1220_glibc236_x86_64-GPL.txz 다운로드
5. Toolchain 추출 및 /opt에 배치
6. Docker 이미지 빌드
   └─ ARG: PLATFORM, TOOLCHAIN_VERSION 전달
7. Docker Hub에 푸시
   └─ 태그: 7.3-{platform}, 7.3 (선택), latest (선택)
8. 빌드 요약 생성 및 artifact로 저장
```

## Dockerfile 상세

### Base Image
- `debian:11-slim` - 경량 Debian

### 환경 변수
```bash
SHELL=/bin/bash
ARCH=x86_64
PLATFORM={빌드 플랫폼}
TOOLCHAIN_VERSION=7.3
```

### 주요 구성
- `/opt` - Synology 툴체인 추출 디렉토리
- `/files` - 추가 스크립트/설정 파일
- `/input` - 소스 코드 입력 (VOLUME)
- `/output` - 컴파일 결과 출력 (VOLUME)
- ENTRYPOINT: `/opt/do.sh`
- 사용자: `arpl` (비-root)

## entrypoint 스크립트 (do.sh)

현재 기본 entrypoint는 다음을 지원합니다:

- `compile-module {platform}` - 모듈 컴파일
- `shell` - 대화형 쉘 시작

실제 컴파일 로직은 프로젝트 요구에 맞게 커스터마이즈해야 합니다.

## 문제 해결

### 1. Docker Hub 로그인 실패

```
Error response from daemon: unauthorized: authentication required
```

**해결책:**
- DOCKER_USERNAME, DOCKER_PASSWORD Secrets 확인
- 비밀번호 대신 Personal Access Token 사용 권장

### 2. Toolchain 다운로드 실패

```
Failed to download toolchain
```

**해결책:**
- Synology 아카이브 사이트 접근 가능 여부 확인
- 플랫폼명 맞는지 확인
- 네트워크 연결 확인

### 3. Docker 빌드 실패

**해결책:**
- `docker build` 로컬 테스트
- `/opt` 디렉토리에 toolchain 추출 확인
- Dockerfile 문법 점검

## 참고

- **Synology 아카이브**: https://archive.synology.com/download/ToolChain/toolchain/7.3-86009
- **Docker Hub 저장소**: https://hub.docker.com/repository/docker/dante90/syno-compiler
- **기존 태그**: 7.1, 7.2, latest

## 라이선스

Synology 툴체인은 GPL 라이선스입니다. Docker 이미지 사용 시 Synology 라이선스 조건을 준수하시기 바랍니다.
