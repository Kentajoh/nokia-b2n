#!/bin/sh

# These things can be done only of rootfs is writable i.e. is ramdisk.
if [ -w $LXC_ROOTFS_PATH ]; then
    rm $LXC_ROOTFS_PATH/sbin/adbd

    sed -i "/mount_all /d" $LXC_ROOTFS_PATH/init.*.rc
    sed -i "/swapon_all /d" $LXC_ROOTFS_PATH/init.*.rc
    sed -i "/on nonencrypted/d" $LXC_ROOTFS_PATH/init.rc

    # Config snippet scripts
    run-parts /var/lib/lxc/android/pre-start.d || true
fi

# Make sure bind-mount-points are available.
mkdir -p /dev/__properties__ /dev/socket

# Android 10 second-stage init labels the property area before it loads
# SELinux. First-stage init normally loads precompiled_sepolicy; this
# container skips that stage, so load the matching vendor policy here.
# Stay permissive: this policy would otherwise confine the Ubuntu host.
log=/userdata/b2n-sepolicy.log
{
    echo "---- $(date 2>/dev/null || echo undated) ----"
    if [ ! -e /sys/fs/selinux/load ]; then
        mkdir -p /sys/fs/selinux
        mount -t selinuxfs selinuxfs /sys/fs/selinux
        echo "mount selinuxfs: $?"
    else
        echo "selinuxfs already present"
    fi
    policy=/android/vendor/etc/selinux/precompiled_sepolicy
    ls -l "$policy" /sys/fs/selinux/load /sys/fs/selinux/policy 2>&1 || true
    if [ -f "$policy" ] && [ -e /sys/fs/selinux/load ]; then
        # The policy node exists before any policy is loaded, so test a read.
        if dd if=/sys/fs/selinux/policy of=/dev/null bs=1 count=1 2>/dev/null; then
            echo "policy already loaded"
        else
            dd if="$policy" of=/sys/fs/selinux/load bs=1048576
            echo "dd: $?"
            if dd if=/sys/fs/selinux/policy of=/dev/null bs=1 count=1 2>/dev/null; then
                echo "policy readable after load"
                echo "b2n: loaded Android SELinux policy" > /dev/kmsg
            else
                echo "policy still unreadable after load"
                echo "b2n: Android SELinux policy rejected" > /dev/kmsg
            fi
        fi
        echo 0 > /sys/fs/selinux/enforce
        echo "enforce=$(cat /sys/fs/selinux/enforce 2>/dev/null)"
    else
        echo "b2n: Android SELinux policy not loaded" > /dev/kmsg
        echo "policy missing or selinuxfs unavailable"
    fi
} > "$log" 2>&1
