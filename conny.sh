#!/bin/bash
# Conny is a halpful internet connection script for people with no expectations

WIFI_INTERFACE="$(ls /sys/class/net/ | grep ^w)"
WIRED_INTERFACE="$(ls /sys/class/net/ | grep ^e)"
USR="$(who | awk '{print $1}')"

CONNY_CFG_FILE="/home/$USR/.config/conny.conf"
DEFAULT_WIFI="$(grep ssid $CFG_PATH/wpa_supplicant.conf)"

# Config file comes to the rescue!
DEFCON_METHOD="$(grep '^DEFCON_METHOD' $CONNY_CFG_FILE 2>/dev/null | awk -F'=' '{print $2}')"
DEF_CFG_PATH="$(grep '^DEF_CFG_PATH' $CONNY_CFG_FILE 2>/dev/null | awk -F'=' '{print $2}')"
DEFAULT_TO_DHCP="$(grep '^DEFAULT_TO_DHCP' $CONNY_CFG_FILE 2>/dev/null | awk -F'=' '{print $2}')"
DEFAULT_IP="$(grep '^DEFAULT_IP' $CONNY_CFG_FILE 2>/dev/null | awk -F'=' '{print $2}')"
DEFAULT_ROUTE="$(grep '^DEFAULT_ROUTE' $CONNY_CFG_FILE 2>/dev/null | awk -F'=' '{print $2}')"

# Test that config values exist
if [ -z $DEFCON_METHOD ]; then
    DEFCON_METHOD='wifi'
fi
case $DEFCON_METHOD in
    wired|wifi) 
        ;;
    *)
        echo 'FAILPOTATO: Incorrect connection method in config'
        exit 1
        ;;
esac

if [ -z $DEFAULT_TO_DHCP ]; then
    DEFCON_METHOD='1'
fi
case $DEFCON_METHOD in
    [01]) 
        ;;
    *)
        echo 'FAILPOTATO: Incorrect thoughts about dhcp in config'
        exit 1
        ;;
esac

# Old hardcoded default values
#CFG_PATH="/home/$USR/.config"
#DEFAULT_IP='192.168.1.222/24'
#DEFAULT_ROUTE='192.168.1.1'

echo "Testing DHCP: $DEFAULT_TO_DHCP"
echo "Testing IP: $DEFAULT_IP"
echo "Testing route: $DEFAULT_ROUTE"
echo "Testing cfg path: $DEF_CFG_PATH"

echo 'NOTE: Conny only connects, no disconnecting here :)'
echo 'Pinging googles to check for interwebs...' 
ping -q -c2 -W4 www.google.se > /dev/null 2>&1 && echo 'Found interwebs (possibly), exiting' && exit 0

echo -n "Use $DEFCON_METHOD? Y/n: "
read USE_DEFCON_METHOD
test -z "$USE_DEFCON_METHOD" && USE_DEFCON_METHOD=y
case "$USE_DEFCON_METHOD" in
    [Yy])
        if [ "$DEFCON_METHOD"="wifi" ]; then
            MY_INTERFACE="$WIFI_INTERFACE"
        else
            MY_INTERFACE="$WIRED_INTERFACE"
        fi
        ;;
    [Nn])
        if [ "$DEFCON_METHOD"="wired" ]; then
            MY_INTERFACE="$WIRED_INTERFACE"
        else
            MY_INTERFACE="$WIFI_INTERFACE"
        fi
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
if [ "$MY_INTERFACE"="$WIFI_INTERFACE" ] ; then
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
if [ "$DEFAULT_TO_DHCP" = "1" ]; then
    echo -n "Enter IP address, '1' for default ($DEFAULT_IP), 'enter' for dhcpcd: "
else
    echo -n "Enter IP address, 'enter' for default ($DEFAULT_IP), '1' for dhcpcd: "
fi
read IP_THINGY
if [ -z "$IP_THINGY" -a "$DEFAULT_TO_DHCP" = "1" ] || [ "$IP_THINGY" = "1" -a "$DEFAULT_TO_DHCP" = "0" ]; then
    dhcpcd "$MY_INTERFACE"
else
    if [ "$IP_THINGY" = "1" -a "$DEFAULT_TO_DHCP" = "1" ] || [ -z "$IP_THINGY" -a "$DEFAULT_TO_DHCP" = "0" ]; then
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
