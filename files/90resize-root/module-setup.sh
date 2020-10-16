#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    require_binaries dmsetup      || return 1
    require_binaries parted       || return 1
    require_binaries partprobe    || return 1
    return 0
}

depends() {
    return 0
}

installkernel() {
    return 0
}

install() {
    inst_hook cmdline 99 "$moddir/resize-root-dummy.sh"
    inst_hook pre-mount 99 "$moddir/resize-root.sh"

    inst_multiple e2fsck
    inst_multiple resize2fs
    inst_multiple resize-root
    inst_multiple awk
    inst_multiple bash
    inst_multiple sed
    inst_multiple pidof
    inst_multiple tr
    inst_multiple parted
    inst_multiple partprobe
    inst_multiple fdisk
    inst_multiple partx
    inst_multiple readlink
}
