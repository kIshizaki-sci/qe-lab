ARG BASE_IMAGE=intel/oneapi-hpckit:2023.2.1-devel-ubuntu22.04

FROM $BASE_IMAGE

LABEL maintainer="Kohei ISHIZAKI <ishizaki@superstring.dev>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash

USER root
RUN mkdir /root/docker_build;
RUN dpkgArch="$(dpkg --print-architecture)"; \
        case "${dpkgArch##*-}" in \
            amd64) perl -p -i.bak -e 's%(deb(?:-src|)\s+)https?://(?!archive\.canonical\.com|security\.ubuntu\.com)[^\s]+%$1http://ftp.riken.go.jp/Linux/ubuntu/%' /etc/apt/sources.list;; \
        esac; \
    ln -sf  /usr/share/zoneinfo/Asia/Tokyo /etc/localtime; \
    echo "postfix postfix/main_mailer_type string 'No configuration'" | debconf-set-selections

RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
    | tee /etc/apt/sources.list.d/oneAPI.list

RUN apt update && \
    apt upgrade -y --no-install-recommends \
    && apt install -y --no-install-recommends \
    curl \
    git \
    sudo \
    apt-utils \
    wget; \
    apt install -y --no-install-recommends \
    cmake \
    ca-certificates \
    build-essential \
    python3-dev \
    unzip \
    python3-pip \
    # 2025年8月 nobleではv.18がインストール
    llvm; \
    apt install -yq --no-install-recommends \
    emacs-nox \
    locales \
    # fonts with the same metrics as Times, Arial and Courier
    fonts-liberation \
    #scalable PostScript and OpenType fonts based on Computer Modern
    lmodern \
    #世界中の多くの代表的な場所のローカル時間の実装に必要な データが含まれます。タイムゾーンの境界への政治団体による変更、UTC オフセット、 そしてサマータイムルールを反映するため、定期的に更新されています。
    tzdata \
    #ドキュメントの変換
    pandoc \
    # グラフ形式のデータの作成
    graphviz-dev; \
    apt clean; \
    rm -rf /var/lib/apt/lists/*;

RUN apt install -yq --no-install-recommends \
    language-pack-ja;\
    echo 'LANG=ja_JP.UTF-8' >> /etc/profile; \
    apt clean; \
    rm -rf /var/lib/apt/lists/*;

ENV LANG=ja_JP.UTF-8

RUN apt update && \
    apt install -yq --no-install-recommends \
    # GNU assembler, linker and binary utilities
    binutils \
    # X11 pixmap library (development headers)
    libxpm-dev \
    # FreeType-based font drawing library for X (development files)
    libxft-dev \
    libssl-dev \
    gfortran \
    # Old Perl 5 Compatible Regular Expression Library - development files
    libpcre3-dev \
    #xlibmesa-glu-dev \
    # OpenGL Extension Wrangler - development environment
    libglew-dev \
    libftgl-dev \
    libmysqlclient-dev \
    libfftw3-dev \
    # CFITSIO based utilities
    libcfitsio-dev \
    # Development headers for the Avahi Apple Bonjour compatibility library
    libavahi-compat-libdnssd-dev \
    libldap-dev \
    # 2025年8月 nobleではv.2.9がインストール
    libxml2-dev \
    # headers and development libraries for MIT Kerberos
    libkrb5-dev \
    # HDF5 - development files - serial version
    libhdf5-dev \
    libgsl0-dev; \
    apt clean; \
    rm -rf /var/lib/apt/lists/*;

WORKDIR /root
RUN curl -LsSf https://astral.sh/uv/install.sh | sh;\
    source $HOME/.local/bin/env;\
    uv self update;\
    uv python install 3.12.11;\
    uv venv /opt/venv;

# Claude Code をインストール
RUN curl -fsSL https://claude.ai/install.sh | bash

ENV VIRTUAL_ENV=/opt/VIRTUAL_ENV
ENV PATH="/root/.local/bin:${PATH}"
ENV PATH="/opt/venv/bin:${PATH}"

COPY python_env/requirements.txt requirements.txt
RUN uv pip install -r requirements.txt

COPY python_env/jupyterlab-settings /root/.jupyter/lab/user-settings

RUN apt update && \
    apt install -yq --no-install-recommends \
    automake \
    autoconf; \
    apt clean; \
    rm -rf /var/lib/apt/lists/*;

WORKDIR /root
RUN git clone --depth=1 https://github.com/QEF/q-e.git -b qe-7.4.1 espresso-src &&\
    mkdir espresso;
WORKDIR /root/espresso-src

RUN ./configure \
    F90=ifort \
    F77=ifort \
    FC=ifort \
    CC=icc \
    CXX=icpc \
    FFLAGS="-O3 -assume byterecl -ip -g -qopenmp -qmkl=parallel -xhost  -par-num-threads=12 -prof-gen -ipo" \
    FCLAGS="-O3 -assume byterecl -ip -g -qopenmp -qmkl=parallel -xhost  -par-num-threads=12 -prof-gen -ipo" \
    --enable-openmp --enable-parallel=no --with-scalapack=intel --prefix='/root/espresso' && \
    #--enable-openmp --enable-parallel=no --with-scalapack=intel && \
    make all gui gipaw &&\
    make install;
    #make all gui gipaw;
ENV PATH=$PATH:/root/espresso/bin

# GitHub設定スクリプトをコピー
COPY scripts/setup-github.sh /usr/local/bin/setup-github.sh
RUN chmod +x /usr/local/bin/setup-github.sh

# エントリーポイントスクリプトをコピー
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /root
RUN mkdir pseudo_dir notebooks;

# エントリーポイントを設定
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]