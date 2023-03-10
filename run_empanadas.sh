#!/bin/bash
# set -x
# Tested this script on Fedora Workstation 37 and imagefactory installed (dnf install -y imagefactory)

SCRIPT_PATH=`realpath ${BASH_SOURCE[0]}`
SCRIPT_DIR=`dirname $SCRIPT_PATH`

cd ${SCRIPT_DIR}/transfer; wget -c https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.1-x86_64-dvd.iso
cd ${SCRIPT_DIR}/transfer; git clone --branch stable https://github.com/valentin-nasta/oz.git; git clone --branch devel https://github.com/rocky-linux/sig-core-toolkit.git; git clone --branch r9 https://github.com/rocky-linux/kickstarts.git; 
cd ${SCRIPT_DIR}; sudo podman build -t empanadas:latest -f transfer/sig-core-toolkit/iso/empanadas/Containerfile.imagefactory

empanadas() {
  sudo podman run -it --rm \
    -e LIBVIRT_DEFAULT_URI \
    -v /var/run/libvirt/:/var/run/libvirt/ \
    -v /var/lib/imagefactory/:/var/lib/imagefactory/:rw \
    -v ${SCRIPT_DIR}/extra:/extra \
    -v ${SCRIPT_DIR}/sources:/sources \
    -v ${SCRIPT_DIR}/image-version.json:/image-version.json \
    -v ${SCRIPT_DIR}/transfer:/transfer:rw \
    -v ${SCRIPT_DIR}/transfer/oz.cfg:/etc/oz/oz.cfg \
    -v ${SCRIPT_DIR}/transfer/oz/oz/Guest.py:/usr/lib/python3.10/site-packages/oz/Guest.py \
    -v ${SCRIPT_DIR}/transfer/oz/oz/RHEL_9.py:/usr/lib/python3.10/site-packages/oz/RHEL_9.py \
    --network host \
    --name empanadas \
    --security-opt label=disable \
    --privileged --device fuse \
    --expose=6080 \
    empanadas:latest $@
}
empanadas $1
