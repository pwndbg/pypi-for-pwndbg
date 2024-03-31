#!/usr/bin/env bash

#ubuntu:20.04: -lcrypt -lpthread -ldl -lutil -lm -lpython3.8
#ubuntu:22.04: -lcrypt -ldl -lm -lpython3.10
#ubuntu:24.04: -lpython3.12 -ldl
#debian:11: -lcrypt -lpthread -ldl -lutil -lm -lpython3.9
#debian:12: -lpython3.11 -ldl
#kalilinux/kali-last-release: -lpython3.11 -ldl
#alpine:3.16: -lpython3.10 -ldl -lm
#alpine:3.17: -lpython3.10 -ldl -lm
#alpine:3.18: -lpython3.11 -ldl
#alpine:3.19: -lpython3.11 -ldl
#almalinux:9: -lpython3.9 -lcrypt -ldl -lm
#oraclelinux:9: -lpython3.9 -lcrypt -ldl -lm
#rockylinux:9: -lpython3.9 -lcrypt -ldl -lm
#fedora:38: -lpython3.11 -ldl
#fedora:39: -lpython3.12 -ldl
#fedora:40: -lpython3.12 -ldl
#fedora:41: -lpython3.12 -ldl
#archlinux: -lpython3.11 -ldl

for image in ""ubuntu:20.04 ubuntu:22.04 ubuntu:24.04 debian:11 debian:12 kalilinux/kali-last-release""; do
    echo -n "$image: ";
    docker run --rm -i $image bash -c 'export DEBIAN_FRONTEND=noninteractive; apt update -y &> /dev/null; apt install -y python3 python3-dev pkg-config &> /dev/null; pkg-config --libs --static python3-embed';
done;
for image in ""alpine:3.16 alpine:3.17 alpine:3.18 alpine:3.19""; do
    echo -n "$image: ";
    docker run --rm -i $image sh -c 'apk add python3 python3-dev pkgconfig &> /dev/null; pkg-config --libs --static python3-embed';
done;
for image in ""almalinux:9 oraclelinux:9 rockylinux:9 fedora:38 fedora:39 fedora:40 fedora:41""; do
    echo -n "$image: ";
    docker run --rm -i $image bash -c 'dnf install python3 python3-devel pkg-config -y &> /dev/null; pkg-config --libs --static python3-embed';
done;
for image in ""archlinux""; do
    echo -n "$image: ";
    docker run --rm -i $image bash -c 'pacman --noconfirm -Sy python3 pkg-config &> /dev/null; pkg-config --libs --static python3-embed';
done;
