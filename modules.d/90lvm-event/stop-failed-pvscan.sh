#!/bin/sh

# We want to retrigger possibly failed lvm2-pvscan@.service instances after
# switchroot. Failed instances of pvscan may appear if we are missing
# rd.lvm.lv and rd.lvm.vg options, we then don't generate
# auto_activation_volume_list= and hence we try to activate all volume groups.
# However, we may have initrd image that is missing required kernel modules to
# activate those volume groups (e.g. we are missing to activate raid5).
stop_failed_pvscan() {
    for i in $(systemctl --no-pager --no-legend --type=service --state=failed list-units | grep -o -E '\blvm2-pvscan.*\.service\b'); do
        systemctl stop "$i"
    done
}

stop_failed_pvscan