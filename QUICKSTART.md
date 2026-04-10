# Synology Compiler 7.3 - Quick Start Guide

## 1단계: GitHub Secrets 설정

Docker Hub 푸시를 위한 인증 정보 설정:

```bash
# GitHub 웹 인터페이스에서:
# Settings → Secrets and variables → Actions → New repository secret

# 다음 두 개의 Secret 추가:
DOCKER_USERNAME   = <your-docker-hub-username>
DOCKER_PASSWORD   = <your-docker-hub-access-token>  # 비밀번호 대신 토큰 권장
```

**Personal Access Token 생성 방법:**
1. Docker Hub → Account Settings → Security
2. "New Access Token" 클릭
3. Read & Write 권한 선택
4. GitHub Secret에 저장

---

## 2단계: 워크플로우 실행

### 옵션 A: GitHub 웹 인터페이스

```
GitHub 저장소 → Actions 탭
→ "Build and Push Synology Compiler 7.3"
→ "Run workflow" 클릭
→ platform 선택 (예: broadwell)
→ push_latest 선택 (예: broadwell로 'latest' 태그도 업데이트)
→ "Run workflow" 클릭
```

### 옵션 B: GitHub CLI

```bash
# broadwell 플랫폼 빌드 (latest 태그도 업데이트)
gh workflow run build-syno-compiler-7.3.yml \
  -f platform=broadwell \
  -f push_latest=broadwell
```

### 옵션 C: 로컬 빌드 (테스트용)

```bash
# 단일 플랫폼 빌드
docker build -t dante90/syno-compiler:7.3-broadwell \
  --build-arg PLATFORM=broadwell \
  --build-arg TOOLCHAIN_VERSION=7.3 .

# 모든 플랫폼 빌드 (로컬)
./scripts/build-all-platforms.sh

# 모든 플랫폼 빌드 + Docker Hub 푸시
./scripts/build-all-platforms.sh true
```

---

## 3단계: 빌드된 이미지 확인

```bash
# 로컬 이미지 확인
docker images | grep syno-compiler

# Docker Hub 푸시 확인
# https://hub.docker.com/repository/docker/dante90/syno-compiler/tags

# 빌드 로그 확인 (GitHub)
# 저장소 → Actions → 워크플로우 이름 → 해당 실행 선택
```

---

## 4단계: Docker 이미지 사용

### 모듈 컴파일 예제

```bash
# apollolake 플랫폼에서 모듈 컴파일
docker run --rm -it \
  -v /path/to/source:/input \
  -v /path/to/output:/output \
  dante90/syno-compiler:7.3-apollolake \
  compile-module apollolake

# broadwell 플랫폼 (최신 버전)
docker run --rm -it \
  -v /path/to/source:/input \
  -v /path/to/output:/output \
  dante90/syno-compiler:7.3 \
  compile-module broadwell
```

### 대화형 쉘 시작

```bash
docker run --rm -it \
  -v /path/to/work:/input \
  dante90/syno-compiler:7.3-broadwell \
  shell
```

---

## 트러블슈팅

### 문제: "authentication required" 오류

```
Error response from daemon: unauthorized: authentication required
```

**해결책:**
```bash
# 1. Docker Hub 재로그인
docker login

# 2. GitHub Secrets 확인
#    - DOCKER_USERNAME 정확한지 확인
#    - DOCKER_PASSWORD (또는 토큰) 유효한지 확인
#    - 공개 이미지인 경우 토큰이 읽기 권한이 아닌 읽기/쓰기 권한 필요

# 3. 저장소 접근 권한 확인
#    - 개인 저장소인 경우 충분한 권한 있는지 확인
```

### 문제: "Toolchain download failed"

**해결책:**
```bash
# 1. 플랫폼명 확인 (대소문자 구분)
# 2. 인터넷 연결 확인
# 3. Synology 아카이브 사이트 접근 가능 여부 확인:
curl -s https://archive.synology.com/download/ToolChain/toolchain/7.3-86009 | head -20
```

### 문제: 로컬 Docker 빌드 실패

**해결책:**
```bash
# 1. 권한 확인
ls -la Dockerfile opt/

# 2. opt/ 디렉토리 구조 확인
#    (워크플로우에서 자동으로 툴체인을 다운로드/추출하므로 로컬에서는 빌드 실패 가능)

# 3. opt/ 디렉토리 수동 준비:
mkdir -p opt/
# 여기에 시놀로지 툴체인 txz를 수동으로 추출
```

---

## 플랫폼 목록

| 플랫폼 | CPU | Kernel | 비고 |
|--------|-----|--------|------|
| apollolake | Intel Atom | 4.4.180 | |
| avoton | Intel Atom | 3.10.108 | |
| braswell | Intel Pentium | 3.10.108 | |
| **broadwell** | Intel Core i7 | 4.4.180 | ⭐ 기본값 (가장 널리 사용) |
| broadwellnk | Intel Core | 4.4.302 | |
| broadwellnkv2 | Intel Core | 4.4.302 | |
| broadwellntbap | Intel Core | 4.4.302 | |
| bromolow | Intel Pentium | 3.10.108 | |
| denverton | Intel Atom | 4.4.302 | |
| epyc7002 | AMD EPYC | 5.10.55 | |
| geminilake | Intel Celeron | 4.4.302 | |
| geminilakenk | Intel Celeron | 5.10.55 | |
| grantley | Intel Xeon | 3.10.108 | |
| kvmx64 | QEMU/KVM | 4.4.302 | |
| purley | Intel Xeon | 4.4.302 | |
| r1000 | AMD Ryzen | 4.4.302 | |
| r1000nk | AMD Ryzen | 5.10.55 | |
| v1000 | AMD Radeon | 4.4.302 | |
| v1000nk | AMD Radeon | 5.10.55 | |

---

## 다음 단계

1. **entrypoint 스크립트 커스터마이즈**: `/opt/do.sh`를 프로젝트에 맞게 수정
2. **추가 파일 준비**: `files/` 디렉토리에 필요한 스크립트/설정 추가
3. **다중 플랫폼 빌드**: `./scripts/build-all-platforms.sh` 스크립트 활용

---

## 참고 자료

- **Synology Developer Resources**: https://archive.synology.com/download/ToolChain/
- **Docker Documentation**: https://docs.docker.com/
- **GitHub Actions**: https://docs.github.com/en/actions

---

**Need help?** GitHub Issues에서 문제를 보고해 주세요.
