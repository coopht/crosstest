# crosstest
To start qemu:

1. Need tun/tap enabled in kernel

    modprobe tun
  
2. Setup interface

    ip tuntap add IFNAME user USER group GROUP mode tap
    ifconfig IFNAME 192.168.1.1 up
  
3. export filesystem via nfs:

    echo /path/to/crosstest/crosstest/rootfs/ 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,async) >> /etc/exports
    exportfs -av
  
4. launch qemu:

    ./crosstest/bin/qemu-system-arm
    -smp cpus=4
    -M vexpress-a15
    -cpu cortex-a15
    -m 512
    -kernel./crosstest/linux/zImage
    -dtb crosstest/linux/vexpress-v2p-ca15_a7.dtb
    -append "root=/dev/nfs rw nfsroot=192.168.1.1:/path/to/crosstest/crosstest/rootfs/,nfsvers=3 ip=192.168.1.2 console=ttyAMA0 mem=512M"
    -serial stdio
    -net nic,vlan=0
    -net tap,ifname=IFNAME,vlan=0,script=no,downscript=no
  
5. Setup ssh connection with keys based auth
6. Enable batch mode for ssh connection
   Host 192.168.1.2
   BatchMode yes
   HostName 192.168.1.2
   ControlPath /tmp/%r@%h:%p
   ControlMaster auto
   ControlPersist 10m

7. Setup dejagnu env
echo lappend boards_dir "/path/to/crosstest/tools/dg/" > ~/dejagnu/site.exp 
export DEJAGNU=/home/karlson/dejagnu/site.exp
