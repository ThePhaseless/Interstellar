[proxmox_hosts]
${pve_ip} ansible_user=${pve_user} ansible_name="Proxmox VE"

[oracle]
%{ for ip, user in oracle_servers ~}
${ip} ansible_user=${user}
%{ endfor ~}

[oracle:vars]
ansible_ssh_private_key_file=${private_key_path}

[proxmox_containers:children]
