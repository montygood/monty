# !/bin/bash

###############
## Variablen ##
###############
ARCHI=$(uname -m)
VERSION=" -| Arch Installation ($ARCHI) |- "
LOCALE="de_CH.UTF-8"
FONT=""
KEYMAP="de_CH-latin1"
CODE="CH"
ZONE="Europe"
SUBZONE="Zurich"
XKBMAP="ch"
SPRA="de"

################
## Funktionen ##
################
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
		dialog --backtitle "$VERSION" --title " -| Fehler |- " --msgbox "$(cat /tmp/.errlog)" 0 0
		echo "" > /tmp/.errlog
	fi
	dialog --backtitle "$VERSION" --title " -| Log Anzeige |- " --msgbox "$(cat /tmp/.errlog)" 0 0
	echo "" > /tmp/.errlog
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
id_sys() {
	# Sprache
	sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen
	locale-gen >/dev/null 2>&1
	export LANG=${LOCALE}
	[[ $FONT != "" ]] && setfont $FONT
	# Keymap
	loadkeys $KEYMAP 2>/tmp/.errlog
	check_for_error
	echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}" > /tmp/vconsole.conf
	# Test
		dialog --backtitle "$VERSION" --title " -| Systemprüfung |- " --infobox "\nTeste Voraussetzungen" 0 0 && sleep 2
	if [[ `whoami` != "root" ]]; then
		dialog --backtitle "$VERSION" --title " -| Fehler |- " --infobox "\ndu bist nicht 'root'\nScript wird beendet" 0 0 && sleep 2
		exit 1
	fi
	if [[ ! $(ping -c 1 google.com) ]]; then
		dialog --backtitle "$VERSION" --title " -| Fehler |- " --infobox "\nkein Internet Zugang.\nScript wird beendet" 0 0 && sleep 2
		exit 1
	fi
	dialog --backtitle "$VERSION" --title " -| Systemprüfung |- " --infobox "\n... OK ..." 0 0 && sleep 2   
	clear
	echo "" > /tmp/.errlog
	pacman -Syy
	# Apple System
	if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true  # if MAC
	else
		modprobe -q efivarfs            # all others
	fi
	# BIOS or UEFI
	if [[ -d "/sys/firmware/efi/" ]]; then
		# Mount efivarfs if it is not already mounted
		if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
			mount -t efivarfs efivarfs /sys/firmware/efi/efivars
		fi
		SYSTEM="UEFI"
	else
		SYSTEM="BIOS"
	fi
	umount_partitions
}   

