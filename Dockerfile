FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

RUN --mount=type=cache,target=/var/cache/apt \
    set -eu \
    && apt update && apt upgrade -y && apt install -y \
        python3.10 python3.10-dev python3-pip python-is-python3 \
        shadow git aria2 \
        Mesa-libGL1

# Install PyTorch nightly
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install ninja wheel setuptools numpy \
    && pip install --pre torch torchvision --force-reinstall \
        --index-url https://download.pytorch.org/whl/nightly/cu118 

# Install xFormers from wheel file we just compiled
COPY --from=yanwk/comfyui-boot:xformers /wheels /root/wheels

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install /root/wheels/*.whl \
    && rm -rf /root/wheels

# Deps for main app
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r https://raw.githubusercontent.com/comfyanonymous/ComfyUI/master/requirements.txt

# Deps for ControlNet Preprocessors
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r https://raw.githubusercontent.com/Fannovel16/comfy_controlnet_preprocessors/main/requirements.txt \
    --extra-index-url https://download.pytorch.org/whl/nightly/cu118 

# Fix for CuDNN
WORKDIR /usr/lib64/python3.10/site-packages/torch/lib
RUN ln -s libnvrtc-672ee683.so.11.2 libnvrtc.so 
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/lib64/python3.10/site-packages/torch/lib"

# Create a low-privilege user.
RUN printf 'CREATE_MAIL_SPOOL=no' > /etc/default/useradd \
    && mkdir -p /home/runner /home/scripts \
    && groupadd runner \
    && useradd runner -g runner -d /home/runner \
    && chown runner:runner /home/runner /home/scripts

COPY --chown=runner:runner scripts/. /home/scripts/

COPY ./test.py /home/test.py

RUN /home/scripts/test.sh

USER runner:runner
VOLUME /home/runner
WORKDIR /home/runner
EXPOSE 8188
ENV CLI_ARGS=""
CMD ["bash","/home/scripts/entrypoint.sh"]
