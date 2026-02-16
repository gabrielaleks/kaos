# Tailscale
Tailscale is a VPN service that makes devices on different networks behave as if they’re on the same local network. It uses WireGuard under the hood to create secure, encrypted connections between all of my devices, forming what’s called a “tailnet.” This means my laptops, phones, Raspberry Pi, and any other machines can communicate privately and securely, even if they’re on completely different networks or behind NATs and firewalls. Tailscale handles all the complicated networking automatically, including NAT traversal and key management, so I don’t have to configure port forwarding or VPN servers manually.

In my homelab, Tailscale is incredibly useful because it allows me to access my services from anywhere without exposing them to the public internet. For example, I can reach my Pi-hole, Portainer, or self-hosted apps on my Raspberry Pi using consistent internal domain names like *.kaoshome.dev, even when I’m on mobile data or at a coffee shop. It also integrates nicely with Pi-hole because I can use dnsmasq rules like address=/.kaoshome.dev/<raspberry-tailscale-ip> to force all my internal domains to resolve to my Pi’s tailnet IP.

Setting up Tailscale is straightforward. On my personal devices (laptop, phone, tablet), I simply install the Tailscale app and log in with my account. Each device automatically joins my tailnet and gets a unique Tailscale IP. On my Raspberry Pi, I install the Tailscale package:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

After authenticating, my Raspberry Pi becomes part of my tailnet. I can now ping it, SSH into it, or access my internal services securely from any other device in my Tailscale network. With Tailscale running, I have a private, encrypted network overlay that makes managing and accessing my homelab simple and safe.