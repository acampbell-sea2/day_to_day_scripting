fi

section 'PHYSICAL PCI-BACKED NETWORK INTERFACES'
physical_count=0
for net_path in /sys/class/net/*; do
    [[ -e "$net_path/device" ]] || continue
    iface=${net_path##*/}
    pci=$(basename "$(readlink -f "$net_path/device")")
    [[ "$pci" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[[:xdigit:]]+$ ]] || continue
    physical_count=$((physical_count + 1))

    driver="N/A"; firmware="N/A"; driver_pci=""
    if have ethtool; then
        nic_info=$(ethtool -i "$iface" 2>/dev/null) || nic_info=""
        [[ -n "$nic_info" ]] && {
            driver=$(printf '%s\n' "$nic_info" | field 'driver')
            firmware=$(printf '%s\n' "$nic_info" | field 'firmware-version')
            driver_pci=$(printf '%s\n' "$nic_info" | field 'bus-info')
        }
    fi

    permanent="N/A"
    if have ethtool; then
        perm_data=$(ethtool -P "$iface" 2>/dev/null) || perm_data=""
        [[ -n "$perm_data" ]] && permanent=${perm_data#*: }
    fi
    master="N/A"
    if [[ -e "$net_path/master" ]]; then
        master=$(basename "$(readlink -f "$net_path/master")")
    fi
    speed=$(val_or_na "$net_path/speed")
    [[ "$speed" =~ ^[0-9]+$ ]] || speed="N/A"
    carrier=$(val_or_na "$net_path/carrier")
    case "$carrier" in
        1) carrier='UP (1)' ;;
        0) carrier='DOWN (0)' ;;
    esac

    printf '\nInterface:       %s\n' "$iface"
    printf '  PCI address:    %s\n' "$pci"
    printf '  PCI path:       %s\n' "$(readlink -f "$net_path/device")"
    printf '  Chassis slot:   %s\n' "$(slot_for_pci "$pci")"
    printf '  Physical port:  %s\n' "$(val_or_na "$net_path/phys_port_name")"
    printf '  dev_port:       %s\n' "$(val_or_na "$net_path/dev_port")"
    printf '  PCI device:     %s\n' "$(pci_description "$pci")"
    printf '  Driver:         %s\n' "${driver:-N/A}"
    printf '  Firmware:       %s\n' "${firmware:-N/A}"
    if [[ -n "$driver_pci" && "$driver_pci" != "$pci" ]]; then
        printf '  Driver bus-info:%s (differs from sysfs!)\n' "$driver_pci"
    fi
    printf '  State:          %s\n' "$(val_or_na "$net_path/operstate")"
    printf '  Carrier:        %s\n' "$carrier"
    printf '  Speed (Mb/s):   %s\n' "$speed"
    printf '  Current MAC:    %s\n' "$(val_or_na "$net_path/address")"
    printf '  Permanent MAC:  %s\n' "$permanent"
    printf '  Master:         %s\n' "$master"

    if (( SHOW_OPTICS )); then
        print_optics "$iface"
    fi

    if (( SHOW_FULL )); then
        printf '\n--- ethtool -i %s ---\n' "$iface"
        if have ethtool; then ethtool -i "$iface" 2>&1 || true; else echo 'N/A'; fi
        printf '\n--- ethtool %s (link settings) ---\n' "$iface"
        if have ethtool; then ethtool "$iface" 2>&1 || true; else echo 'N/A'; fi
        printf '\n--- ethtool -P %s ---\n' "$iface"
        if have ethtool; then ethtool -P "$iface" 2>&1 || true; else echo 'N/A'; fi
        printf '\n--- lspci -D -s %s -vv ---\n' "$pci"
        if have lspci; then lspci -D -s "$pci" -vv 2>&1 || true; else echo 'N/A'; fi
    fi
done
if (( physical_count == 0 )); then
    echo 'No physical PCI-backed network interfaces found.'
fi

section 'LINUX BONDS'
found_bond=0
for bond_file in /proc/net/bonding/*; do
    [[ -f "$bond_file" ]] || continue
    found_bond=1
    printf '\n--- %s ---\n' "$bond_file"
    cat "$bond_file" 2>&1 || true
done
if (( found_bond == 0 )); then
    echo 'No /proc/net/bonding entries found.'
fi

if (( SHOW_FULL )); then
    section 'RAW ip -d link show'
    if have ip; then ip -d link show 2>&1 || true; else echo 'N/A'; fi
    section 'RAW dmidecode -t 9'
    if have dmidecode; then dmidecode -t 9 2>&1 || true; else echo 'N/A'; fi
fi

section 'NOTES'
echo 'Current and permanent MAC addresses can differ on bonded NICs.'
echo 'SMBIOS slot mapping depends on firmware and might reference an upstream bridge.'
echo 'A carrier UP state confirms physical link, not successful bond failover.'
echo 'Verify the chassis serial number against the actual server label before tracing cables.'
echo 'Virtual interfaces do not have their own PCIe slot; follow their master or parent device.'
echo 'This report does not change interfaces, link settings, bonds, or switch configuration.'
echo 'Review serial numbers and MAC addresses before sharing reports publicly.'
