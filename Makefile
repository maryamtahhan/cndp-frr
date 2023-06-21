# SPDX-License-Identifier: BSD-3-Clause

all: xdp docker-image

xdp:
	$(MAKE) -C my-filter-udp-to-xdp

docker-image:
	docker build -t quay.io/mtahhan/cndp-fedora-frr -f docker/Dockerfile .
