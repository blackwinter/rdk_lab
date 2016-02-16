0. Install [VirtualBox](https://www.virtualbox.org/) and [Packer](https://www.packer.io/)
0. Create `variables.json` (see [User Variables](https://www.packer.io/docs/templates/user-variables.html)); available variables: `packer inspect template.json`
0. Build the virtual machine: `packer build -var-file=variables.json template.json` (NOTE: This process runs **unattended**; don't interact with the virtual machine.)
0. Import the virtual machine into VirtualBox: `VBoxManage import output-virtualbox-iso/<vmname>.ova`
0. Start the virtual machine: `virtualbox --startvm <vmname>`
0. Get the virtual machine's IP address: `VBoxManage guestproperty get <vmname> /VirtualBox/GuestInfo/Net/1/V4/IP`
0. Open the wiki: `http://<vmip>/wiki/`
