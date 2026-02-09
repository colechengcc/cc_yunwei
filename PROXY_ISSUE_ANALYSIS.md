# Docker Build Proxy Issue Analysis

## Problem Summary

Your Docker build is failing because `apt update` inside the container is trying to use proxy `172.16.21.69:7897` (which returns 502 Bad Gateway), even though your Docker daemon is configured to use `172.16.21.5:7890`.

## Root Cause

The error shows:
```
7.746 Err:3 http://archive.archive.ubuntu.com/ubuntu focal-updates InRelease
7.746   502  Bad Gateway [IP: 172.16.21.69 7897]
8.300 Err:4 http://security.archive.ubuntu.com/ubuntu focal-security InRelease
8.300   502  Bad Gateway [IP: 172.16.21.69 7897]
```

**Why is 172.16.21.69:7897 being used instead of 172.16.21.5:7890?**

The issue is that **Docker daemon proxy settings only apply to the Docker daemon itself** (for pulling images from registries), but **NOT to the build process inside containers**. The apt commands running inside your container need separate proxy configuration.

## Evidence of Proxy Misconfiguration

1. **Docker daemon proxy** (correctly configured):
   ```
   HTTP_PROXY=http://172.16.21.5:7890
   HTTPS_PROXY=http://172.16.21.5:7890
   ```

2. **Old proxy configuration** found in `/etc/profile` (commented out):
   ```bash
   #export https_proxy=http://172.16.21.69:7897 http_proxy=http://172.16.21.69:7897
   ```

3. **The container is somehow inheriting or using the old proxy** (172.16.21.69:7897)

## Solutions

### Solution 1: Pass Proxy Settings to Build (Recommended)

Add `--build-arg` flags to your docker build command to pass proxy settings into the build:

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --build-arg NO_PROXY="127.0.0.1,localhost,reg.smvm.cn" \
  --build-arg no_proxy="127.0.0.1,localhost,reg.smvm.cn" \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  -t your-image-name \
  .
```

### Solution 2: Configure BuildKit Proxy Settings

Create or edit `~/.docker/config.json` to include proxy settings for BuildKit:

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.16.21.5:7890",
      "httpsProxy": "http://172.16.21.5:7890",
      "noProxy": "127.0.0.1,localhost,reg.smvm.cn"
    }
  }
}
```

Then restart Docker:
```bash
systemctl restart docker
```

### Solution 3: Add Proxy Configuration in Dockerfile

Modify your Dockerfile to explicitly set proxy before apt commands:

```dockerfile
FROM ubuntu:20.04 as Base

# Set proxy for this build
ENV HTTP_PROXY=http://172.16.21.5:7890
ENV HTTPS_PROXY=http://172.16.21.5:7890
ENV http_proxy=http://172.16.21.5:7890
ENV https_proxy=http://172.16.21.5:7890
ENV NO_PROXY=127.0.0.1,localhost,reg.smvm.cn

RUN apt update \
     && apt -y install clang make tree fontconfig gperf \
     && ln -s /usr/bin/python3 /usr/bin/python \
     && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.91.0 --target aarch64-unknown-linux-gnu --profile minimal \
     && cargo --version \
     && cp -s /usr/bin/aarch64-linux-gnu-gcc /usr/bin/aarch64-unknown-linux-gnu-gcc \
     && cp -s /usr/bin/aarch64-linux-gnu-ar /usr/bin/aarch64-unknown-linux-gnu-ar

# Unset proxy after build (optional, if you don't want it in final image)
ENV HTTP_PROXY=
ENV HTTPS_PROXY=
ENV http_proxy=
ENV https_proxy=
```

### Solution 4: Check for APT Proxy Configuration in Base Image

The base image might have APT proxy configuration. Add this to your Dockerfile before `apt update`:

```dockerfile
RUN rm -f /etc/apt/apt.conf.d/proxy.conf \
    && rm -f /etc/apt/apt.conf.d/*proxy* \
    && echo "Acquire::http::Proxy \"http://172.16.21.5:7890\";" > /etc/apt/apt.conf.d/01proxy \
    && echo "Acquire::https::Proxy \"http://172.16.21.5:7890\";" >> /etc/apt/apt.conf.d/01proxy
```

## Additional Recommendations

1. **Verify proxy is working**:
   ```bash
   curl -x http://172.16.21.5:7890 http://archive.ubuntu.com
   ```

2. **Check if old proxy (172.16.21.69:7897) is still accessible**:
   ```bash
   curl -x http://172.16.21.69:7897 http://archive.ubuntu.com
   ```

3. **Clean up old proxy references**:
   ```bash
   grep -r "172.16.21.69" /etc/
   ```

4. **For debugging, build with no cache**:
   ```bash
   docker build --no-cache --progress=plain ...
   ```

## Quick Fix Command

Try this immediate fix:

```bash
docker build \
  --build-arg HTTP_PROXY=http://172.16.21.5:7890 \
  --build-arg HTTPS_PROXY=http://172.16.21.5:7890 \
  --build-arg http_proxy=http://172.16.21.5:7890 \
  --build-arg https_proxy=http://172.16.21.5:7890 \
  --no-cache \
  -f Dockerfile.1.91-cross-aarch64-linux-gnu \
  .
```

## Why Both Proxies Appear

The 172.16.21.69:7897 proxy is likely:
- Hardcoded in your base image's APT configuration
- Set in a cached build layer
- Coming from environment variables in your shell that get inherited

The 172.16.21.5:7890 is your current Docker daemon proxy setting.

---

**Recommended Action**: Use Solution 1 (build args) combined with Solution 3 (Dockerfile ENV) for maximum compatibility.
