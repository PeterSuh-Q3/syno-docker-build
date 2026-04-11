# 🐳 Docker Hub 설정 완벽 가이드

## 🎯 개요

Synology Docker Build 시스템에서 Docker Hub로 이미지를 push하려면 적절한 계정 설정이 필요합니다. 이 가이드는 **통합 Docker Hub 관리 도구**를 사용해 간단하게 설정하는 방법을 안내합니다.

## 🚀 빠른 설정 (권장)

### 1단계: Docker Hub 계정 설정
```bash
# 🛠️ 통합 설정 도구로 한 번에 설정
./docker-hub-manager.sh setup
```

이 명령어는 다음을 자동으로 처리합니다:
- Docker Hub 계정 정보 입력 및 저장
- Docker 로그인 설정
- 빌드 스크립트들의 이미지 이름 자동 업데이트
- 설정 테스트 및 검증

### 2단계: GitHub Actions 설정 (CI/CD용)
```bash
# 🔐 GitHub Secrets 설정 가이드
./docker-hub-manager.sh github-setup
```

## 📋 세부 설정 과정

### 🔑 Docker Hub 계정 준비

1. **Docker Hub 계정**: [hub.docker.com](https://hub.docker.com)에서 무료 계정 생성
2. **Access Token 생성** (권장):
   ```
   Docker Hub → Settings → Security → New Access Token
   - Name: "Synology Build"  
   - Permissions: Read, Write, Delete
   ```

### 🛠️ 로컬 환경 설정

```bash
# 현재 Docker Hub 상태 확인
./docker-hub-manager.sh status

# 처음 설정 (대화형)
./docker-hub-manager.sh setup

# 기존 계정으로 로그인
./docker-hub-manager.sh login

# 설정 테스트
./docker-hub-manager.sh test-push
```

### 🔄 GitHub Actions 설정

GitHub 저장소에서 다음 Secrets을 설정:

| Secret Name | Value | 설명 |
|-------------|--------|------|
| `DOCKER_USERNAME` | 사용자명 | Docker Hub 계정명 |
| `DOCKER_PASSWORD` | 토큰/비밀번호 | Access Token 권장 |

**설정 방법:**
1. GitHub 저장소 → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. 위 정보 입력

## ⚡ 통합 빌드 시스템 사용법

### Docker Hub 설정 완료 후

```bash
# 🚀 완전 자동화 빌드 (push 포함)
./build-manager.sh quick

# 📊 시스템 상태 확인 (Docker Hub 로그인 상태 포함)
./build-manager.sh status

# 🏗️ 플랫폼별 빌드
./build-manager.sh platform epyc7002
```

### Docker Hub 없이 로컬 빌드만

```bash
# 로그인 없이도 로컬 빌드 가능
export NO_DOCKER_PUSH=true
./build-manager.sh quick
```

## 🔧 설정별 사용 시나리오

### 시나리오 1: 개발자 로컬 환경

```bash
# 처음 한 번만 설정
./docker-hub-manager.sh setup

# 이후 일반적인 사용
./build-manager.sh quick                    # Docker Hub로 push
```

### 시나리오 2: CI/CD 환경 (GitHub Actions)

```bash
# GitHub Secrets 설정
./docker-hub-manager.sh github-setup

# Workflow 파일에서 자동으로 처리됨
# .github/workflows/build-parallel.yml 사용
```

### 시나리오 3: 테스트 환경 (push 없음)

```bash
# Docker Hub 없이 로컬 빌드만
export NO_DOCKER_PUSH=true
./build-manager.sh quick
```

## 🎛️ 관리 명령어 모음

### Docker Hub 관련 명령어

```bash
# 🔍 상태 및 진단
./docker-hub-manager.sh status              # 현재 상태 확인
./docker-hub-manager.sh test-push           # Push 권한 테스트

# 🔐 인증 관리
./docker-hub-manager.sh login               # 로그인
./docker-hub-manager.sh logout              # 로그아웃

# ⚙️ 설정 관리
./docker-hub-manager.sh setup               # 완전 설정
./docker-hub-manager.sh github-setup        # GitHub 가이드
```

### 통합 빌드 매니저에서

```bash
# Docker Hub 통합 명령어들
./build-manager.sh docker-setup             # 계정 설정
./build-manager.sh docker-login             # 로그인
./build-manager.sh docker-status            # 상태 확인
./build-manager.sh docker-github            # GitHub 설정
```

## 🚨 문제 해결

### 일반적인 문제들

**1. "unauthorized: authentication required"**
```bash
# 해결: Docker Hub 로그인
./docker-hub-manager.sh login

# 또는 Access Token 사용
./docker-hub-manager.sh setup
```

**2. "denied: requested access to the resource is denied"**
```bash
# 해결: 저장소 권한 확인
./docker-hub-manager.sh test-push

# 저장소가 존재하고 Write 권한이 있는지 확인
```

**3. GitHub Actions 실패**
```bash
# 해결: Secrets 확인
./docker-hub-manager.sh github-setup

# DOCKER_USERNAME, DOCKER_PASSWORD 정확한지 확인
```

**4. 이미지 이름 변경 필요**
```bash
# 해결: 설정 업데이트
./docker-hub-manager.sh setup

# 모든 스크립트의 이미지 이름이 자동 업데이트됨
```

### 디버깅 도구

```bash
# 🔍 상세 진단
./docker-hub-manager.sh status
./build-manager.sh status

# 📊 Docker 정보 확인
docker info | grep Username
docker images | grep syno-compiler

# 🧪 테스트 빌드 (push 없음)
export NO_DOCKER_PUSH=true
./build-manager.sh quick
```

## 🔒 보안 모범 사례

### Access Token 사용 (권장)

✅ **권장사항:**
- Docker Hub 비밀번호 대신 **Access Token** 사용
- 토큰에 필요한 최소 권한만 부여
- 정기적으로 토큰 로테이션

❌ **피해야 할 것:**
- 평문 비밀번호 저장
- 과도한 권한 부여
- 토큰 공개 저장소에 노출

### 환경별 설정

```bash
# 개발 환경: 제한된 권한 토큰
DOCKER_TOKEN_PERMISSIONS="Read, Write"

# 프로덕션: 전체 권한 (필요시)
DOCKER_TOKEN_PERMISSIONS="Read, Write, Delete"

# CI/CD: Write 권한 + 자동 정리
DOCKER_TOKEN_AUTO_CLEANUP="true"
```

## 📚 레퍼런스

### 설정 파일 위치

```
~/.docker-hub-config          # 로컬 Docker Hub 설정
.github/workflows/            # CI/CD 워크플로우
docker-hub-manager.sh         # 통합 관리 도구
build-manager.sh              # 빌드 매니저 (Docker Hub 통합)
```

### 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `NO_DOCKER_PUSH` | Docker Hub push 비활성화 | `false` |
| `DOCKER_HUB_USERNAME` | Docker Hub 사용자명 | `dante90` |
| `DOCKER_HUB_REPO` | 저장소 이름 | `syno-compiler` |

### 이미지 이름 규칙

```bash
# 기본 구조
{username}/{repository}:{tag}

# 예시
dante90/syno-compiler:7.3
dante90/syno-compiler:7.3-epyc7002  
dante90/syno-compiler:latest
```

---

## 🎉 완료 확인

모든 설정이 완료되면:

1. ✅ `./build-manager.sh status`에서 "Docker Hub: logged in" 표시
2. ✅ `./build-manager.sh quick`으로 빌드 + push 성공  
3. ✅ GitHub Actions에서 자동 빌드/푸시 동작
4. ✅ Docker Hub에서 이미지 확인 가능

**이제 60-70% 빠른 빌드와 함께 Docker Hub 자동 배포까지 완성되었습니다!** 🚀