##############
## Eingaben ##
##############
sel_device() {
	DEVICE=""
	devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
	for i in ${devices_list[@]}; do
		DEVICE="${DEVICE} ${i}"
	done
	DEVICE=$(dialog --nocancel --backtitle "$VERSION" --title " -| Laufwerk |- " --menu "Welche HDD wird verwendet" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
	IDEV=`echo $DEVICE | cut -c6-`
	HD_SD="HDD"
	if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
	VERSION=" -| Arch Installation ($ARCHI) |- $SYSTEM auf $HD_SD |- "
	dialog --backtitle "$VERSION" --title " -| Wipen |- " --yesno "WARNUNG: Alle Daten unwiederuflich auf ${DEVICE} entfernen\nsauber aber dauert etwas" 0 0
	if [[ $? -eq 0 ]]; then WIPE="YES" ; fi
}
sel_hostname() {
	HOSTNAME=$(dialog --backtitle "$VERSION" --title " -| Hostname |- " --stdout --inputbox "Identifizierung im Netzwerk" 0 0 "")
	if [[ $HOSTNAME =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$VERSION" --title " -| FEHLER |- " --msgbox "Ungültiger PC-Name." 0 0
		set_hostname
	fi
}
sel_user() {
	USER=$(dialog --backtitle "$VERSION" --title " -| Benutzer |- " --stdout --inputbox "Namen des Benutzers in Kleinbuchstaben." 0 0 "")
	if [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$VERSION" --title " -| FEHLER |- " --msgbox "Ungültiger Benutzername." 0 0
		set_user
	fi
}
sel_password() {
	RPASSWD=$(dialog --backtitle "$VERSION" --title " -| Root & $USER |- " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --backtitle "$VERSION" --title " -| Root & $USER |- " --stdout --clear --insecure --passwordbox "Passwort bestätigen:" 0 0 "")
	if [[ $RPASSWD == $RPASSWD2 ]]; then 
		echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
	else
		dialog --backtitle "$VERSION" --title " -| FEHLER |- " --infobox "\nDie eingegebenen Passwörter stimmen nicht überein." 0 0
		set_password
	fi
}

############
## Setzen ##
############
set_partitions() {
	if [[ $WIPE == "YES" ]]; then
		clear
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm --needed wipe 2>>/tmp/.errlog
			check_for_error
		fi	
		dialog --backtitle "$VERSION" --title " -| Wipe |- " --infobox "\n...Bitte warten..." 0 0
		wipe -Ifre ${DEVICE} 2>>/tmp/.errlog
		check_for_error
	else
		sgdisk --zap-all ${DEVICE} 2>>/tmp/.errlog
		check_for_error
	fi
	if [[ $SYSTEM == "BIOS" ]]; then
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} 2>>/tmp/.errlog
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --yesno "Harddisk $DEVICE wird Formatiert" 0 0
		echo j | mkfs.ext4 -L arch ${DEVICE}2 >/dev/null 2>>/tmp/.errlog
		mount ${DEVICE}2 /mnt 2>>/tmp/.errlog
		check_for_error
	fi
	if [[ $SYSTEM == "UEFI" ]]; then
		echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk ${DEVICE} 2>>/tmp/.errlog
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --yesno "Harddisk $DEVICE wird Formatiert" 0 0
		echo j | mkfs.vfat -F32 -L boot ${DEVICE}1 >/dev/null 2>>/tmp/.errlog
		echo j | mkfs.ext4 -L arch ${DEVICE}2 >/dev/null 2>>/tmp/.errlog
		mount ${DEVICE}2 /mnt 2>>/tmp/.errlog
		mkdir -p /mnt/boot 2>>/tmp/.errlog
		mount ${DEVICE}1 /mnt/boot 2>>/tmp/.errlog
		check_for_error
	fi		
	if [[ $HD_SD == "HDD" ]]; then
		dialog --backtitle "$VERSION" --title "-| Swap-File |-" --yesno "wird angelegt" 0 0
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile 2>>/tmp/.errlog
		chmod 600 /mnt/swapfile 2>>/tmp/.errlog
		mkswap /mnt/swapfile -L swap >/dev/null 2>>/tmp/.errlog
		swapon /mnt/swapfile >/dev/null 2>>/tmp/.errlog
		check_for_error		
	fi
	dialog --backtitle "$VERSION" --title "wurde Erstellt" --infobox "\n     OK     " 0 0
}
set_mirrorlist() {
	if ! (</etc/pacman.d/mirrorlist grep "rankmirrors" &>/dev/null) then
		dialog --backtitle "$VERSION" --title " -| Spiegelserver |- " --infobox "...Bitte warten..." 0 0
		URL="https://www.archlinux.org/mirrorlist/?country=${CODE}&use_mirror_status=on"
		MIRROR_TEMP=$(mktemp --suffix=-mirrorlist)
		curl -so ${MIRROR_TEMP} ${URL} 2>>/tmp/.errlog
		sed -i 's/^#Server/Server/g' ${MIRROR_TEMP} 2>>/tmp/.errlog
		mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig 2>>/tmp/.errlog
		dialog --backtitle "$VERSION" --title " -| Spiegelserver |- " --infobox "\nsortiere die Spiegelserver\n...Bitte warten..." 0 0
		rankmirrors -n 10 ${MIRROR_TEMP} > /etc/pacman.d/mirrorlist 2>>/tmp/.errlog
		chmod +r /etc/pacman.d/mirrorlist 2>>/tmp/.errlog
		dialog --backtitle "$VERSION" --title " -| Spiegelserver |- " --infobox "\nFertig!\n\n" 0 0 && sleep 2
		clear
		pacman-key --init
		pacman-key --populate archlinux
		pacman-key --refresh-keys
	fi
}
gen_fstab() {
	genfstab -U -p /mnt > /mnt/etc/fstab 2>/tmp/.errlog && check_for_error
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
}
set_hostname() {
	echo "${HOSTNAME}" > /mnt/etc/hostname 2>/tmp/.errlog
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts 2>>/tmp/.errlog
	check_for_error
}
set_locale() {
	echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen 2>/tmp/.errlog
	check_for_error
	arch_chroot "locale-gen" >/dev/null 2>>/tmp/.errlog
}
set_timezone() {
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime" 2>/tmp/.errlog && check_for_error
}
set_hw_clock() {
	arch_chroot "hwclock --systohc --utc"  2>/tmp/.errlog && check_for_error
}
set_root_password() {
	arch_chroot "passwd root" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
}
set_new_user() {
	dialog --backtitle "$VERSION" --title "-| Benutzer |-" --infobox "wird erstellt" 0 0 && sleep 2
	arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp -s /bin/bash" 2>/tmp/.errlog
	check_for_error
	arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
	rm /tmp/.passwd
	check_for_error
	arch_chroot "cp /etc/skel/.bashrc /home/${USER}"
	arch_chroot "chown -R ${USER}:users /home/${USER}"
	[[ -e /mnt/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
}
run_mkinitcpio() {
	clear
	KERNEL=$(ls /mnt/boot/*.img | grep -v "fallback" | sed "s~/mnt/boot/initramfs-~~g" | sed s/\.img//g | uniq)
	for i in ${KERNEL}; do
		arch_chroot "mkinitcpio -p ${i}"
	done
}
set_xkbmap() {
	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf 2>>/tmp/.errlog
	check_for_error
}
set_security(){
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/journald.conf
	sed -i "s/SystemMaxUse.*/#&/g" /mnt/etc/systemd/journald.conf
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/coredump.conf
	echo "kernel.dmesg_restrict = 1" > /mnt/etc/sysctl.d/50-dmesg-restrict.conf
}

#############
## Install ##
#############
ins_base() {
	clear
	pac_strap "base base-devel btrfs-progs f2fs-tools sudo"
	[[ -e /tmp/vconsole.conf ]] && cp -f /tmp/vconsole.conf /mnt/etc/vconsole.conf 2>/tmp/.errlog
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /etc/pacman.conf 2>>/tmp/.errlog
	fi
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then
		echo -e "\n[archlinuxfr]\nServer = http://repo.archlinux.fr/$(uname -m)\nSigLevel = Never" >> /etc/pacman.conf 2>>/tmp/.errlog
	fi
	cp -f /etc/pacman.conf /mnt/etc/pacman.conf 2>>/tmp/.errlog
	check_for_error
	pacman -Syy
	arch_chroot "pacman -Syy"
}
ins_bootloader() {
	arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl" 2>/tmp/.errlog
	check_for_error
	if [[ $SYSTEM == "BIOS" ]]; then		
		if [[ $DEVICE != "" ]]; then
			dialog --backtitle "$VERSION" --title " -| Grub-install |- " --infobox "...Bitte warten..." 0 0
			pacstrap /mnt grub dosfstools 2>/tmp/.errlog
			arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>>/tmp/.errlog
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>>/tmp/.errlog
			check_for_error
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		fi
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		if [[ $DEVICE != "" ]]; then
			dialog --backtitle "$VERSION" --title " -| Grub-install |- " --infobox "...Bitte warten..." 0 0
			pacstrap /mnt grub efibootmgr dosfstools 2>/tmp/.errlog
			arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>>/tmp/.errlog
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>>/tmp/.errlog
			check_for_error
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			arch_chroot "mkdir -p /boot/EFI/boot"
			arch_chroot "cp -r /boot/EFI/arch_grub/grubx64.efi /boot/EFI/boot/bootx64.efi"
		fi
	fi
}
ins_xorg() {
	clear
	pac_strap "xorg-server xorg-server-utils xorg-xinit xf86-input-keyboard xf86-input-mouse xf86-input-synaptics xf86-input-libinput"
	# now copy across .xinitrc for all user accounts
	user_list=$(ls /mnt/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$i/.xinitrc
		arch_chroot "chown -R ${i}:users /home/${i}"
	done
}
ins_graphics_card() {
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
	if [[ $(echo $GRAPHIC_CARD | grep -i "nvidia") != "" ]]; then
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
ins_de_wm() {
	clear
	pac_strap "cinnamon nemo-fileroller nemo-preview"
	clear
	pac_strap "gnome-terminal bash-completion gamin gksu gnome-icon-theme gnome-keyring gvfs gvfs-afc gvfs-smb polkit poppler python2-xdg ntfs-3g ttf-dejavu xdg-user-dirs xdg-utils xterm"
}
ins_dm() {
	clear
	pac_strap "lightdm lightdm-gtk-greeter"
	arch_chroot "systemctl enable lightdm.service"
	sed -i "s/#autologin-user=/autologin-user=${USER}/" /mnt/etc/lightdm/lightdm.conf 2>>/tmp/.errlog
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf 2>>/tmp/.errlog
	check_for_error
	arch_chroot "groupadd -r autologin"
	arch_chroot "gpasswd -a ${USER} autologin"
}
ins_network() {
	WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRELESS_DEV ]]; then 
		clear
		pac_strap "iw wireless_tools wpa_actiond dialog rp-pppoe"
	fi

	clear
	pac_strap "networkmanager network-manager-applet"
	arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service"

	clear
	pac_strap "cups system-config-printer hplip ghostscript gsfonts"
	arch_chroot "systemctl enable org.cups.cupsd.service"

	if (dmesg | grep -i "blue" &> /dev/null); then 
		clear
		pac_strap "bluez bluez-utils blueman"
		arch_chroot "systemctl enable bluetooth.service"
	fi
}

###########
## Start ##
###########
id_sys
sel_device
sel_hostname
sel_user
sel_password
set_partitions
set_mirrorlist
ins_base
ins_bootloader
gen_fstab 
set_hostname
set_locale
set_timezone
set_hw_clock
set_root_password 
set_new_user
run_mkinitcpio
ins_xorg
ins_graphics_card
ins_de_wm
ins_dm
set_xkbmap
ins_network
set_security
umount_partitions
dialog --backtitle "$VERSION" --title " -| Installation Fertig |- " --infobox "Install Medium nach dem Neustart entfernen" 0 0
exit 0
reboot
