#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

generate_lvm_conf() {
    VGS=$(getargs rd.lvm.vg -d rd_LVM_VG=)
    LVS=$(getargs rd.lvm.lv -d rd_LVM_LV=)

    for VG in $VGS; do
        VOLS="${VOLS:+${VOLS}, } \"$VG\""
    done

    for LV in $LVS; do
        VOLS="${VOLS:+${VOLS}, } \"$LV\""
    done

    {
        echo "activation {"
        echo "    monitoring = 0"
        if [ -n "$VOLS" ]; then
            echo "    auto_activation_volume_list = [ $VOLS ]"
        fi
        echo "}"
    }>>/etc/lvm/lvm.conf
}

[ -d /etc/lvm ] || mkdir -m 0755 -p /etc/lvm

generate_lvm_conf