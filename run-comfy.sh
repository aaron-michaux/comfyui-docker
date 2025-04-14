#!/bin/bash

set -euo pipefail

PPWD="$(cd "$(dirname "$0")" ; pwd)"
COMFY_DIR="$HOME/Documents/ComfyUI"
PORT=8188
CARDID=0
COMFY_HELP="False"
ENTER_CONTAINER="False"
CONTAINER_NAME="ComfyUI"

# BASIC_OPTS=" --force-fp16"
# BASIC_OPTS=" --lowvram"
BASIC_OPTS=""
# --lowvram
# --force-fp16  Force fp16.
# --fp16-vae    Run the VAE in fp16, might cause black images.
# --bf16-vae    Run the VAE in bf16, might lower quality.

# ---------------------------------------------------------------------------------------- 

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [Options...]

   Options:

      -e|--enter               Enter the built container
      -p|--port <integer>      Port to server on
      -i|--card-id <integer>   The CUDA card id to use
      -h|--help
      --comfy-help
      --                       Pass remaining arguments directly to comfy

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

EOF
}

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

# ------------------------------------------------------------------------------------------ Action!

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "--" ] && break
    [ "$ARG" = "--comfy-help" ] && COMFY_HELP="True" && continue
    [ "$ARG" = "-e" ] || [ "$ARG" = "--enter" ] && ENTER_CONTAINER="True" && continue
    [ "$ARG" = "-p" ] || [ "$ARG" = "--port" ] && PORT="$1" && shift && continue
    [ "$ARG" = "-i" ] || [ "$ARG" = "--card-id" ] && CARDID="$1" && shift && continue
    echo "Unexpected argument: $ARG" 1>&2 && exit 1
done

if [ ! -d "$COMFY_DIR" ] ; then
    echo "Directory not found, comfy-dir: $COMFY_DIR" 1>&2
    exit 1
fi

ENTRY_POINT_ARG=""
REQUIRED_ARGS=""
if [ "$ENTER_CONTAINER" = "True" ] ; then
    ENTRY_POINT_ARG="--entrypoint /bin/bash"
    REQUIRED_ARGS=""
else
    ENTRY_POINT_ARG="--entrypoint /bin/bash"
    REQUIRED_ARGS="python3 /home/comfyui/app/main.py --listen --port $PORT --cuda-device $CARDID $BASIC_OPTS"
fi
cd "$PPWD"

docker kill $CONTAINER_NAME 2>/dev/null || true
docker rm   $CONTAINER_NAME 2>/dev/null || true
docker build -f Dockerfile -t comfyui:latest .
docker run -it \
       --name $CONTAINER_NAME \
       -p $PORT:$PORT \
       -e NVIDIA_VISIBLE_DEVICES=all \
       --gpus all \
       -v "${COMFY_DIR}:/home/comfyui/app" \
       $ENTRY_POINT_ARG \
       comfyui:latest \
       -- $REQUIRED_ARGS "$@"

