#!/usr/bin/env bash
set -euo pipefail

SWAPFILE_PATH="/swapfile"
SWAPFILE_SIZE_MB=8192
MIN_FREE_MB=1024

[[ -f /etc/default/photonicat2-swapfile ]] && . /etc/default/photonicat2-swapfile

if swapon --show=NAME --noheadings | grep -Fxq "${SWAPFILE_PATH}"; then
	exit 0
fi

if [[ ! -f "${SWAPFILE_PATH}" ]]; then
	swap_base=$(dirname "${SWAPFILE_PATH}")
	free_mb=$(df -Pm "${swap_base}" | awk 'NR==2 { print $4 }')
	needed_mb=$((SWAPFILE_SIZE_MB + MIN_FREE_MB))

	if (( free_mb < needed_mb )); then
		echo "Not enough free space in ${swap_base} for ${SWAPFILE_SIZE_MB}MiB swapfile" >&2
		exit 1
	fi

	if ! fallocate -l "${SWAPFILE_SIZE_MB}M" "${SWAPFILE_PATH}"; then
		dd if=/dev/zero of="${SWAPFILE_PATH}" bs=1M count="${SWAPFILE_SIZE_MB}" status=progress
	fi

	chmod 600 "${SWAPFILE_PATH}"
	mkswap "${SWAPFILE_PATH}"
fi

if ! grep -Eq "^${SWAPFILE_PATH}[[:space:]]+none[[:space:]]+swap[[:space:]]" /etc/fstab; then
	echo "${SWAPFILE_PATH} none swap defaults,nofail,discard=once,pri=0 0 0" >> /etc/fstab
fi

swapon -p 0 "${SWAPFILE_PATH}"
