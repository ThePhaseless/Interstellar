# Ansible Infrastructure Configuration

This Ansible project manages Proxmox containers and installs Tailscale on both containers and Oracle instances.

## Structure

```text
Ansible/
├── site.yaml                    # Main playbook
├── vars/
│   └── proxmox.yaml             # Container IDs and Proxmox connection info
└── roles/
    ├── proxmox_containers/      # Manages Proxmox LXC containers
    │   ├── tasks/
    │   │   ├── main.yaml        # Main container management tasks
    │   │   └── update_container_config.yaml  # Container config updates
    │   └── vars/
    │       └── main.yaml        # Role-specific variables
    └── tailscale/               # Installs and configures Tailscale
        ├── tasks/
        │   ├── main.yaml        # Main Tailscale tasks dispatcher
        │   ├── install_debian.yaml    # Debian/Ubuntu installation
        │   ├── install_redhat.yaml    # RedHat/CentOS installation
        │   └── configure.yaml   # Tailscale configuration
        └── vars/
            └── main.yaml        # Tailscale variables
```

## Usage

1. **Configure variables**: Edit `vars/proxmox.yaml` with your container IDs and Proxmox details
2. **Customize container config**: Edit `roles/proxmox_containers/vars/main.yaml` to set the configuration text to add to containers
3. **Set Tailscale auth key** (optional): Edit `roles/tailscale/vars/main.yaml` to add your Tailscale auth key
4. **Run the playbook**:

   ```bash
   ansible-playbook -i inventory-static.ini site.yaml
   ```

## What it does

1. **Container Discovery**: Extracts container IDs from vars, gets their IP addresses
2. **Dynamic Inventory**: Adds containers to the `proxmox_containers` group in Ansible inventory
3. **Container Configuration**: Updates each container's config file and restarts if needed
4. **Tailscale Installation**: Installs Tailscale on both containers and Oracle instances

## Variables

### Proxmox Containers Role

- `proxmox_containers_config_text`: Text to add to container configuration files

### Tailscale Role

- `tailscale_auth_key`: Tailscale authentication key (optional)
- `tailscale_accept_routes`: Whether to accept subnet routes
- `tailscale_accept_dns`: Whether to accept DNS configuration

## Requirements

- Ansible 2.9+
- SSH access to Proxmox host and containers
- Proper SSH key configuration
- Internet access for Tailscale installation
