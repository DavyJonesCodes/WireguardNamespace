#!/usr/bin/env bash

# ==========================================================
# vpn_namespace_setup.sh
# ----------------------------------------------------------
# Author: DavyJonesCodes
# GitHub: https://github.com/DavyJonesCodes
# License: MIT
#
# Description:
#   Sets up a Linux network namespace with internet access,
#   optionally routed through WireGuard VPN.
#
# Usage:
#   sudo ./vpn_namespace_setup.sh [--name <namespace>] [interface] [--no-vpn] [--teardown]
#
#   --name        Custom name for the namespace (default: vpnspace)
#   interface     Optional: network interface to use (e.g., eth0)
#   --no-vpn      Optional: skip WireGuard and provide direct internet
#   --teardown    Optional: remove the namespace and clean up
# ==========================================================

# -------- Configuration (Default Values) --------
NS="vpnspace"
VETH="vpn-veth"
VPEER="vpn-peer"
VETH_ADDR="10.200.1.1"
VPEER_ADDR="10.200.1.2"
DEFAULT_ROUTE="10.200.1.1"
WG_CONFIG="/etc/wireguard/jp-osa-wg-001.conf"

# -------- Parse Arguments --------
SKIP_VPN=false
TEARDOWN=false
CUSTOM_IFACE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-vpn)
            SKIP_VPN=true
            shift
            ;;
        --teardown)
            TEARDOWN=true
            shift
            ;;
        --name)
            NS="$2"
            VETH="${NS}-veth"
            VPEER="${NS}-peer"
            shift 2
            ;;
        *)
            CUSTOM_IFACE="$1"
            shift
            ;;
    esac
done

# -------- Root Check --------
if [[ $EUID -ne 0 ]]; then
    echo -e "❌  This script must be run as root."
    exit 1
fi

# -------- Teardown Function --------
teardown_namespace() {
    echo -e "🧹  Tearing down namespace '${NS}'..."

    ip netns del "$NS" &>/dev/null
    ip link del "$VETH" &>/dev/null

    iptables -t nat -D POSTROUTING -s ${VPEER_ADDR}/24 -o "$CUSTOM_IFACE" -j MASQUERADE 2>/dev/null
    iptables -D FORWARD -i "$CUSTOM_IFACE" -o "$VETH" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -o "$CUSTOM_IFACE" -i "$VETH" -j ACCEPT 2>/dev/null

    echo -e "✅  Namespace and interfaces cleaned up."
    exit 0
}

# -------- If Teardown Requested --------
if [[ "$TEARDOWN" == true ]]; then
    teardown_namespace
fi

# -------- WireGuard Config Check --------
if [[ "$SKIP_VPN" == false && ! -f "$WG_CONFIG" ]]; then
    echo -e "❌  WireGuard config not found at: $WG_CONFIG"
    exit 1
fi

# -------- Interface Utilities --------
check_interface_exists() { ip link show "$1" &>/dev/null; }

check_interface() {
    [[ "$(ip link show "$1")" =~ "state UP" ]] && ping -I "$1" -c 1 -W 1 8.8.8.8 &>/dev/null
}

find_valid_interface() {
    for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
        [[ "$iface" != "lo" && "$iface" != veth* ]] && check_interface "$iface" && echo "$iface" && return
    done
    echo -e "❌  No working network interfaces found."
    exit 1
}

# -------- Determine Interface --------
IFACE="$CUSTOM_IFACE"
if [[ -z "$IFACE" ]]; then
    IFACE=$(find_valid_interface)
    echo -e "🔍  Auto-selected interface: $IFACE"
else
    if ! check_interface_exists "$IFACE"; then
        echo -e "❌  The specified interface '$IFACE' does not exist."
        exit 1
    fi
    if ! check_interface "$IFACE"; then
        echo -e "❌  The interface '$IFACE' is down or has no internet."
        exit 1
    fi
    echo -e "🔌  Using specified interface: $IFACE"
fi

# -------- DNS Setup --------
update_resolv_conf() {
    cp /etc/resolv.conf /etc/resolv.conf.bak
    for dns in 8.8.8.8 8.8.4.4 1.1.1.1; do
        grep -q "$dns" /etc/resolv.conf || echo "nameserver $dns" >> /etc/resolv.conf
    done
    echo -e "📡  DNS resolvers updated."
}

# -------- WireGuard Setup --------
connect_wireguard() {
    ip netns exec ${NS} wg-quick up ${WG_CONFIG} &>/dev/null
    echo -e "🔐  WireGuard connected inside namespace."
}

# -------- Namespace & Veth Setup --------
create_namespace() {
    ip netns del ${NS} &>/dev/null
    ip netns add ${NS}

    ip link add ${VETH} type veth peer name ${VPEER}
    ip link set ${VPEER} netns ${NS}

    ip addr add ${VETH_ADDR}/24 dev ${VETH}
    ip link set ${VETH} up

    ip netns exec ${NS} ip addr add ${VPEER_ADDR}/24 dev ${VPEER}
    ip netns exec ${NS} ip link set ${VPEER} up
    ip netns exec ${NS} ip link set lo up
    ip netns exec ${NS} ip route add default via ${DEFAULT_ROUTE}

    echo -e "🌐  Namespace '${NS}' created with virtual interfaces."
}

# -------- NAT & Forwarding --------
configure_forwarding() {
    echo 1 > /proc/sys/net/ipv4/ip_forward

    iptables -P FORWARD DROP
    iptables -F FORWARD
    iptables -t nat -F

    iptables -t nat -A POSTROUTING -s ${VPEER_ADDR}/24 -o "$IFACE" -j MASQUERADE
    iptables -A FORWARD -i "$IFACE" -o "$VETH" -j ACCEPT
    iptables -A FORWARD -o "$IFACE" -i "$VETH" -j ACCEPT

    echo -e "🛡️  IP forwarding and iptables configured."
}

# -------- IP Info (Namespace) --------
make_request_in_namespace() {
    ip netns exec ${NS} curl -s ipinfo.io | jq -r '
        "\n🌍  IP Information (Namespace):\n-------------------------------",
        "IP Address: \(.ip)",
        "Country:    \(.country)",
        "City:       \(.city)",
        "Region:     \(.region)"'
    echo
}

# -------- IP Info (Host) --------
make_request_from_host() {
    curl -s ipinfo.io | jq -r '
        "🌍  IP Information (Host):\n--------------------------",
        "IP Address: \(.ip)",
        "Country:    \(.country)",
        "City:       \(.city)",
        "Region:     \(.region)"'
    echo
}

# -------- Setup Sequence --------
setup_network() {
    ip link show "${VETH}" &>/dev/null && ip link delete ${VETH}
    ip link show "${VPEER}" &>/dev/null && ip link delete ${VPEER}

    create_namespace
    configure_forwarding

    if [[ "$SKIP_VPN" == false ]]; then
        connect_wireguard
    else
        echo -e "🚫  VPN setup skipped (namespace will use direct internet)."
    fi

    update_resolv_conf
}

# -------- Execute --------
setup_network
make_request_in_namespace
make_request_from_host

# -------- Final Summary --------
echo -e "🎉  Namespace '${NS}' is ready.\n"
echo "📄  Network Interface Summary"
echo "────────────────────────────────────────"
printf "🌐  %-20s → %s\n" "Host Interface"      "${VETH} (${VETH_ADDR})"
printf "🛰️   %-20s → %s\n" "Namespace Interface" "${VPEER} (${VPEER_ADDR})"
echo
