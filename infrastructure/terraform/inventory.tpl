[loadgenerator]
${vm_ip} ansible_user=debian ansible_ssh_private_key_file=~/.ssh/google_compute_engine

[loadgenerator:vars]
frontend_addr=${frontend_addr}
locust_users=${users}
locust_spawn_rate=${spawn_rate}
