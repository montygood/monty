# !/bin/bash
## Installer Variables
op_title=" -| Arch Installation - ($(uname -m)) |- "
LOCALE="de_CH.UTF-8"
FONT=""
KEYMAP="de_CH-latin1"
CODE="CH"
ZONE="Europe"
SUBZONE="Zurich"
XKBMAP="ch"
SPRA="de"
## Functions
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}" 2>>/tmp/.errlog
    check_for_error
}  
pac_strap() {
    pacstrap /mnt ${1} --needed 2>>/tmp/.errlog
    check_for_error
}  
check_for_error() {
	if [[ $? -eq 1 ]] && [[ $(cat /tmp/.errlog | grep -i "error") != "" ]]; then
		dialog --backtitle "$op_title" --title " -| Fehleranzeige |- " --msgbox "$(cat /tmp/.errlog)" 0 0
	fi
	echo "" > /tmp/.errlog
}
load() {
	{	int="1"
        	while ps | grep "$pid" &> /dev/null
    	    	do
    	            sleep $pri
    	            echo $int
    	        	if [ "$int" -lt "100" ]; then
    	        		int=$((int+1))
    	        	fi
    	        done
            echo 100
            sleep 1
	} | dialog --gauge "$msg" 9 79 0
}
umount_partitions(){
	MOUNTED=""
	MOUNTED=$(mount | grep "/mnt" | awk '{print $3}' | sort -r)
	swapoff -a
	for i in ${MOUNTED[@]}; do
		umount $i >/dev/null 2>>/tmp/.errlog
	done
	check_for_error
}
_menu() {
	umount_partitions
	reboot
	dialog --backtitle "$op_title" --title " -| Installation Fertig |- " --infobox "Install Medium nach dem Neustart entfernen" 0 0
	exit 0
}
## Configuration
id_system() {
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true  # if MAC
    else
		modprobe -q efivarfs
    fi
    if [[ -d "/sys/firmware/efi/" ]]; then
		if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then mount -t efivarfs efivarfs /sys/firmware/efi/efivars ; fi
		SYSTEM="UEFI"
    else
		SYSTEM="BIOS"
    fi
	if [[ `whoami` != "root" ]]; then
		dialog --backtitle "$op_title" --title " -| Systemprüfung ergab |- " --msgbox "\ndu bist nicht 'root'\nScript wird beendet" 0 0
		exit 1
	fi
	if [[ ! $(ping -c 1 google.com) ]]; then
		dialog --backtitle "$op_title" --title " -| Systemprüfung ergab |- " --msgbox "\nkein Internet Zugang.\nScript wird beendet" 0 0
		exit 1
	fi
	clear
	echo "" > /tmp/.errlog
	#Locale
    sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen 2>>/tmp/.errlog
    locale-gen >/dev/null 2>&1
    export LANG=${LOCALE}
    [[ $FONT != "" ]] && setfont $FONT	
	#Keymap
	loadkeys $KEYMAP 2>>/tmp/.errlog
    check_for_error
	select_device
}
select_device() {
    DEVICE=""
    devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
    for i in ${devices_list[@]}; do
        DEVICE="${DEVICE} ${i}"
    done
    DEVICE=$(dialog --nocancel --backtitle "$op_title" --title " -| Laufwerk |- " --menu "Welche HDD wird verwendet" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
	IDEV=`echo $DEVICE | cut -c6-`
	HD_SD="HDD"
	if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
	op_title=" -| Arch Linux - ($(uname -m)) $SYSTEM $HD_SD |- "
	dialog --backtitle "$op_title" --title " -| Wipen |- " --yesno "WARNUNG: Alle Daten unwiederuflich auf ${DEVICE} entfernen\nsauber aber dauert etwas" 0 0
	if [[ $? -eq 0 ]]; then WIPE="YES" ; fi
	select_hostname
}
select_hostname() {
	hostname=$(dialog --backtitle "$op_title" --title " -| Hostname |- " --stdout --inputbox "Identifizierung im Netzwerk" 0 0 "")
	set_password
}
set_password() {
	RPASSWD=$(dialog --backtitle "$op_title" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --backtitle "$op_title" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort bestätigen:" 0 0 "")
	if [[ $RPASSWD == $RPASSWD2 ]]; then 
		echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
	else
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --infobox "\nDie eingegebenen Passwörter stimmen nicht überein." 0 0
		set_password
	fi
	set_user
}
set_user() {
	USER=$(dialog --backtitle "$op_title" --title " -| Benutzer |- " --stdout --inputbox "Namen des Benutzers in Kleinbuchstaben." 0 0 "")
	if [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --msgbox "Ungültiger Benutzername." 0 0
		set_user
	fi
	set_partitions
}
set_partitions() {
	umount_partitions
	if [[ $WIPE == "YES" ]]; then
		clear
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm --needed wipe 2>>/tmp/.errlog
			check_for_error
		fi	
		dialog --backtitle "$op_title" --title " -| Wipen |- " --infobox "\n...Bitte warten..." 0 0
		wipe -Ifre ${DEVICE} 2>>/tmp/.errlog
		check_for_error
    else
		sgdisk --zap-all ${DEVICE} 2>>/tmp/.errlog
		check_for_error
	fi
    if [[ $SYSTEM == "BIOS" ]]; then
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} 2>>/tmp/.errlog
		echo j | mkfs.ext4 -L arch ${DEVICE}2 >/dev/null 2>>/tmp/.errlog
		mount ${DEVICE}2 /mnt 2>>/tmp/.errlog
		check_for_error
	fi
	if [[ $SYSTEM == "UEFI" ]]; then
		echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk ${DEVICE} 2>>/tmp/.errlog
		echo j | mkfs.vfat -F32 -L boot ${DEVICE}1 >/dev/null 2>>/tmp/.errlog
		echo j | mkfs.ext4 -L arch ${DEVICE}2 >/dev/null 2>>/tmp/.errlog
		mount ${DEVICE}2 /mnt 2>>/tmp/.errlog
		mkdir -p /mnt/boot 2>>/tmp/.errlog
		mount ${DEVICE}1 /mnt/boot 2>>/tmp/.errlog
		check_for_error
	fi		
	if [[ $HD_SD == "HDD" ]]; then
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile 2>>/tmp/.errlog
		chmod 600 /mnt/swapfile 2>>/tmp/.errlog
		mkswap /mnt/swapfile -L swap >/dev/null 2>>/tmp/.errlog
		swapon /mnt/swapfile >/dev/null 2>>/tmp/.errlog
		check_for_error		
	fi
	set_mirrorlist
}
set_mirrorlist() {
	if ! (</etc/pacman.d/mirrorlist grep "rankmirrors" &>/dev/null) then
		URL="https://www.archlinux.org/mirrorlist/?country=${CODE}&use_mirror_status=on"
		MIRROR_TEMP=$(mktemp --suffix=-mirrorlist)
		curl -so ${MIRROR_TEMP} ${URL} 2>>/tmp/.errlog
		sed -i 's/^#Server/Server/g' ${MIRROR_TEMP} 2>>/tmp/.errlog
		cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 2>>/tmp/.errlog
		rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist 2>>/tmp/.errlog & pid=$! pri=0.8 msg="Bitte warten. Spiegelserver werden nach Schnelligkeit sortiert..." load
		mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig 2>>/tmp/.errlog
		mv -f ${MIRROR_TEMP} /etc/pacman.d/mirrorlist 2>>/tmp/.errlog
		chmod +r /etc/pacman.d/mirrorlist 2>>/tmp/.errlog
		clear
		pacman-key --init 2>>/tmp/.errlog
		pacman-key --populate archlinux 2>>/tmp/.errlog
		pacman-key --refresh-keys 2>>/tmp/.errlog & pid=$! pri=0.8 msg="Spiegelserver-Schlüssel werden geupdatet..." load
		pacman -Syy
		check_for_error
	fi
	install_base
}
install_base() {
	clear
	pac_strap "base base-devel btrfs-progs f2fs-tools sudo"
    echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}" > /mnt/etc/vconsole.conf 2>>/tmp/.errlog
	cp -f /etc/pacman.conf /mnt/etc/pacman.conf 2>>/tmp/.errlog
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf 2>>/tmp/.errlog
	fi
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then
		echo -e "\n[archlinuxfr]\nServer = http://repo.archlinux.fr/$(uname -m)\nSigLevel = Never" >> /mnt/etc/pacman.conf 2>>/tmp/.errlog
	fi
	pacman -Syy 2>>/tmp/.errlog
	check_for_error	
	arch_chroot "pacman -Syy"
	install_bootloader
}
install_bootloader() {
    arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl"
	if [[ $SYSTEM == "BIOS" ]]; then		
		if [[ $DEVICE != "" ]]; then
			pac_strap "grub dosfstools"
			arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>>/tmp/.errlog
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>>/tmp/.errlog
			check_for_error
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		fi
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		if [[ $DEVICE != "" ]]; then
			pac_strap "grub efibootmgr dosfstools"
			arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>>/tmp/.errlog
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>>/tmp/.errlog
			check_for_error
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			arch_chroot "mkdir -p /boot/EFI/boot"
			arch_chroot "cp -r /boot/EFI/arch_grub/grubx64.efi /boot/EFI/boot/bootx64.efi"
		fi
	fi
	set_fstab
}
set_fstab() {
	genfstab -U -p /mnt >> /mnt/etc/fstab 2>>/tmp/.errlog
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab 2>>/tmp/.errlog
	check_for_error
	set_hostname
}
set_hostname() {
   echo "${hostname}" > /mnt/etc/hostname 2>>/tmp/.errlog
   echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${hostname}\n::1\tlocalhost.localdomain\tlocalhost\t${hostname}" > /mnt/etc/hosts 2>>/tmp/.errlog
   check_for_error
   set_locale
}
set_locale() {
  echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf 2>>/tmp/.errlog
  sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen 2>>/tmp/.errlog
  check_for_error
  arch_chroot "locale-gen" >/dev/null
  set_timezone
}
set_timezone() {
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
	set_hw_clock
}
set_hw_clock() {
	arch_chroot "hwclock --systohc --utc"
	set_root_password
}
set_root_password() {
	arch_chroot "passwd root" < /tmp/.passwd >/dev/null
	set_new_user
}
set_new_user() {
	arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp -s /bin/bash"
	arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null
	rm /tmp/.passwd
	arch_chroot "cp /etc/skel/.bashrc /home/${USER}"
	arch_chroot "chown -R ${USER}:users /home/${USER}"
	[[ -e /mnt/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers 2>>/tmp/.errlog
	check_for_error
	set_mkinitcpio
}
set_mkinitcpio() {
	clear
	KERNEL=$(ls /mnt/boot/*.img | grep -v "fallback" | sed "s~/mnt/boot/initramfs-~~g" | sed s/\.img//g | uniq)
	for i in ${KERNEL}; do
		arch_chroot "mkinitcpio -p ${i}"
	done
	install_xorg
}
install_xorg() {
	pac_strap "xorg-server xorg-server-utils xorg-xinit xf86-input-keyboard xf86-input-mouse xf86-input-synaptics xf86-input-libinput"
	user_list=$(ls /mnt/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$i/.xinitrc 2>>/tmp/.errlog
		check_for_error
		arch_chroot "chown -R ${i}:users /home/${i}"
	done
	install_graphics_card
}
install_graphics_card() {
	install_intel(){
		pac_strap "xf86-video-intel libva-intel-driver intel-ucode"
		sed -i 's/MODULES=""/MODULES="i915"/' /mnt/etc/mkinitcpio.conf
		if [[ -e /mnt/boot/grub/grub.cfg ]]; then
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		fi
		# Systemd-boot
		if [[ -e /mnt/boot/loader/loader.conf ]]; then
				update=$(ls /mnt/boot/loader/entries/*.conf)
				for i in ${upgate}; do
					sed -i '/linux \//a initrd \/intel-ucode.img' ${i}
				done
		fi			 
	}
	install_ati(){
		pac_strap "xf86-video-ati"
		sed -i 's/MODULES=""/MODULES="radeon"/' /mnt/etc/mkinitcpio.conf
	}
	NVIDIA=""
	VB_MOD=""
	GRAPHIC_CARD=""
	INTEGRATED_GC="N/A"
	GRAPHIC_CARD=$(lspci | grep -i "vga" | sed 's/.*://' | sed 's/(.*//' | sed 's/^[ \t]*//')
	if 	[[ $(echo $GRAPHIC_CARD | grep -i "nvidia") != "" ]]; then
		[[ $(lscpu | grep -i "intel\|lenovo") != "" ]] && INTEGRATED_GC="Intel" || INTEGRATED_GC="ATI"
		if [[ $(dmesg | grep -i 'chipset' | grep -i 'nvc\|nvd\|nve') != "" ]]; then HIGHLIGHT_SUB_GC=4
			elif [[ $(dmesg | grep -i 'chipset' | grep -i 'nva\|nv5\|nv8\|nv9'﻿) != "" ]]; then HIGHLIGHT_SUB_GC=5
			elif [[ $(dmesg | grep -i 'chipset' | grep -i 'nv4\|nv6') != "" ]]; then HIGHLIGHT_SUB_GC=6
			else HIGHLIGHT_SUB_GC=3
		fi	
	elif [[ $(echo $GRAPHIC_CARD | grep -i 'intel\|lenovo') != "" ]]; then HIGHLIGHT_SUB_GC=2
	elif [[ $(echo $GRAPHIC_CARD | grep -i 'ati') != "" ]]; then HIGHLIGHT_SUB_GC=1
	elif [[ $(echo $GRAPHIC_CARD | grep -i 'via') != "" ]]; then HIGHLIGHT_SUB_GC=7
	elif [[ $(echo $GRAPHIC_CARD | grep -i 'virtualbox') != "" ]]; then HIGHLIGHT_SUB_GC=8
	elif [[ $(echo $GRAPHIC_CARD | grep -i 'vmware') != "" ]]; then HIGHLIGHT_SUB_GC=9
	else HIGHLIGHT_SUB_GC=10
	fi	
	if [[ $HIGHLIGHT_SUB_GC == 1 ]] ; then
		install_ati
	fi
	if [[ $HIGHLIGHT_SUB_GC == 2 ]] ; then
		install_intel
	fi
	if [[ $HIGHLIGHT_SUB_GC == 3 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		pac_strap "xf86-video-nouveau"
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pac_strap "${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings"
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pac_strap "${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings"
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-304xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-304xx-lts"
		pac_strap "${NVIDIA} nvidia-304xx-libgl nvidia-304xx-utils nvidia-settings"
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 7 ]] ; then
		pac_strap "xf86-video-openchrome"
	fi
	if [[ $HIGHLIGHT_SUB_GC == 8 ]] ; then
		[[ -e /mnt/boot/initramfs-linux.img ]] && VB_MOD="linux-headers"
		[[ -e /mnt/boot/initramfs-linux-grsec.img ]] && VB_MOD="$VB_MOD linux-grsec-headers"
		[[ -e /mnt/boot/initramfs-linux-zen.img ]] && VB_MOD="$VB_MOD linux-zen-headers"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && VB_MOD="$VB_MOD linux-lts-headers"
		pac_strap "virtualbox-guest-utils virtualbox-guest-dkms $VB_MOD"
		umount -l /mnt/dev
		arch_chroot "modprobe -a vboxguest vboxsf vboxvideo"  
		arch_chroot "systemctl enable vboxservice"
		echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 9 ]] ; then
		pac_strap "xf86-video-vmware xf86-input-vmmouse"
	fi
	if [[ $HIGHLIGHT_SUB_GC == 10 ]] ; then
		pac_strap "xf86-video-fbdev"
	fi
    check_for_error	 
	if [[ $NVIDIA_INST == 1 ]] && [[ ! -e /mnt/etc/X11/xorg.conf.d/20-nvidia.conf ]]; then
		echo "Section "\"Device"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        Identifier "\"Nvidia Card"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        Driver "\"nvidia"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        VendorName "\"NVIDIA Corporation"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        Option "\"NoLogo"\" "\"true"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        #Option "\"UseEDID"\" "\"false"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        #Option "\"ConnectedMonitor"\" "\"DFP"\"" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "        # ..." >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
		echo "EndSection" >> /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
	fi
	install_de_wm
}
install_de_wm() {
	clear
	pac_strap "cinnamon nemo-fileroller nemo-preview"
	clear
	pac_strap "gnome-terminal bash-completion gamin gksu gnome-icon-theme gnome-keyring gvfs gvfs-afc gvfs-smb polkit poppler python2-xdg ntfs-3g ttf-dejavu xdg-user-dirs xdg-utils"
	install_dm
}
install_dm() {
	pac_strap "lightdm lightdm-gtk-greeter"
	arch_chroot "systemctl enable lightdm-gtk-greeter"
	sed -i "s/#autologin-user=/autologin-user=${USER}/" /mnt/etc/lightdm/lightdm.conf 2>>/tmp/.errlog
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf 2>>/tmp/.errlog
	check_for_error
	arch_chroot "groupadd -r autologin"
	arch_chroot "gpasswd -a ${USER} autologin"
	set_xkbmap
}
set_xkbmap() {
    echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf 2>>/tmp/.errlog
	check_for_error
	install_network
}
install_network() {
	WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRELESS_DEV ]]; then 
		pac_strap "iw wireless_tools wpa_actiond dialog rp-pppoe"
	fi
	WIRED_DEV=`ip link | grep "ens\|eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRED_DEV ]]; then 
		pac_strap "networkmanager network-manager-applet"
		arch_chroot "systemctl enable dhcpcd@${WIRED_DEV}.service"
		arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service"
	fi	
	pac_strap "cups system-config-printer hplip splix cups-pdf ghostscript gsfonts"
	arch_chroot "systemctl enable org.cups.cupsd.service"
	if (dmesg | grep -i "blue" &> /dev/null); then 
		pac_strap "bluez bluez-utils blueman"
		arch_chroot "systemctl enable bluetooth.service"
	fi
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/journald.conf 2>>/tmp/.errlog
	sed -i "s/SystemMaxUse.*/#&/g" /mnt/etc/systemd/journald.conf 2>>/tmp/.errlog
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/coredump.conf 2>>/tmp/.errlog
	echo "kernel.dmesg_restrict = 1" > /mnt/etc/sysctl.d/50-dmesg-restrict.conf 2>>/tmp/.errlog
	check_for_error
	install_jdownloader
}
install_jdownloader() {
	pac_strap "jre7-openjdk"
	mkdir -p /mnt/opt/JDownloader/ 2>>/tmp/.errlog
	wget -c -O /mnt/opt/JDownloader/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar 2>>/tmp/.errlog
	arch_chroot "chown -R 1000:1000 /opt/JDownloader/"
	arch_chroot "chmod -R 0775 /opt/JDownloader/"
	echo "[Desktop Entry]" > /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Name=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Comment=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Exec=java -jar /opt/JDownloader/JDownloader.jar" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Icon=/opt/JDownloader/themes/standard/org/jdownloader/images/logo/jd_logo_64_64.png" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Terminal=false" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Type=Application" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "StartupNotify=false" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	echo "Categories=Network;Application;" >> /mnt/usr/share/applications/JDownloader.desktop 2>>/tmp/.errlog
	check_for_error
	set_mediaelch
}
set_mediaelch() {		
	echo "#!/bin/sh" > /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "wakeonlan 00:01:2e:3a:5e:81" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mkdir /mnt/Serien1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mkdir /mnt/Serien2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mkdir /mnt/Filme1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mkdir /mnt/Filme2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mkdir /mnt/Musik" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mount -t nfs4 192.168.2.250:/export/Serien1 /mnt/Serien1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mount -t nfs4 192.168.2.250:/export/Serien2 /mnt/Serien2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mount -t nfs4 192.168.2.250:/export/Filme1 /mnt/Filme1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mount -t nfs4 192.168.2.250:/export/Filme2 /mnt/Filme2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo mount -t nfs4 192.168.2.250:/export/Musik /mnt/Musik" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "MediaElch" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo umount /mnt/Serien1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo umount /mnt/Serien2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo umount /mnt/Filme1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo umount /mnt/Filme2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo umount /mnt/Musik" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo rmdir /mnt/Serien1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo rmdir /mnt/Serien2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo rmdir /mnt/Filme1" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo rmdir /mnt/Filme2" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	echo "sudo rmdir /mnt/Musik" >> /mnt/usr/bin/elch 2>>/tmp/.errlog
	mkdir -p /mnt/home/${USER}/.config/kvibes/ 2>>/tmp/.errlog
	echo "[Directories]" > /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Concerts\size=0" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Downloads\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Downloads\1\path=/home/monty/Downloads" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Downloads\1\sepFolders=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Downloads\size=1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\1\path=/mnt/Filme1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\1\sepFolders=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\2\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\2\path=/mnt/Filme2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\2\sepFolders=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Movies\size=2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Music\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Music\1\path=/mnt/Musik" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Music\1\sepFolders=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Music\size=1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TvShows\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TvShows\1\path=/mnt/Serien1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TvShows\2\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TvShows\2\path=/mnt/Serien2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TvShows\size=2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "[Downloads]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "DeleteArchives=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "KeepSource=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "Unrar=/bin/unrar" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "[Scrapers]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "AEBN\Language=en" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "FanartTv\DiscType=BluRay" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "FanartTv\Language=de" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "FanartTv\PersonalApiKey=" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "ShowAdult=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TMDb\Language=de" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TMDbConcerts\Language=en" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "TheTvDb\Language=de" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "UniversalMusicScraper\Language=en" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "UniversalMusicScraper\Prefer=theaudiodb" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "[TvShows]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "DvdOrder=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "ShowMissingEpisodesHint=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "[Warnings]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "DontShowDeleteImageConfirm=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "[XBMC]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "RemoteHost=192.168.2.251" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "RemotePassword=xbmc" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "RemotePort=80" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	echo "RemoteUser=xbmc	" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>>/tmp/.errlog
	chmod +x /mnt/usr/bin/elch 2>>/tmp/.errlog
	check_for_error
	install_apps
}
install_apps() {
	pac_strap "libreoffice-fresh-${SPRA} firefox-i18n-${SPRA} thunderbird-i18n-${SPRA} hunspell-${SPRA} aspell-${SPRA} ttf-liberation"
	pac_strap "gimp gimp-help-${SPRA} gthumb simple-scan vlc avidemux-gtk handbrake clementine mkvtoolnix-gui picard meld unrar p7zip lzop cpio"
	pac_strap "flashplugin geany leafpad pitivi frei0r-plugins xfburn simplescreenrecorder qbittorrent mlocate pkgstats"
	pac_strap "libaacs tlp tlp-rdw ffmpegthumbs ffmpegthumbnailer x264 upx nss-mdns libquicktime libdvdcss cdrdao"
	pac_strap "alsa-utils fuse-exfat autofs mtpfs icoutils wine-mono playonlinux winetricks nfs-utils gparted gst-plugins-ugly gst-libav"
	pac_strap "wine wine_gecko steam yaourt"
	[[ $(uname -m) == x86_64 ]] && pac_strap "lib32-alsa-plugins lib32-libpulse"
	arch_chroot "upx --best /usr/lib/firefox/firefox"
	install_yaourt
}
install_yaourt() {
	[[ $(uname -m) == x86_64 ]] && arch_chroot "yaourt -S codecs64 --noconfirm --needed"
	[[ $(uname -m) == i686  ]] && arch_chroot "yaourt -S codecs --noconfirm --needed"
	arch_chroot "yaourt -S mediaelch --noconfirm --needed"
    arch_chroot "yaourt -S pamac-aur --noconfirm --needed"
    arch_chroot "yaourt -S teamviewer --noconfirm --needed"
	arch_chroot "systemctl enable teamviewerd"
    arch_chroot "yaourt -S wakeonlan --noconfirm --needed"
    arch_chroot "yaourt -S mp3gain --noconfirm --needed"
    arch_chroot "yaourt -S mintstick-git --noconfirm --needed"
    arch_chroot "yaourt -S mp3diags-unstable --noconfirm --needed"
    arch_chroot "yaourt -S skype --noconfirm --needed"
	mkdir -p /mnt/usr/share/linuxmint/locale/de/LC_MESSAGES/ 2>>/tmp/.errlog
	cp mintstick.mo /mnt/usr/share/linuxmint/locale/de/LC_MESSAGES/mintstick.mo 2>>/tmp/.errlog
	cp mp3diags_de_DE.qm /mnt/usr/bin/mp3diags_de_DE.qm 2>>/tmp/.errlog
	check_for_error
	_menu
}

## Running
id_system

