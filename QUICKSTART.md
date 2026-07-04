# Synology Compiler - Quick Start

Synology 크로스 컴파일 툴체인을 Docker 이미지로 빌드/배포합니다.
DSM 버전당 **전 플랫폼을 담은 단일 이미지** `dante90/syno-compiler:{dsm}` 를 게시합니다
(플랫폼은 `compile-module <platform>` 로 런타임에 선택). 설계는 [README.md](README.md) 참고.

## 1단계: GitHub Secrets 설정

```
Settings → Secrets and variables → Actions → New repository secret
```

| 이름 | 값 |
|-----|-----|
| `DOCKER_USERNAME` | Docker Hub 사용자명 |
| `DOCKER_PASSWORD` | Docker Hub Personal Access Token (Read & Write) |

## 2단계: 워크플로우 실행

### 옵션 A: GitHub 웹 인터페이스

```
Actions → "Build and Push Synology Compiler (Performance Optimized)" → Run workflow
→ dsm_version / push_to_hub / tag_latest 선택 → Run
```

DSM 6.2 는 별도 워크플로우 **"Build and Push (6.2)"** 를 사용합니다.

### 옵션 B: GitHub CLI

```bash
# DSM 7.3 → dante90/syno-compiler:7.3
gh workflow run build-parallel.yml -f dsm_version=7.3 -f push_to_hub=true

# DSM 7.4 (+ latest 갱신) → :7.4 (+ :latest)
gh workflow run build-parallel.yml -f dsm_version=7.4 -f push_to_hub=true -f tag_latest=true

# DSM 6.2
gh workflow run build-6.2.yml -f push_to_hub=true
```

### 워크플로우 입력 요약

| 입력 | 설명 | 기본값 |
|------|------|--------|
| `dsm_version` | DSM 버전 (7.0/7.1/7.2/7.3/7.4) | `7.3` |
| `push_to_hub` | Docker Hub 푸시 | `true` |
| `tag_latest` | `:latest` 도 갱신 | `false` |

## 3단계: 로컬 빌드 (테스트)

로컬 실행에는 **bash 4 이상**이 필요합니다 (macOS 기본 bash 3.2 불가 → `brew install bash`).

```bash
# 플랫폼 목록(JSON) 확인
./build-parallel.sh 7.3 platforms

# 전 플랫폼 fat 이미지 → dante90/syno-compiler:7.3
./build-parallel.sh 7.3 all

# DSM 6.2 (버전 인자 없음)
./build-parallel-62.sh all

# (로컬 테스트용) 단일 플랫폼 이미지 — 게시용 아님
./build-parallel.sh 7.1 build broadwell
```

## 4단계: 이미지 사용

```bash
# 모듈 컴파일 (이미지는 :{dsm}, 플랫폼은 인자로)
docker run -u $(id -u) --rm -t \
  -v /path/to/source:/input \
  -v /path/to/output:/output \
  dante90/syno-compiler:7.3 \
  compile-module broadwell

# DSM 7.4
docker run -u $(id -u) --rm -t \
  -v /path/to/source:/input \
  -v /path/to/output:/output \
  dante90/syno-compiler:7.4 \
  compile-module epyc7003ntb

# 대화형 셸
docker run --rm -it \
  -v /path/to/work:/input \
  dante90/syno-compiler:7.3 \
  shell
```

## 트러블슈팅

| 증상 | 확인 사항 |
|------|-----------|
| `authentication required` | `DOCKER_USERNAME` / `DOCKER_PASSWORD` Secret, 토큰 권한(R/W) |
| `Failed to download ... toolchain` | 플랫폼명(대소문자), 네트워크, Synology/SourceForge 접근 가능 여부 |
| `Platform '...' not found` | 해당 DSM 버전이 지원하는 플랫폼인지 (`... platforms` 로 확인) |
| 로컬 실행 시 빈 태그/오류 | bash 4+ 사용 여부 (`bash --version`) |

## 참고

- Synology ToolChain: https://archive.synology.com/download/ToolChain/
- Docker Hub: https://hub.docker.com/r/dante90/syno-compiler
