#!/usr/bin/env bash

#ubuntu:18.04: ldd (Ubuntu GLIBC 2.27-3ubuntu1.6) 2.27
#ubuntu:20.04: ldd (Ubuntu GLIBC 2.31-0ubuntu9.14) 2.31
#ubuntu:22.04: ldd (Ubuntu GLIBC 2.35-0ubuntu3.6) 2.35
#ubuntu:24.04: ldd (Ubuntu GLIBC 2.39-0ubuntu2) 2.39
#debian:11: ldd (Debian GLIBC 2.31-13+deb11u8) 2.31
#debian:12: ldd (Debian GLIBC 2.36-9+deb12u4) 2.36
#kalilinux/kali-last-release: ldd (Debian GLIBC 2.37-12) 2.37
#alpine:3.16: Version 1.2.3
#alpine:3.17: Version 1.2.3
#alpine:3.18: Version 1.2.4
#alpine:3.19: Version 1.2.4_git20230717
#centos:centos7: ldd (GNU libc) 2.17
#almalinux:8: ldd (GNU libc) 2.28
#almalinux:9: ldd (GNU libc) 2.34
#oraclelinux:9: ldd (GNU libc) 2.34
#rockylinux:9: ldd (GNU libc) 2.34
#fedora:38: ldd (GNU libc) 2.37
#fedora:39: ldd (GNU libc) 2.38
#fedora:40: ldd (GNU libc) 2.39
#fedora:41: ldd (GNU libc) 2.39.9000
#archlinux: ldd (GNU libc) 2.38

for image in ""ubuntu:18.04 ubuntu:20.04 ubuntu:22.04 ubuntu:24.04 debian:11 debian:12 kalilinux/kali-last-release""; do
    echo -n "$image: ";
    docker run --rm -i $image bash -c 'ldd --version 2>&1 | grep -iE "GLIBC|GNU libc|Version"';
done;
for image in ""alpine:3.16 alpine:3.17 alpine:3.18 alpine:3.19""; do
    echo -n "$image: ";
    docker run --rm -i $image sh -c 'ldd --version 2>&1 | grep -iE "GLIBC|GNU libc|Version"';
done;
for image in ""centos:centos7 almalinux:8 almalinux:9 oraclelinux:9 rockylinux:9 fedora:38 fedora:39 fedora:40 fedora:41""; do
    echo -n "$image: ";
    docker run --rm -i $image bash -c 'ldd --version 2>&1 | grep -iE "GLIBC|GNU libc|Version"';
done;
for image in ""archlinux""; do
    echo -n "$image: ";
    docker run --rm -i $image bash -c 'ldd --version 2>&1 | grep -iE "GLIBC|GNU libc|Version"';
done;
