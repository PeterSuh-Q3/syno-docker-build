# Synology Compiler - Quick Start

Synology 크로스 컴파일 툴체인을 Docker 이미지(`dante90/syno-compiler`)로 빌드/배포합니다.
자세한 설계는 [README.md](README.md) 참고.

## 1단계: GitHub Secrets 설정

Docker Hub 푸시용 인증 정보를 저장소에 등록합니다:

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
→ dsm_version / platforms / push_to_hub / tag_latest / build_method 선택 → Run
```

DSM 6.2 는 별도 워크플로우 **"Build and Push (6.2)"** 를 사용합니다.

### 옵션 B: GitHub CLI

```bash
# DSM 7.3 전체 플랫폼, 플랫폼별로 병렬 빌드 → :7.3-{platform} 이미지들
gh workflow run build-parallel.yml \
  -f dsm_version=7.3 -f platforms=all -f build_method=parallel -f push_to_hub=true

# DSM 7.2 broadwell 한 개만 → :7.2-broadwell
gh workflow run build-parallel.yml \
  -f dsm_version=7.2 -f platforms=broadwell -f push_to_hub=true

# DSM 7.3 전체를 하나의 fat 이미지로 → :7.3 (+ :latest)
gh workflow run build-parallel.yml \
  -f dsm_version=7.3 -f platforms=all -f build_method=sequential \
  -f tag_latest=true -f push_to_hub=true

# DSM 6.2
gh workflow run build-6.2.yml -f platforms=all -f build_method=parallel
```

### 워크플로우 입력 요약

| 입력 | 설명 | 기본값 |
|------|------|--------|
| `dsm_version` | DSM 버전 (7.0/7.1/7.2/7.3) | `7.3` |
| `platforms` | `all` 또는 단일 플랫폼명 | `all` |
| `build_method` | `parallel`(플랫폼별 잡) / `sequential`(단일 잡) | `parallel` |
| `push_to_hub` | Docker Hub 푸시 | `true` |
| `tag_latest` | `sequential`+`all` 일 때 `:latest` 도 갱신 | `false` |

## 3단계: 로컬 빌드 (테스트)

로컬 실행에는 **bash 4 이상**이 필요합니다 (macOS 기본 bash 3.2 불가 → `brew install bash`).

```bash
# 플랫폼 목록(JSON) 확인
./build-parallel.sh 7.3 platforms

# 단일 플랫폼 다운로드+빌드 → dante90/syno-compiler:7.3-broadwell
./build-parallel.sh 7.3 build broadwell

# 전체 플랫폼을 하나의 fat 이미지로 → dante90/syno-compiler:7.3
./build-parallel.sh 7.3 all

# DSM 6.2 (버전 인자 없음)
./build-parallel-62.sh build broadwell
```

## 4단계: 이미지 사용

```bash
# 모듈 컴파일
docker run -u $(id -u) --rm -t \
  -v /path/to/source:/input \
  -v /path/to/output:/output \
  dante90/syno-compiler:7.3-broadwell \
  compile-module broadwell

# 대화형 셸
docker run --rm -it \
  -v /path/to/work:/input \
  dante90/syno-compiler:7.3-broadwell \
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
