#!/bin/bash
# Conny is a halpful internet connection script for people with no expectations

WIFI_INTERFACE="$(ls /sys/class/net/ | grep ^w)"
WIRED_INTERFACE="$(ls /sys/class/net/ | grep ^e)"
USR="$(who | awk '{print $1}')"
CFG_PATH="/home/$USR/.config"
DEFAULT_WIFI="$(grep ssid $CFG_PATH/wpa_supplicant.conf)"
DEFAULT_IP='192.168.1.111/24'
DEFAULT_ROUTE='192.168.1.1'

echo 'NOTE: Conny only connects, no disconnecting here :)'
echo 'Pinging googles to check for interwebs...' 
ping -q -c2 -W4 www.google.se > /dev/null 2>&1 && echo 'Found interwebs (possibly), exiting' && exit 0

echo -n 'Wifi instead of wired? Y/n: '
read WIFI
test -z "$WIFI" && WIFI=y
case "$WIFI" in
    [Yy])
        MY_INTERFACE="$WIFI_INTERFACE"
        ;;
    [Nn])
        MY_INTERFACE="$WIRED_INTERFACE"
        ;;
    *)
        echo 'FAILPOTATO: Answer must be y or n'
        exit 1
esac

echo "Setting interface $MY_INTERFACE to UP..."
ip link set "$MY_INTERFACE" up

# SSID and WPA
#NOTE Possible patch for bash tab completion in scripts:
# https://stackoverflow.com/questions/4726695/bash-and-readline-tab-completion-in-a-user-input-loop
if echo "$WIFI" | grep -iq y ; then
    echo -en "Enter wpa config name\n'?' for open wifi\ndefault: $DEFAULT_WIFI: "
    read WPA_CONFIG
    if [ -z $WPA_CONFIG ]; then
        echo "Running wpa_supplicant for $WPA_CONFIG..."
        wpa_supplicant -B -D nl80211,wext -i "$WIFI_INTERFACE" -c "$CFG_PATH/wpa_supplicant.conf"
    else
        if [ "$WPA_CONFIG" = "?" ]; then
            echo -n 'Enter SSID of open network: '
            read OPEN_SSID
            echo "Connecting to $OPEN_SSID..."
            iw dev "$WIFI_INTERFACE" connect "$OPEN_SSID" \
                || echo "FAILPOTATO: $WIFI_INTERFACE could not connect to $OPEN_SSID" && exit 1
        else
            # Try wpa_supplicant on everything that stands still long enough
            if [ -e "$CFG_PATH/wpa_$WPA_CONFIG.conf" ]; then
                echo "Running wpa_supplicant for $WPA_CONFIG..."
                wpa_supplicant -B -D nl80211,wext -i "$WIFI_INTERFACE" -c "$CFG_PATH/wpa_$WPA_CONFIG.conf"
            else
                echo "FAILPOTATO: $CFG_PATH/wpa_$WPA_CONFIG.conf might not be valid config file"
                exit 1
            fi
        fi
    fi
fi

# IP address
echo -n "Enter IP address, '1' for default ($DEFAULT_IP), enter for dhcpcd: "
read IP_THINGY
if [ -z "$IP_THINGY" ]; then
    dhcpcd "$MY_INTERFACE"
else
    if [ "$IP_THINGY" = "1" ]; then
        echo "Adding address $DEFAULT_IP and route via $DEFAULT_ROUTE..."
        ip addr add "$DEFAULT_IP" dev "$MY_INTERFACE"
        ip route add default via "$DEFAULT_ROUTE"
    else
        echo "Adding address $IP_THINGY..."
        ip addr add "$IP_THINGY" dev "$MY_INTERFACE" || echo "FAILPOTATO: Could not use address $IP_THINGY" && exit 1
        echo -n "Enter route thingy (default is $DEFAULT_ROUTE): "
        read MY_ROUTE
        echo "Adding route $MY_ROUTE..."
        ip route add default via "$MY_ROUTE" || echo "FAILPOTATO: $MY_ROUTE is wrong route" && exit 1
    fi
fi
