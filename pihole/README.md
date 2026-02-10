1. Configure Tailscale global DNS
- Go to Tailscale Admin DNS
- Create a global nameserver using the Raspberry Pi’s Tailscale IP
- Toggle “Override DNS servers” to enable it

Why this matters: This ensures all devices on the Tailnet use Pi-hole as their primary DNS server, so queries for ads, trackers, or local services are filtered consistently. Without overriding, devices might continue using their default ISP or system DNS, bypassing Pi-hole.

Difference from split DNS: Split DNS only affects specific domains, sending other queries elsewhere (like kaos -> 100.x.x.x). Global DNS ensures all domains are routed through Pi-hole, giving full network-wide ad-blocking and custom local domain resolution (like *.kaos).


2. Assign a fixed IP to the Raspberry Pi
Before installing Pi-hole, ensure your Pi has a static IP:
- Either configure it in your router (DHCP reservation)
- Or set a static IP directly on the Pi (/etc/dhcpcd.conf)

This matter because pi-hole needs a consistent IP so that:
- Devices always know where to find the DNS server
- Custom local DNS entries (*.kaos) remain valid
- Traefik and other services relying on Pi-hole DNS don’t break if the Pi’s IP changes

3. Install Pi-hole
To install Pi-hole, run this command on the raspberry pi:

```bash
curl -sSL https://install.pi-hole.net | bash
```

Follow the procedure.

4. Configure Pi-hole to allow all origins
- In the Pi-hole dashboard, go to: Settings → DNS → Expert View
- Under Interface settings, choose “Permit all origins”

Why this matters:
- By default, Pi-hole only responds to queries from its own subnet
- Allowing all origins ensures it responds to DNS queries from:
    - Devices on your LAN
    - Devices connected via Tailscale
- This is essential for network-wide and Tailnet-wide DNS filtering

5. Enable Pi-hole to load custom dnsmasq files
Edit /etc/pihole/pihole.toml and set the following:

```bash
etc_dnsmasq_d=true
```

Why this matters:
- Pi-hole’s FTL engine uses dnsmasq internally
- Enabling this allows Pi-hole to read additional dnsmasq configuration files from /etc/dnsmasq.d/
- This is necessary to add custom local domain mappings, like *.kaos, without modifying core Pi-hole files

6. Create custom dnsmasq configuration for *.kaos
Create a file /etc/dnsmasq.d/02-kaos.conf and add:

```bash
address=/.kaos/<raspberry-tailscale-ip>
```

Why this matters:
- This tells Pi-hole to resolve all subdomains of kaos to your Raspberry Pi’s Tailscale IP
- Traefik and other local services can now be accessed using addresses like traefik.kaos or portainer.kaos
- Using /.kaos/ ensures future subdomains automatically resolve, without adding individual entries

7. Restart pihole
To make sure the new file is loaded, we must restart the DNS resolver. We can do this either by accessing pihole's dashboard (on http://<raspberry-local-ip>/admin), going to Settings > System and clicking the "Restart DNS resolver" button or by running this command on the raspberry:

```bash
sudo systemctl restart pihole-FTL
```

8. Optional: Reset MagicDNS
Sometimes you may need to toggle MagicDNS off and on in the Tailscale admin console. This forces devices to re-fetch the new DNS configuration and recognize the custom *.kaos mappings. Why this matters:
- Devices might cache old DNS settings
- Resetting ensures Pi-hole becomes the authoritative DNS for all Tailnet devices