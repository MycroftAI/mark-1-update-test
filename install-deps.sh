#!/usr/bin/env bash

sudo apt-get update && sudo apt-get install -y \
	wget \
	unzip \
	qemu-user-static \
	binfmt-support \
	kvm \
	bridge-utils \
	systemd-container


