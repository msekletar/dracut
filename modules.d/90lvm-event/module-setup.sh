#!/bin/bash

# called by dracut
check() {
    # No point trying to support lvm if the binaries are missing
    require_binaries lvm || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in "${host_fs_types[@]}"; do
            [[ $fs = LVM*_member ]] && return 0
        done
        return 255
    }

    return 0
}

# called by dracut
depends() {
    # We depend on dm_mod being loaded
    echo rootfs-block dm systemd
    return 0
}

# called by dracut
cmdline() {
    return 0
}

installkernel() {
    hostonly='' instmods dm-snapshot
}

# called by dracut
install() {
    inst lvm
    inst_rules 11-dm-lvm.rules 69-dm-lvm-metad.rules
    inst $systemdsystemunitdir/lvm2-pvscan@.service
    #FIXME: check if needed
    inst_libdir_file "libdevmapper-event-lvm*.so"


    if [[ $hostonly ]] || [[ $lvmconf = "yes" ]]; then
        if [ -f $dracutsysrootdir/etc/lvm/lvm.conf ]; then
            inst_simple -H /etc/lvm/lvm.conf
            # FIXME use LVM profiles in the future https://bugzilla.redhat.com/show_bug.cgi?id=1134400
            sed -i -e 's/\(^[[:space:]]*\)locking_type[[:space:]]*=[[:space:]]*[[:digit:]]/\1locking_type = 4/' ${initdir}/etc/lvm/lvm.conf
            sed -i -e 's/\(^[[:space:]]*\)event_activation[[:space:]]*=[[:space:]]*[[:digit:]]/\1event_activation = 1/' ${initdir}/etc/lvm/lvm.conf
            # FIXME autoactivation list
        fi

        export LVM_SUPPRESS_FD_WARNINGS=1
        # Also install any files needed for LVM system id support.
        if [ -f $dracutsysrootdir/etc/lvm/lvmlocal.conf ]; then
            inst_simple -H /etc/lvm/lvmlocal.conf
        fi
        eval $(lvm dumpconfig global/system_id_source &>/dev/null)
        if [ "$system_id_source" == "file" ]; then
            eval $(lvm dumpconfig global/system_id_file)
            if [ -f "$system_id_file" ]; then
                inst_simple -H $system_id_file
            fi
        fi
        unset LVM_SUPPRESS_FD_WARNINGS
    fi

    if ! [[ -e ${initdir}/etc/lvm/lvm.conf ]]; then
        mkdir -p "${initdir}/etc/lvm"
        {
            echo 'global {'
            echo 'locking_type = 4'
            echo '}'
        } > "${initdir}/etc/lvm/lvm.conf"
    fi


    if [[ $hostonly ]] && type -P lvs &>/dev/null; then
        for dev in "${!host_fs_types[@]}"; do
            [ -e /sys/block/${dev#/dev/}/dm/name ] || continue
            dev=$(</sys/block/${dev#/dev/}/dm/name)
            eval $(dmsetup splitname --nameprefixes --noheadings --rows "$dev" 2>/dev/null)
            [[ ${DM_VG_NAME} ]] && [[ ${DM_LV_NAME} ]] || continue
            case "$(lvs --noheadings -o segtype ${DM_VG_NAME} 2>/dev/null)" in
                *thin*|*cache*|*era*)
                    inst_multiple -o thin_dump thin_restore thin_check thin_repair \
                                  cache_dump cache_restore cache_check cache_repair \
                                  era_check era_dump era_invalidate era_restore
                    break;;
            esac
        done
    fi

    if ! [[ $hostonly ]]; then
        inst_multiple -o thin_dump thin_restore thin_check thin_repair \
                      cache_dump cache_restore cache_check cache_repair \
                      era_check era_dump era_invalidate era_restore
    fi
}
