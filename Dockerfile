FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV KBUILD_BUILD_USER="dipper-builder"

RUN apt-get update && apt-get install -y \
    build-essential bc bison flex patch pkg-config git curl tar xz-utils zip unzip \
    cpio rsync kmod perl python3 python-is-python3 libssl-dev libelf-dev pahole \
    libncurses-dev zlib1g-dev libyaml-dev lz4 zstd device-tree-compiler \
    adb fastboot wget vim nano sudo tmux jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget -q http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb \
    -O /tmp/libtinfo5.deb && dpkg -i /tmp/libtinfo5.deb && rm /tmp/libtinfo5.deb \
    || echo "libtinfo5 not available, continuing without it"

RUN useradd -m -s /bin/bash kernel-builder && \
    echo "kernel-builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/kernel-builder

USER kernel-builder
WORKDIR /home/kernel-builder

RUN mkdir -p ~/toolchains

RUN cd ~/toolchains && \
    git clone --depth=1 https://github.com/ravindu644/proton-12.git proton-12 \
    || git clone --depth=1 https://github.com/kdrag0n/proton-clang.git proton-12 \
    || { echo "WARNING: Could not clone Proton Clang. You will need to install it manually."; }

RUN cd ~/toolchains && \
    curl -Lf -o linaro.tar.xz \
    "https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains/linaro-aarch64-7.5.tar.xz" && \
    mkdir -p aarch64-linaro-7.5 && \
    tar -xJf linaro.tar.xz -C aarch64-linaro-7.5 --strip-components=1 && \
    rm linaro.tar.xz \
    || { echo "WARNING: Could not download Linaro GCC. Trying alternative source..."; \
         curl -Lf -o linaro.tar.xz \
         "https://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/aarch64-linux-gnu/gcc-linaro-7.5.1-2019.12-x86_64_aarch64-linux-gnu.tar.xz" && \
         mkdir -p aarch64-linaro-7.5 && \
         tar -xJf linaro.tar.xz -C aarch64-linaro-7.5 --strip-components=1 && \
         rm linaro.tar.xz; }

RUN set -e; \
    MAGISK_URL=$(curl -sL https://api.github.com/repos/topjohnwu/Magisk/releases/latest \
      | jq -r '.assets[] | select(.name | test("Magisk-v.*\\.apk$")) | .browser_download_url' \
      | head -1) && \
    if [ -n "$MAGISK_URL" ]; then \
      curl -Lf -o /tmp/magisk.apk "$MAGISK_URL" && \
      cd /tmp && unzip -o magisk.apk "lib/x86_64/libmagiskboot.so" 2>/dev/null || \
      unzip -o magisk.apk "lib/arm64-v8a/libmagiskboot.so" 2>/dev/null && \
      LIB_DIR=$(find /tmp/lib -name "libmagiskboot.so" | head -1) && \
      cp "$LIB_DIR" ~/toolchains/magiskboot && \
      chmod +x ~/toolchains/magiskboot && \
      rm -rf /tmp/magisk.apk /tmp/lib; \
    else \
      echo "WARNING: Could not download Magisk. magiskboot will not be available."; \
    fi

ENV PATH="/home/kernel-builder/toolchains/proton-12/bin:/home/kernel-builder/toolchains/aarch64-linaro-7.5/bin:/home/kernel-builder/toolchains:${PATH}"
ENV LD_LIBRARY_PATH="/home/kernel-builder/toolchains/proton-12/lib:/home/kernel-builder/toolchains/proton-12/lib64:${LD_LIBRARY_PATH}"

COPY --chown=kernel-builder:kernel-builder scripts/ ./scripts/
COPY --chown=kernel-builder:kernel-builder config/ ./config/

RUN chmod +x ~/scripts/*.sh

RUN echo 'export PS1="\[\033[1;36m\]dipper-builder\[\033[0m\]:\[\033[1;34m\]\W\[\033[1;33m\] ->\[\033[0m\] "' >> ~/.bashrc && \
    echo 'export PATH="/home/kernel-builder/toolchains/proton-12/bin:/home/kernel-builder/toolchains/aarch64-linaro-7.5/bin:/home/kernel-builder/toolchains:${PATH}"' >> ~/.bashrc && \
    echo 'export LD_LIBRARY_PATH="/home/kernel-builder/toolchains/proton-12/lib:/home/kernel-builder/toolchains/proton-12/lib64:${LD_LIBRARY_PATH:-}"' >> ~/.bashrc

CMD ["bash"]
