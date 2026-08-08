#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: tools/update-route-config-release.sh [arch]

Download the latest RouterPlane/route-config Debian package release asset,
replace the vendored package under packages/bsp/common/resources, and update
board config references.

Arguments:
  arch    Debian architecture to download. Defaults to arm64.

Environment:
  ROUTE_CONFIG_REPO         GitHub repository. Defaults to RouterPlane/route-config.
  ROUTE_CONFIG_BOARD_FILES  Space-separated board files to rewrite.

Requires:
  gh, dpkg-deb, sha256sum
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

repo="${ROUTE_CONFIG_REPO:-RouterPlane/route-config}"
deb_arch="${1:-${ROUTE_CONFIG_DEB_ARCH:-arm64}}"

case "${deb_arch}" in
	*[!A-Za-z0-9.+-]* | "")
		echo "Invalid Debian architecture: ${deb_arch}" >&2
		exit 2
		;;
esac

for tool in gh dpkg-deb sha256sum; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		echo "Missing required tool: ${tool}" >&2
		exit 127
	fi
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
resource_dir="${repo_root}/packages/bsp/common/resources"
board_files_default="config/boards/nanopi-r6s.conf config/boards/photonicat2.csc"
board_files="${ROUTE_CONFIG_BOARD_FILES:-${board_files_default}}"

api_path="repos/${repo}/releases/latest"
tag="$(gh api "${api_path}" --jq '.tag_name')"
asset_name="$(
	gh api "${api_path}" \
		--jq ".assets[].name | select(test(\"^route-config_[^_]+_${deb_arch}\\\\.deb$\"))" |
		head -n 1
)"

if [[ -z "${asset_name}" ]]; then
	echo "No route-config Debian asset found for ${deb_arch} in ${repo} ${tag}" >&2
	exit 1
fi

case "${asset_name}" in
	*[!A-Za-z0-9._+-]*)
		echo "Unexpected asset name from GitHub API: ${asset_name}" >&2
		exit 1
		;;
esac

asset_digest="$(
	gh api "${api_path}" \
		--jq ".assets[] | select(.name == \"${asset_name}\") | .digest" |
		head -n 1
)"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/route-config-release.XXXXXX")"
cleanup() {
	rm -rf -- "${tmpdir}"
}
trap cleanup EXIT

gh release download "${tag}" \
	--repo "${repo}" \
	--pattern "${asset_name}" \
	--dir "${tmpdir}" \
	--clobber

downloaded="${tmpdir}/${asset_name}"
if [[ ! -f "${downloaded}" ]]; then
	echo "Downloaded asset not found: ${downloaded}" >&2
	exit 1
fi

if [[ "${asset_digest}" == sha256:* ]]; then
	expected_sha256="${asset_digest#sha256:}"
	actual_sha256="$(sha256sum "${downloaded}" | awk '{print $1}')"
	if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
		echo "Checksum mismatch for ${asset_name}" >&2
		echo "Expected: ${expected_sha256}" >&2
		echo "Actual:   ${actual_sha256}" >&2
		exit 1
	fi
fi

package_name="$(dpkg-deb -f "${downloaded}" Package)"
package_version="$(dpkg-deb -f "${downloaded}" Version)"
package_arch="$(dpkg-deb -f "${downloaded}" Architecture)"

if [[ "${package_name}" != "route-config" ]]; then
	echo "Unexpected package name in ${asset_name}: ${package_name}" >&2
	exit 1
fi

if [[ "${package_arch}" != "${deb_arch}" ]]; then
	echo "Unexpected package arch in ${asset_name}: ${package_arch}, expected ${deb_arch}" >&2
	exit 1
fi

mkdir -p "${resource_dir}"
cp -f -- "${downloaded}" "${resource_dir}/${asset_name}"

find "${resource_dir}" -maxdepth 1 -type f \
	\( -name "router-config_*_${deb_arch}.deb" -o -name "route-config_*_${deb_arch}.deb" \) \
	! -name "${asset_name}" \
	-delete

for board_file in ${board_files}; do
	board_path="${repo_root}/${board_file}"
	if [[ ! -f "${board_path}" ]]; then
		echo "Skipping missing board file: ${board_file}" >&2
		continue
	fi

	sed -i -E \
		-e "s#packages/bsp/common/resources/(router-config|route-config)_[^\"[:space:]]+_${deb_arch}\\.deb#packages/bsp/common/resources/${asset_name}#g" \
		-e "s#/tmp/(router-config|route-config)_[^\"[:space:]]+_${deb_arch}\\.deb#/tmp/${asset_name}#g" \
		-e "s#Installing router-config package#Installing route-config package#g" \
		-e "s#router-config deb not found#route-config deb not found#g" \
		-e "s#Failed to install router-config \\.deb package#Failed to install route-config .deb package#g" \
		-e "s#router-config package installed successfully#route-config package installed successfully#g" \
		"${board_path}"
done

echo "Updated ${repo} ${tag}"
echo "Package: ${package_name} ${package_version} (${package_arch})"
echo "Vendored: packages/bsp/common/resources/${asset_name}"
