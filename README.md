# WireguardNamespace

<p align="center">
  <img src="https://raw.githubusercontent.com/DavyJonesCodes/WireguardNamespace/main/assets/logo.png" alt="Logo" height="128px">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
  <img src="https://img.shields.io/github/license/DavyJonesCodes/WireguardNamespace?style=for-the-badge"/>
</p>

**WireguardNamespace** is a standalone Bash script for setting up isolated Linux network namespaces with optional WireGuard VPN routing. It's ideal for sandboxing applications, routing specific programs through VPNs, or testing in a clean network environment.

---

## ✨ Features

- 🧱 **Namespace Isolation**: Create isolated network spaces for apps or testing.
- 🔐 **WireGuard Support**: Automatically connects VPN via `wg-quick` (if enabled).
- 🧹 **Clean Teardown**: Easily delete namespace, interfaces, and routing rules.
- 🏷️ **Custom Naming**: Use `--name <namespace>` to manage multiple namespaces.
- 🚫 **VPN Optional**: Use `--no-vpn` for direct internet access without tunneling.

---

## 🚀 Usage

```bash
sudo ./WireguardNamespace.sh [--name <namespace>] [interface] [--no-vpn] [--teardown]
````

### Arguments

| Option       | Description                                                      |
| ------------ | ---------------------------------------------------------------- |
| `--name`     | Set custom namespace name (default: `vpnspace`)                  |
| `--no-vpn`   | Skip VPN setup (provides regular internet in namespace)          |
| `--teardown` | Remove namespace, veth, and NAT rules                            |
| `interface`  | Network interface to use (e.g. `eth0`). Auto-selected if omitted |

---

### ✅ Examples

```bash
# Default setup with VPN
sudo ./WireguardNamespace.sh

# Create isolated namespace without VPN
sudo ./WireguardNamespace.sh --no-vpn

# Create a custom namespace called 'research'
sudo ./WireguardNamespace.sh --name research

# Teardown custom namespace
sudo ./WireguardNamespace.sh --name research --teardown
```

---

## 📦 Requirements

* Linux with:

  * `ip`, `iptables`, `wg-quick`, `curl`, `jq`
* A valid WireGuard config (default path is `/etc/wireguard/wg0.conf`)
* Root privileges (`sudo`)

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

---

## 🤝 Contributing

Want to improve this script or add new features? Feel free to fork and submit a pull request. Ideas and suggestions welcome!

---

## 📬 Support

Open an issue or email [devjonescodes@gmail.com](mailto:devjonescodes@gmail.com) if you need help or want to collaborate.
