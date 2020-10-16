#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Environment variables that this script relies upon:
# - root

_info () {
    echo "resize-root: $*"
}

_warning () {
    echo "resize-root Warning: $*" >&2
}

# This will drop us into an emergency shell
_fatal () {
    echo "resize-root Fatal: $*" >&2
    exit 1
}

_resizeRoot () {
    # Remove 'block:' prefix and find the root device
    # shellcheck disable=SC2154
    rootdev=$(readlink -f "${root#block:}")

    if [ -z "${rootdev}" ] ; then
        _warning "unable to find root device"
        return
    fi

    # If the basename of the root device (ie 'xvda1', 'sda1', 'vda') exists
    # in /sys/block/ then it is a block device, not a partition
    if [ -e "/sys/block/${rootdev##*/}" ] ; then
        _info "${rootdev} is not a partition"
        return
    fi

    # Check if the root device is a partition (name ends with a digit)
    if [ "${rootdev%[0-9]}" = "${rootdev}" ] ; then
        _warning "${rootdev} is not a partition"
        return
    fi

    # Remove all numbers from the end of rootdev to get the rootdisk and
    # partition number
    rootdisk=${rootdev}
    while [ "${rootdisk%[0-9]}" != "${rootdisk}" ] ; do
        rootdisk=${rootdisk%[0-9]}
    done
    partnum=${rootdev#${rootdisk}}

    # Check if we need to strip a trailing 'p' from the rootdisk name (for
    # device names like /dev/mmcblk0p)
    tmp=${rootdisk%[0-9]p}
    if [ "${#tmp}" != "${#rootdisk}" ] ; then
        rootdisk=${rootdisk%p}
    fi

    # Do a resize-root dry run and exit if it fails or doesn't have anything
    # to do
    # if ! out=$(resize-root --dry-run "${rootdisk}" "${partnum}") ; then
    #     _info "${out}"
    #     return
    # fi

    # Wait for any of the initial udev events to finish otherwise resize-root
    # might fail
    # udevadm settle --timeout=30

    # Resize the root partition
    while true
    do
        if [[ ! -z "$(pidof systemd-fsck)" ]]
        then
            sleep 1
        elif [[ ! -z "$(pidof fsck)" ]]
        then
            sleep 1
        elif [[ ! -z "$(pidof fsck.ext4)" ]]
        then
            sleep 1
        else
            /usr/sbin/resize-root "${rootdisk}" "${partnum}" >&2 || true
            # Wait for the partition re-read events to complete so that the root
            # partition is available for mounting
            udevadm settle --timeout=30

            # Add the root partition if it didn't come back on its own
            if ! [ -e "${rootdev}" ] ; then
                partx --add --nr "${partnum}" "${rootdisk}" || \
                    _warning "failed to add root device ${rootdev}"
                udevadm settle --timeout=30 || true
            fi

            break
        fi
    done
}

_resizeRoot

# vi: ts=4 expandtab
