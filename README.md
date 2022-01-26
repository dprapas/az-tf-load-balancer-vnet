# Description

Create an Azure infrastructure which consists of the following components:

1. A virtual network with one subnet
2. One public load balancer
3. Three VMs that reside behind the load balancer
4. One Bastion VM used to connect to the other VMs

## Build and Run

To build the infrastructure do the following

1. terraform init
2. terraform plan
3. terraform apply

Once the building of the infrastructure is done do the following

1. Connect to each VM via Bastion
2. Install and run nginx to each VM
3. Get the public IP (frontend IP) of the load balancer
4. Go to http://<FRONTEND_IP> and you should end up on the nginx home page
