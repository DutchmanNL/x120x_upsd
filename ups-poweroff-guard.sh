#!/bin/sh
# X120x UPS poweroff guard.
#
# The X120x boards only power the Pi back on via an AC power-restore edge.
# If the system powers off while AC is already present (e.g. power returned
# during the shutdown grace period and the cancel lost the race), no edge
# will ever come and the Pi stays off until the button is pressed.
#
# This script runs at the very end of every poweroff (see
# ups-poweroff-guard.service): if AC power is present at that moment, the
# poweroff is converted into a reboot instead.
#
# GPIO6 is the X120x power-loss-detection pin: high = AC present.
#
# To intentionally power off while AC is present, skip the guard once with:
#   sudo touch /run/ups-poweroff-guard.skip && sudo poweroff
[ -e /run/ups-poweroff-guard.skip ] && exit 0
case "$(pinctrl get 6 2>/dev/null)" in
  *"| hi"*)
    echo "ups-poweroff-guard: AC present at poweroff, rebooting instead" > /dev/kmsg
    systemctl --force reboot
    ;;
esac
exit 0
