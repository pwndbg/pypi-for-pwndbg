# syntax=docker/dockerfile:1.4
FROM centos:centos7 as glibc_2_17

RUN yum update -y
RUN yum install -y epel-release
RUN yum install -y python3 python3-devel python3-pip make gcc pkg-config zlib zlib-devel openssl openssl-devel readline readline-devel ncurses ncurses-devel bzip2 bzip2-devel libffi libffi-devel sqlite sqlite-devel xz xz-devel
RUN yum install -y gmp gmp-devel mpfr mpfr-devel expat expat-devel libzstd libzstd-devel diffutils
RUN yum install -y patchelf wget tar binutils gcc-c++ git
RUN yum install -y texinfo
#RUN yum install -y openssl11-devel openssl11-lib

FROM almalinux:8 as glibc_2_28

RUN dnf update -y
RUN dnf install -y epel-release
RUN dnf install -y python3 python3-devel python3-pip make gcc pkg-config zlib zlib-devel openssl openssl-devel readline readline-devel ncurses ncurses-devel bzip2 bzip2-devel libffi libffi-devel sqlite sqlite-devel xz xz-devel
RUN dnf install -y gmp gmp-devel mpfr mpfr-devel expat expat-devel libzstd libzstd-devel diffutils
RUN dnf install -y patchelf wget tar binutils gcc-c++ git
RUN dnf --enablerepo=powertools install -y texinfo

FROM almalinux:9 as glibc_2_34

RUN dnf update -y
RUN dnf install -y epel-release
RUN dnf install -y python3 python3-devel python3-pip make gcc pkg-config zlib zlib-devel openssl openssl-devel readline readline-devel ncurses ncurses-devel bzip2 bzip2-devel libffi libffi-devel sqlite sqlite-devel xz xz-devel
RUN dnf install -y gmp gmp-devel mpfr mpfr-devel expat expat-devel libzstd libzstd-devel diffutils
RUN dnf install -y patchelf wget tar binutils gcc-c++ git
RUN dnf --enablerepo=crb install -y texinfo

FROM glibc_2_28 as pyall_glibc_2_28

RUN <<EOT bash
  set -ex
  curl https://pyenv.run | bash
  export PATH="/root/.pyenv/bin:$PATH"

  # https://endoflife.date/python
  pyenv install 3.8.19
  pyenv install 3.9.19
  pyenv install 3.10.14
  pyenv install 3.11.8
  pyenv install 3.12.2
EOT

#FROM pyall_glibc_2_28 as final_38
#
#COPY tools/build-gdb.sh .
#RUN ./build-gdb.sh /root/.pyenv/versions/3.8.19/bin/python

#FROM pyall_glibc_2_28 as final_39
#
#COPY tools/build-gdb.sh .
#RUN ./build-gdb.sh /root/.pyenv/versions/3.9.19/bin/python
#
#FROM pyall_glibc_2_28 as final_310
#
#COPY tools/build-gdb.sh .
#RUN ./build-gdb.sh /root/.pyenv/versions/3.10.14/bin/python

FROM pyall_glibc_2_28 as final_311

COPY tools/build-gdb.sh .
RUN ./build-gdb.sh /root/.pyenv/versions/3.11.8/bin/python
#
#FROM pyall_glibc_2_28 as final_312
#
#COPY tools/build-gdb.sh .
#RUN ./build-gdb.sh /root/.pyenv/versions/3.12.2/bin/python
