FROM ubuntu:latest


RUN apt update && apt install -y \
    zenity \
    sysstat \
    lm-sensors \
    smartmontools \
    alsa-utils \
    nvidia-utils-535 \
    radeontop \
    intel-gpu-tools \
    bc \
    xdg-utils \
    dbus-x11 \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY smt_gui.sh .

RUN chmod +x smt_gui.sh


CMD ["./smt_gui.sh"]
