yum install -q -y bzip2 gcc kernel-devel-`uname -r` kernel-headers make

mount -o loop ~/VBoxGuestAdditions.iso /mnt
sh /mnt/VBoxLinuxAdditions.run --nox11

umount /mnt
rm ~/VBoxGuestAdditions.iso
