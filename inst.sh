# !/bin/bash

###############
## Variablen ##
###############
ARCHI=$(uname -m)
VERSION=" -| Arch Installation ($ARCHI) |- "
LOCALE="de_CH.UTF-8"
KEYMAP="de_CH-latin1"
CODE="CH"
ZONE="Europe"
SUBZONE="Zurich"
XKBMAP="ch"
SPRA="echo $LOCALE | cut -d\_ -f1"

################
## Funktionen ##
################
arch_chroot() {
	dialog --backtitle "$VERSION" --title "-| Einstellungen |-" --infobox "\n${1}" 0 0
	arch-chroot /mnt /bin/bash -c "${1}" 2>>/tmp/.errlog
	check_error
}  
pac_strap() {
	dialog --backtitle "$VERSION" --title "-| Installiere |-" --infobox "\n${1}" 0 0 && sleep 2
	pacstrap /mnt ${1} --needed 2>>/tmp/.errlog
	check_error
}
check_error() {
	if [[ $? -eq 1 ]] && [[ $(cat /tmp/.errlog | grep -i "error") != "" ]]; then
		dialog --backtitle "$VERSION" --title "-| Fehler |-" --msgbox "$(cat /tmp/.errlog)" 0 0
	fi
	echo "" > /tmp/.errlog
}
umount_partitions(){
	dialog --backtitle "$VERSION" --title "-| Unmaunte |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	MOUNTED=""
	MOUNTED=$(mount | grep "/mnt" | awk '{print $3}' | sort -r)
	swapoff -a
	for i in ${MOUNTED[@]}; do
		umount $i >/dev/null
	done
}
id_sys() {
	dialog --backtitle "$VERSION" --title "-| Sprache |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	# Sprache
	sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen
	locale-gen >/dev/null 2>&1
	export LANG=${LOCALE}
	# Keymap
	loadkeys $KEYMAP
	# Test
	dialog --backtitle "$VERSION" --title "-| Systemprüfung |-" --infobox "\nTeste Voraussetzungen\n\n" 0 0 && sleep 2
	if [[ `whoami` != "root" ]]; then
		dialog --backtitle "$VERSION" --title "-| Fehler |-" --infobox "\ndu bist nicht 'root'\nScript wird beendet\n" 0 0 && sleep 2
		exit 1
	fi
	if [[ ! $(ping -c 1 google.com) ]]; then
		dialog --backtitle "$VERSION" --title "-| Fehler |-" --infobox "\nkein Internet Zugang.\nScript wird beendet\n" 0 0 && sleep 2
		exit 1
	fi
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
	DEVICE=$(dialog --nocancel --backtitle "$VERSION" --title "-| Laufwerk |-" --menu "zum Installieren" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
	IDEV=`echo $DEVICE | cut -c6-`
	HD_SD="HDD"
	if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
	VERSION="-| Arch Installation ($ARCHI) |- $SYSTEM auf $HD_SD |-"
	dialog --backtitle "$VERSION" --title "-| Wipen |-" --yesno "\nWARNUNG:\nAlle Daten unwiederuflich auf ${DEVICE} löschen\n\n" 0 0
	if [[ $? -eq 0 ]]; then WIPE="YES" ; fi
}
sel_hostname() {
	HOSTNAME=$(dialog --nocancel --backtitle "$VERSION" --title "-| Hostname |-" --stdout --inputbox "PC-Namen:" 0 0 "")
	if [[ $HOSTNAME =~ \ |\' ]] || [[ $HOSTNAME =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$VERSION" --title "-| FEHLER |-" --msgbox "\nUngültiger PC-Name\n\n" 0 0
		sel_hostname
	fi
}
sel_user() {
	FULLNAME=$(dialog --nocancel --backtitle "$VERSION" --title "-| Benutzer |-" --stdout --inputbox "Vornamen & Nachnamen" 0 0 "")
	USERNAME=$(dialog --nocancel --backtitle "$VERSION" --title "-| Benutzer |-" --stdout --inputbox "Anmeldenamen" 0 0 "")
	if [[ $USERNAME =~ \ |\' ]] || [[ $USERNAME =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$VERSION" --title "-| FEHLER |-" --msgbox "\nUngültiger Benutzername\n\n" 0 0
		sel_user
	fi
}
sel_password() {
	RPASSWD=$(dialog --nocancel --backtitle "$VERSION" --title "-| Root & $USERNAME |-" --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --nocancel --backtitle "$VERSION" --title " | Root & $USERNAME |-" --stdout --clear --insecure --passwordbox "Passwort bestätigen:" 0 0 "")
	if [[ $RPASSWD == $RPASSWD2 ]]; then 
		echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
	else
		dialog --backtitle "$VERSION" --title "-| FEHLER |-" --msgbox "\nPasswörter stimmen nicht überein\n\n" 0 0
		sel_password
	fi
}

############
## Setzen ##
############
set_partitions() {
	if [[ $WIPE == "YES" ]]; then
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm --needed wipe
		fi	
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --infobox "\nWipe Bitte warten\n\n" 0 0
		wipe -Ifre ${DEVICE}
	else
		sgdisk --zap-all ${DEVICE}
	fi
	if [[ $SYSTEM == "BIOS" ]]; then
		parted -s ${DEVICE} mklabel gpt
		parted -s ${DEVICE} mkpart primary ext4 1MiB 100%
		parted -s ${DEVICE} set 1 boot on
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --infobox "\nHarddisk $DEVICE wird Formatiert\n\n" 0 0
		echo j | mkfs.ext4 -q -L arch ${DEVICE}1 >/dev/null
		mount ${DEVICE}1 /mnt
	fi
	if [[ $SYSTEM == "UEFI" ]]; then
		parted -s ${DEVICE} mklabel gpt
		parted -s ${DEVICE} mkpart ESP fat32 1MiB 513MiB
		parted -s ${DEVICE} mkpart primary ext4 513MiB 100%
		parted -s ${DEVICE} set 1 boot on
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --infobox "\nHarddisk $DEVICE wird Formatiert\n\n" 0 0
		echo j | mkfs.vfat -F32 ${DEVICE}1 >/dev/null
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 >/dev/null
		mount ${DEVICE}2 /mnt
		mkdir -p /mnt/boot
		mount ${DEVICE}1 /mnt/boot
	fi		
	if [[ $HD_SD == "HDD" ]]; then
		dialog --backtitle "$VERSION" --title "-| Swap-File |-" --infobox "\nwird angelegt\n\n" 0 0 && sleep 2
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile >/dev/null
		swapon /mnt/swapfile >/dev/null
	fi
}
set_mirrorlist() {
	if ! (</etc/pacman.d/mirrorlist grep "rankmirrors" &>/dev/null) then
		dialog --backtitle "$VERSION" --title "-| Spiegelserver |-" --infobox "\nBitte warten\n\n" 0 0 && sleep 2
		URL="https://www.archlinux.org/mirrorlist/?country=${CODE}&use_mirror_status=on"
		MIRROR_TEMP=$(mktemp --suffix=-mirrorlist)
		curl -so ${MIRROR_TEMP} ${URL}
		sed -i 's/^#Server/Server/g' ${MIRROR_TEMP}
		mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
		dialog --backtitle "$VERSION" --title "-| Spiegelserver |-" --infobox "\nsortieren\nBitte warten\n\n" 0 0 && sleep 2
		rankmirrors -n 10 ${MIRROR_TEMP} > /etc/pacman.d/mirrorlist
		chmod +r /etc/pacman.d/mirrorlist
		dialog --backtitle "$VERSION" --title "-| Spiegelserver |-" --infobox "\nBitte warten\n\n" 0 0 && sleep 2
		if [ $(uname -m) == x86_64 ]; then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /etc/pacman.conf
		fi
		pacman-key --init
		pacman-key --populate archlinux
		pacman -Syy
	fi
}
gen_fstab() {
	dialog --backtitle "$VERSION" --title "-| genfstab |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	if [[ $SYSTEM == "BIOS" ]]; then
		genfstab -U -p /mnt > /mnt/etc/fstab
	fi
	if [[ $SYSTEM == "UEFI" ]]; then
		genfstab -t PARTUUID -p /mnt > /mnt/etc/fstab
	fi
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
}
set_info() {
	dialog --backtitle "$VERSION" --title "-| Einstellungen |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	echo "${HOSTNAME}" > /mnt/etc/hostname
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts

	echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen
	arch_chroot "locale-gen" >/dev/null

#	echo -e "KEYMAP=${KEYMAP}\nFONT=" > /mnt/etc/vconsole.conf
	arch_chroot "localectl --no-convert set-keymap ${KEYMAP}"

	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf
	fi

	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"

	arch_chroot "hwclock --systohc --utc"

	arch_chroot "passwd root" < /tmp/.passwd >/dev/null

	dialog --backtitle "$VERSION" --title "-| Benutzer |-" --infobox "\nwird erstellt\n\n" 0 0 sleep 2
	arch_chroot "groupadd -r autologin -f"
	arch_chroot "groupadd -r plugdev -f"
	arch_chroot "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,plugdev,storage,power,network,video,audio,lp -s /bin/bash"
	arch_chroot "passwd ${USERNAME}" < /tmp/.passwd >/dev/null
	rm /tmp/.passwd
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
#	sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers

	dialog --backtitle "$VERSION" --title "-| mkinitcpio |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	arch_chroot "mkinitcpio -p linux"
}
set_xkbmap() {
	dialog --backtitle "$VERSION" --title "-| Tastatur |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
#	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
	arch_chroot "localectl --no-convert set-x11-keymap ${XKBMAP} pc105 nodeadkeys"
}
set_mediaelch() {		
	dialog --backtitle "$VERSION" --title "-| MediaElch |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	echo "#!/bin/sh" > /mnt/usr/bin/elch
	echo "wakeonlan 00:01:2e:3a:5e:81" >> /mnt/usr/bin/elch
	echo "sudo mkdir /mnt/Serien1" >> /mnt/usr/bin/elch
	echo "sudo mkdir /mnt/Serien2" >> /mnt/usr/bin/elch
	echo "sudo mkdir /mnt/Filme1" >> /mnt/usr/bin/elch
	echo "sudo mkdir /mnt/Filme2" >> /mnt/usr/bin/elch
	echo "sudo mkdir /mnt/Musik" >> /mnt/usr/bin/elch
	echo "sudo mount -t nfs4 192.168.2.250:/export/Serien1 /mnt/Serien1" >> /mnt/usr/bin/elch
	echo "sudo mount -t nfs4 192.168.2.250:/export/Serien2 /mnt/Serien2" >> /mnt/usr/bin/elch
	echo "sudo mount -t nfs4 192.168.2.250:/export/Filme1 /mnt/Filme1" >> /mnt/usr/bin/elch
	echo "sudo mount -t nfs4 192.168.2.250:/export/Filme2 /mnt/Filme2" >> /mnt/usr/bin/elch
	echo "sudo mount -t nfs4 192.168.2.250:/export/Musik /mnt/Musik" >> /mnt/usr/bin/elch
	echo "MediaElch" >> /mnt/usr/bin/elch
	echo "sudo umount /mnt/Serien1" >> /mnt/usr/bin/elch
	echo "sudo umount /mnt/Serien2" >> /mnt/usr/bin/elch
	echo "sudo umount /mnt/Filme1" >> /mnt/usr/bin/elch
	echo "sudo umount /mnt/Filme2" >> /mnt/usr/bin/elch
	echo "sudo umount /mnt/Musik" >> /mnt/usr/bin/elch
	echo "sudo rmdir /mnt/Serien1" >> /mnt/usr/bin/elch
	echo "sudo rmdir /mnt/Serien2" >> /mnt/usr/bin/elch
	echo "sudo rmdir /mnt/Filme1" >> /mnt/usr/bin/elch
	echo "sudo rmdir /mnt/Filme2" >> /mnt/usr/bin/elch
	echo "sudo rmdir /mnt/Musik" >> /mnt/usr/bin/elch
	chmod +x /mnt/usr/bin/elch
	mkdir -p /mnt/home/${USERNAME}/.config/kvibes/
	echo "[Directories]" > /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Concerts\size=0" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Downloads\1\autoReload=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Downloads\1\path=/home/monty/Downloads" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Downloads\1\sepFolders=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Downloads\size=1" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\1\autoReload=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\1\path=/mnt/Filme1" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\1\sepFolders=true" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\2\autoReload=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\2\path=/mnt/Filme2" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\2\sepFolders=true" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Movies\size=2" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Music\1\autoReload=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Music\1\path=/mnt/Musik" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Music\1\sepFolders=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Music\size=1" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TvShows\1\autoReload=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TvShows\1\path=/mnt/Serien1" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TvShows\2\autoReload=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TvShows\2\path=/mnt/Serien2" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TvShows\size=2" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "[Downloads]" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "DeleteArchives=true" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "KeepSource=true" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "Unrar=/bin/unrar" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "[Scrapers]" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "AEBN\Language=en" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "FanartTv\DiscType=BluRay" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "FanartTv\Language=de" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "FanartTv\PersonalApiKey=" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "ShowAdult=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TMDb\Language=de" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TMDbConcerts\Language=en" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "TheTvDb\Language=de" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "UniversalMusicScraper\Language=en" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "UniversalMusicScraper\Prefer=theaudiodb" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "[TvShows]" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "DvdOrder=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "ShowMissingEpisodesHint=true" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "[Warnings]" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "DontShowDeleteImageConfirm=false" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "[XBMC]" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "RemoteHost=192.168.2.251" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "RemotePassword=xbmc" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "RemotePort=80" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
	echo "RemoteUser=xbmc	" >> /mnt/home/${USERNAME}/.config/kvibes/MediaElch.conf
}

#############
## Install ##
#############
ins_base() {
	pac_strap "base base-devel"
}
ins_bootloader() {
	arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl"
	if [[ $SYSTEM == "BIOS" ]]; then		
		if [[ $DEVICE != "" ]]; then
			dialog --backtitle "$VERSION" --title "-| Grub-install |-" --infobox "\nBitte warten\n\n" 0 0 && sleep 2
			pac_strap "grub dosfstools"
			arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		fi
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		if [[ $DEVICE != "" ]]; then
			dialog --backtitle "$VERSION" --title "-| Grub-install |-" --infobox "\nBitte warten\n\n" 0 0 && sleep 2
			pac_strap "grub efibootmgr dosfstools"
			arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			arch_chroot "mkdir -p /boot/EFI/boot"
			arch_chroot "mv -r /boot/EFI/arch_grub/grubx64.efi /boot/EFI/boot/bootx64.efi"
		fi
	fi
}
ins_xorg() {
	pac_strap "xorg-server xorg-server-utils xorg-twm xorg-xclock xorg-xinit"
	pac_strap "xf86-input-keyboard xf86-input-mouse xf86-input-libinput xf86-input-joystick"
	cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/${USERNAME}/.xinitrc
	arch_chroot "chown -R ${USERNAME}:users /home/${USERNAME}"
}
ins_graphics_card() {
	dialog --backtitle "$VERSION" --title "-| Grafikkarte |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	ins_intel(){
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
	ins_ati(){
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
		elif [[ $(dmesg | grep -i 'chipset' | grep -i 'nva\|nv5\|nv8\|nv9'?) != "" ]]; then HIGHLIGHT_SUB_GC=5
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
		ins_ati
	fi
	if [[ $HIGHLIGHT_SUB_GC == 2 ]] ; then
		ins_intel
	fi
	if [[ $HIGHLIGHT_SUB_GC == 3 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
		pac_strap "xf86-video-nouveau"
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pac_strap "${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings"
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pac_strap "${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings"
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
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
}
ins_de_wm() {
	pac_strap "mate-gtk3 mate-extra-gtk3"
}
ins_dm() {
	pac_strap "lightdm lightdm-gtk-greeter accountsservice"
	sed -i "s/#autologin-user=/autologin-user=${USERNAME}/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf
	arch_chroot "systemctl enable lightdm.service"
	arch_chroot "systemctl enable accounts-daemon"
}
ins_hw() {
	#Netzwerkkarte
	pac_strap "networkmanager network-manager-applet"
	arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service"
	#WiFi
	if (dmesg | grep -i Wireless &> /dev/null); then 
		pac_strap "wireless_tools wpa_actiond wpa_supplicant dialog rp-pppoe"
	fi
	#Drucker
	pac_strap "cups system-config-printer hplip"
	arch_chroot "systemctl enable org.cups.cupsd.service"
	#SSD
	if [[ $HD_SD == "SSD" ]]; then
		arch_chroot "systemctl enable fstrim.service"
		arch_chroot "systemctl enable fstrim.timer"
	fi
	#Bluetoo
	if (dmesg | grep -i Bluetooth &> /dev/null); then 
		pac_strap "bluez bluez-utils blueman"
		arch_chroot "systemctl enable bluetooth.service"
	fi
	#Touchpad
	if (dmesg | grep -i Touchpad &> /dev/null); then
		pac_strap "xf86-input-synaptics"
	fi
	#Wacom
	if (dmesg | grep -i Tablet &> /dev/null); then
		pac_strap "xf86-input-wacom"
	fi
	if (dmesg | grep -i Wacom &> /dev/null); then
		pac_strap "xf86-input-wacom"
	fi
}
ins_jdownloader() {
	dialog --backtitle "$VERSION" --title "-| JDownloader|-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	mkdir -p /mnt/opt/JDownloader/
	wget -c -O /mnt/opt/JDownloader/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar
	arch_chroot "chown -R 1000:1000 /opt/JDownloader/"
	arch_chroot "chmod -R 0775 /opt/JDownloader/"
	echo "[Desktop Entry]" > /mnt/usr/share/applications/JDownloader.desktop
	echo "Name=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Comment=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Exec=java -jar /opt/JDownloader/JDownloader.jar" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Icon=/opt/JDownloader/themes/standard/org/jdownloader/images/logo/jd_logo_64_64.png" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Terminal=false" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Type=Application" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "StartupNotify=false" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Categories=Network;Application;" >> /mnt/usr/share/applications/JDownloader.desktop
}
ins_apps() {
	#Firmware
	pac_strap "bash-completion gksu python2-xdg xdg-user-dirs xdg-utils"
	#Office
	pac_strap "libreoffice-fresh libreoffice-fresh-${SPRA} thunderbird thunderbird-i18n-${SPRA} hunspell-${SPRA} aspell-${SPRA} ttf-droid ttf-dejavu ttf-liberation ttf-bitstream-vera"
	#Firmware
	pac_strap "gimp gimp-help-${SPRA} gthumb shotwell xsane xsane-gimp vlc avidemux-gtk handbrake clementine mkvtoolnix-gui picard meld unrar ZIP UNZIP p7zip lzop cpio"
	#Firmware
	pac_strap "flashplugin geany pitivi frei0r-plugins xfburn simplescreenrecorder qbittorrent mlocate pkgstats jre7-openjdk"
	#Firmware
	pac_strap "libaacs tlp tlp-rdw ffmpegthumbs ffmpegthumbnailer x264 upx nss-mdns libquicktime libdvdcss cdrdao wqy-microhei"
	#Firmware
	pac_strap "pulseaudio pulseaudio-alsa pavucontrol alsa-utils alsa-plugins fuse-exfat autofs mtpfs icoutils gparted gst-plugins-ugly gst-libav pavucontrol cairo-dock cairo-dock-plug-ins"
	#Firmware
	pac_strap "gstreamer0.10-bad gstreamer0.10-bad-plugins gstreamer0.10-good gstreamer0.10-good-plugins gstreamer0.10-ugly gstreamer0.10-ugly-plugins gstreamer0.10-ffmpeg"
	#Firmware
	pac_strap "ntfs-3g exfat-utils f2fs-tools gvfs gvfs-afc gvfs-mtp gvfs-google gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav ffmpeg llibdvdnav"
	#wine
	dialog --backtitle "$VERSION" --title "-| Wine |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	pacman -Syy --noconfirm
	pacman -Syu --noconfirm
	arch_chroot "pacman -Syy --noconfirm"
	arch_chroot "pacman -Syu --noconfirm"
	pac_strap "playonlinux winetricks wine wine_gecko wine-mono steam"
	#lib32
	[[ $(uname -m) == x86_64 ]] && pac_strap "lib32-alsa-plugins lib32-libpulse"
	#Firefox
	pac_strap "firefox firefox-i18n-${SPRA}"
	arch_chroot "upx --best /usr/lib/firefox/firefox"
	#NFS
	pac_strap "nfs-utils"
	arch_chroot "systemctl enable rpcbind"
	arch_chroot "systemctl enable nfs-client.target"
	arch_chroot "systemctl enable remote-fs.target"
}
ins_finish() {
	dialog --backtitle "$VERSION" --title "-| entpacke |-" --infobox "\n Bitte warten \n" 0 0
	pacman -S p7zip --noconfirm --needed
	7z x teamviewer.pkg.7z.001
	dialog --backtitle "$VERSION" --title "-| Appikationen |-" --infobox "\n Bitte warten \n" 0 0 && sleep 2
	mv *.pkg.tar.xz /mnt/
	#Firmware
	arch_chroot "pacman -U aic94xx-firmware.pkg.tar.xz --noconfirm --needed"
	arch_chroot "pacman -U wd719x-firmware.pkg.tar.xz --noconfirm --needed"
	arch_chroot "pacman -U dbus-x11.pkg.tar.xz --noconfirm --needed"
	#Mediaelch
	arch_chroot "pacman -U mediaelch.pkg.tar.xz --noconfirm --needed"
	#mintstick
	arch_chroot "pacman -U python2-pyparted.pkg.tar.xz --noconfirm --needed"
	arch_chroot "pacman -U mintstick.pkg.tar.xz --noconfirm --needed"
	#themes icons
	arch_chroot "pacman -U mint-themes.pkg.tar.xz --noconfirm --needed"
	arch_chroot "pacman -U mint-x-icons.pkg.tar.xz --noconfirm --needed"
	#mp3diags
	mv mp3gain /mnt/usr/bin/
	chmod +x /mnt/usr/bin/mp3gain
	mv mp3diags_de_DE.qm /mnt/usr/bin/
	arch_chroot "pacman -U mp3diags-unstable.pkg.tar.xz --noconfirm --needed"
	#pamac
	arch_chroot "pacman -U pamac.pkg.tar.xz --noconfirm --needed"
	#Skype
	arch_chroot "pacman -U skype.pkg.tar.xz --noconfirm --needed"
	#wakeonlan
	arch_chroot "pacman -U wakeonlan.pkg.tar.xz --noconfirm --needed"
	#yaourt
	arch_chroot "pacman -U package-query.pkg.tar.xz --noconfirm --needed"
	arch_chroot "pacman -U yaourt.pkg.tar.xz --noconfirm --needed"
	#Fingerprint
	if (lsusb | grep Fingerprint &> /dev/null); then
		arch_chroot "pacman -U fingerprint-gui.pkg.tar.xz --noconfirm --needed"
	fi
	#Teamviewer
	arch_chroot "pacman -U teamviewer.pkg.tar.xz --noconfirm --needed"
	arch_chroot "systemctl enable teamviewerd"
	#clean
	arch_chroot "mv *.pkg.tar.xz /tmp/"
	arch_chroot "pacman -Rsc --noconfirm $(pacman -Qqdt)"
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
set_info
set_mediaelch
ins_xorg
ins_graphics_card
ins_de_wm
ins_dm
set_xkbmap
ins_hw
ins_jdownloader
ins_finish

umount_partitions
dialog --backtitle "$VERSION" --title "-| Installation Fertig |-" --infobox "\nInstall Medium entfernen\nBei der ersten Anmeldung muss dass Passwort noch eingegeben werden\n" 0 0 && sleep 4
shutdown now
exit 0
