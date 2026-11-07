#!/usr/bin/env bash

set -o errexit
set -o nounset


LIBNAME="${1:-support}"
LIVERSION="${2:-0.3.0}"
BASEURL='https://github.com/bats-core'
DESTDIR="${BATS_LIBS_DEST_DIR:-/usr/lib/bats}"
BATS_LIBS_TMPDIR=

cleanup() {
    local status=${1:-$?}
    trap - ERR EXIT INT TERM
    test -z "${BATS_LIBS_TMPDIR}" || test ! -d "${BATS_LIBS_TMPDIR}" || rm -rf "${BATS_LIBS_TMPDIR}"
    exit "$status"
}

trap 'cleanup $?' ERR EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

BATS_LIBS_TMPDIR=$(mktemp -d -t bats-libs-XXXXXX)
TMPDIR=$BATS_LIBS_TMPDIR
USAGE="Please provide the bats lib name and version \nFor example: install_libs.sh support 2.0.0\n"

[[ $# -ne 2 ]] && { _log FATAL "$USAGE"; exit 1; }

_log() {
    printf "$(date "+%Y-%m-%d %H:%M:%S") - %s - %s\n" "${1}" "${2}"
}

create_temp_dirs() {
    mkdir -p "${TMPDIR}/${1}"
    if [[ ${LIBNAME} != "detik" ]]; then
        mkdir -p "${DESTDIR}/bats-${1}/src"
    else
        _log INFO "Skipping src 'cause Detik does not need it"
    fi
}

download_extract_source() {
    wget -qO- ${BASEURL}/bats-"${1}"/archive/refs/tags/v"${2}".tar.gz | tar xz -C "${TMPDIR}/${1}" --strip-components 1
}

install_files() {
    if [[ ${LIBNAME} != "detik" ]]; then
        install -Dm755 "${TMPDIR}/${1}/load.bash" "${DESTDIR}/bats-${1}/load.bash"
        for fn in "${TMPDIR}/${1}/src/"*.bash; do install -Dm755 "$fn" "${DESTDIR}/bats-${1}/src/$(basename "$fn")"; done
    else
        for fn in "${TMPDIR}/${1}/lib/"*.bash; do install -Dm755 "$fn" "${DESTDIR}/bats-${1}/$(basename "$fn")"; done
    fi
}

_log INFO "Starting to install ${LIBNAME} ver ${LIVERSION}"
_log INFO "Creating directories"
create_temp_dirs "${LIBNAME}"
_log INFO "Downloading"
download_extract_source "${LIBNAME}" "${LIVERSION}"
_log INFO "Installation"
install_files "${LIBNAME}"
_log INFO "Done, cleaning.."
