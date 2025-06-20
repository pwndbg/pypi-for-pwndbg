import subprocess
import tempfile
import os
import shutil
import pytest
import pathlib
import sys
import platform

here = pathlib.Path(__file__).parent.resolve()

images = {
    "debian-like": [
        "ubuntu:22.04",
        "ubuntu:24.04",
        "ubuntu:24.10",
        "ubuntu:25.04",
        "ubuntu:25.10",
        "debian:12",
        "kalilinux/kali-rolling",
    ],
    "rhel-like": [
        "almalinux:10",
        "rockylinux/rockylinux:10",
        "fedora:41",
        "fedora:42",
        "fedora:43",
        "fedora:latest",
    ],
    "archlinux": [
        "archlinux:latest",
    ]
}

dockerfile_map = {
    "debian-like": "Dockerfile.debian-like",
    "rhel-like": "Dockerfile.rhel-like",
    "archlinux": "Dockerfile.archlinux"
}

script_content = """#!/usr/bin/env bash
set -e

python3 -m venv .venv
. .venv/bin/activate

pip install gdb-for-pwndbg
gdb -ex 'exit'

pip install lldb-for-pwndbg
lldb -o 'script print("python", None)' -o 'quit'
"""

def build_and_test(distro_type, image):
    tag = f"test-{image.replace(':', '-').replace('/', '-')}"
    dockerfile = here / dockerfile_map[distro_type]

    with tempfile.TemporaryDirectory() as tmpdir:
        # Build Docker image
        try:
            subprocess.run([
                "docker", "build",
                "--build-arg", f"image={image}",
                "-f", str(dockerfile),
                "-t", tag, tmpdir
            ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError as e:
            is_platform_not_supported = (
                b"no match for platform in manifest: not found" in e.stderr
                or b"ERROR: failed to solve: failed to read dockerfile: no local sources enabled" in e.stderr
            )
            if is_platform_not_supported:
                pytest.xfail(reason=f"{image} is not supported on {platform.machine()}")
                return

            print(e.stdout.decode())
            print(e.stderr.decode(), file=sys.stderr)
            raise e

        # Write script.sh
        script_path = os.path.join(tmpdir, "script.sh")
        with open(script_path, "w") as f:
            f.write(script_content)
        os.chmod(script_path, 0o755)

        # Run container with mounted script
        subprocess.run([
            "docker", "run", "--rm",
            "-v", f"{script_path}:/test.sh",
            tag,
            "bash", "/test.sh"
        ], check=True)


params = [(dt, img) for dt, imgs in images.items() for img in imgs]

@pytest.mark.parametrize("distro_type,image", params)
def test_docker_images(distro_type, image):
    build_and_test(distro_type, image)


# how to run:
# pytest -vvv tests/test_images.py
