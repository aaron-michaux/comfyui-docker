FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Toronto

# RUN echo 'deb mirror://mirrors.ubuntu.com/mirrors.txt jammy main restricted universe multiverse' >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y \
    git \
    make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev git git-lfs  \
    ffmpeg libsm6 libxext6 cmake libgl1-mesa-glx \
    tree g++ gdb ripgrep vim nano \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# User
RUN useradd -m --groups users,sudo -u 1000 comfyui
ENV HOME=/home/comfyui
ENV PATH=/home/comfyui/.local/bin:$PATH

WORKDIR $HOME

RUN chown 1000:1000 -R $HOME

USER comfyui

# Set up run stub
RUN mkdir -p $HOME/app
RUN mkdir -p $HOME/app/models
RUN echo "python3 /home/comfyui/app/main.py --listen --port 8188" > $HOME/run-comfyui.sh
RUN chmod 755 $HOME/run-comfyui.sh

ENV COMFYUI_PATH=$HOME/app
ENV COMFYUI_MODEL_PATH=$HOME/app/models

# Pyenv
RUN curl https://pyenv.run | bash
ENV PATH=$HOME/.pyenv/shims:$HOME/.pyenv/bin:$PATH

# Python
# ARG PYTHON_VERSION=3.10.12
ENV PYTHON_VERSION=3.11.11
RUN pyenv install $PYTHON_VERSION && \
    pyenv global  $PYTHON_VERSION && \
    pyenv rehash && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    datasets \
    huggingface-hub "protobuf<4" "click<8.1"

# Install pip dependencies
COPY ./requirements.txt $HOME/requirements.txt
RUN pip install xformers!=0.0.18 --no-cache-dir --upgrade -r $HOME/requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121

RUN echo "Done"

