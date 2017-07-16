#!/bin/bash

#kein schwarzes Bild
setterm -blank 0 -powersave off
# default
LOCALE="de_CH.UTF-8"
LANGUAGE="de_DE"
KEYMAP="de_CH-latin1"
ZONE="Europe"
SUBZONE="Zurich"
XKBMAP="ch"
export LANG=${LOCALE}
loadkeys $KEYMAP

#Prozesse
check_error() {
	if [[ $? -eq 0 ]] && [[ $(cat /tmp/error.log | grep -i "error") != "" ]]; then
		dialog --title " Error " --msgbox "$(cat /tmp/error.log)" 0 0
	fi
	if [[ $? -eq 0 ]] && [[ $(cat /tmp/error.log | grep -i "fehler") != "" ]]; then
		dialog --title " Fehler " --msgbox "$(cat /tmp/error.log)" 0 0
	fi
}
arch_strap() {
	pacstrap /mnt ${1} --needed &>> /tmp/error.log | dialog --title "-| Konfiguriere |-" --infobox "\n${1}" 0 0
}
arch_chroot() {
	arch-chroot /mnt /bin/bash -c "${1}" &>> /tmp/error.log | dialog --title "-| Installiere |-" --infobox "\n${1}" 0 0
}
_sys() {
	# Apple?
	if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true
	else
		modprobe -q efivarfs
	fi
	# UEFI oder nicht?
	if [[ -d "/sys/firmware/efi/" ]]; then
		if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
			mount -t efivarfs efivarfs /sys/firmware/efi/efivars
		fi
		SYSTEM="UEFI"
	else
		SYSTEM="BIOS"
	fi
	_select
}
_select() {
	#Benutzer?
	FULLNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Vornamen & Nachnamen" 0 0 "")
	sel_user() {
		USERNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Anmeldenamen" 0 0 "")
		if [[ $USERNAME =~ \ |\' ]] || [[ $USERNAME =~ [^a-z0-9\ ] ]]; then
			dialog --title " FEHLER " --msgbox "\nUngültiger Benutzername\n alles in Kleinbuchstaben" 0 0
			sel_user
		fi
	}
	#PW?
	sel_password() {
		RPASSWD=$(dialog --nocancel --title " Root & $USERNAME " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
		RPASSWD2=$(dialog --nocancel --title " Root & $USERNAME " --stdout --clear --insecure --passwordbox "Passwort wiederholen:" 0 0 "")
		if [[ $RPASSWD == $RPASSWD2 ]]; then 
			echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
		else
			dialog --title " FEHLER " --msgbox "\nPasswörter stimmen nicht überein" 0 0
			sel_password
		fi
	}
	#Host?
	sel_hostname() {
		HOSTNAME=$(dialog --nocancel --title " Hostname " --stdout --inputbox "PC-Namen:" 0 0 "")
		if [[ $HOSTNAME =~ \ |\' ]] || [[ $HOSTNAME =~ [^a-z0-9\ ] ]]; then
			dialog --title " FEHLER " --msgbox "\nUngültiger PC-Name" 0 0
			sel_hostname
		fi
	}
	#HDD?
	sel_hdd() {
		DEVICE=""
		devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
		for i in ${devices_list[@]}; do
			DEVICE="${DEVICE} ${i}"
		done
		DEVICE=$(dialog --nocancel --title " Laufwerk " --menu "Worauf soll Installiert werden" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
		IDEV=`echo $DEVICE | cut -c6-`
		HD_SD="HDD"
		if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
	}
	sel_user
	sel_password
	sel_hostname
	sel_hdd
	#Mediaelch?
	dialog --title " MediaElch " --yesno "\nMediaElch installieren" 0 0
	if [[ $? -eq 0 ]]; then ELCH="YES" ; fi
	#Wine?
	dialog --title " Windows Spiele " --yesno "\nWine installieren" 0 0
	if [[ $? -eq 0 ]]; then WINE="YES" ; fi
	#Wipe or zap?
	dialog --title " Wipen " --yesno "\nWARNUNG:\nAlle Daten auf ${DEVICE} löschen" 0 0
	if [[ $? -eq 0 ]]; then
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm wipe &> /dev/null
		fi	
		wipe -Ifre ${DEVICE} &> /dev/null | dialog --title " Harddisk " --infobox "\nWipe Bitte warten" 0 0
	else
		sgdisk --zap-all ${DEVICE} &> /dev/null | dialog --title " Harddisk " --infobox "\nlösche Infos der Harddisk\nBitte warten" 0 0
		wipefs -a ${DEVICE} &> /dev/null | dialog --title " Harddisk " --infobox "\nSammle neue Infos der Harddisk\nBitte warten" 0 0
	fi
	#BIOS Part?
	if [[ $SYSTEM == "BIOS" ]]; then
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} &> /dev/null
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 &> /dev/null | dialog --title " Harddisk " --infobox "\nHarddisk $DEVICE wird Formatiert\nBitte warten" 0 0
		mount ${DEVICE}2 /mnt
	fi
	#UEFI Part?
	if [[ $SYSTEM == "UEFI" ]]; then
		echo -e "o\ny\nn\n1\n\n+512M\nEF00\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} &> /dev/null
		echo j | mkfs.vfat -F32 ${DEVICE}1 &> /dev/null | dialog --title " Harddisk " --infobox "\nHarddisk $DEVICE (Boot) wird Formatiert" 0 0
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 &> /dev/null | dialog --title " Harddisk " --infobox "\nHarddisk $DEVICE (Root) wird Formatiert" 0 0
		mount ${DEVICE}2 /mnt
		mkdir -p /mnt/boot
		mount ${DEVICE}1 /mnt/boot
	fi		
	#Swap?
	if [[ $HD_SD == "HDD" ]]; then
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile &> /dev/null | dialog --title " erstelle Swap " --infobox "\nBitte warten" 0 0
		swapon /mnt/swapfile
	fi
	#Mirror?
	if ! (</etc/pacman.d/mirrorlist grep "reflector" &>/dev/null) then
		pacman -Sy reflector --needed --noconfirm &> /dev/null | dialog --title " Mirror download " --infobox "\nBitte warten" 0 0
		reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null | dialog --title " Mirror updates " --infobox "\nschnellste Mirrors werden gesucht\nBitte warten..." 0 0
		(pacman-key --init
		pacman-key --populate archlinux) &> /dev/null | dialog --title " Mirror refresh " --infobox "\nBitte warten" 0 0
		pacman -Syy &> /dev/null | dialog --title " System-refresh " --infobox "\nneuste Versionen werden gesucht\nBitte warten..." 0 0
	fi
	#Error
	check_error
	_base
}
_base() {
ins_graphics_card() {
	ins_intel(){
		pacstrap /mnt xf86-video-intel libva-intel-driver intel-ucode
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
		pacstrap /mnt xf86-video-ati
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
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		pacstrap /mnt xf86-video-nouveau
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pacstrap /mnt ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-304xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-304xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-304xx-libgl nvidia-304xx-utils nvidia-settings
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 7 ]] ; then
		pacstrap /mnt xf86-video-openchrome
	fi
	if [[ $HIGHLIGHT_SUB_GC == 8 ]] ; then
		[[ -e /mnt/boot/initramfs-linux.img ]] && VB_MOD="linux-headers"
		[[ -e /mnt/boot/initramfs-linux-grsec.img ]] && VB_MOD="$VB_MOD linux-grsec-headers"
		[[ -e /mnt/boot/initramfs-linux-zen.img ]] && VB_MOD="$VB_MOD linux-zen-headers"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && VB_MOD="$VB_MOD linux-lts-headers"
		pacstrap /mnt virtualbox-guest-utils virtualbox-guest-dkms $VB_MOD
		umount -l /mnt/dev
		arch_chroot "modprobe -a vboxguest vboxsf vboxvideo"
		arch_chroot "systemctl enable vboxservice"
		echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 9 ]] ; then
		pacstrap /mnt xf86-video-vmware xf86-input-vmmouse
	fi
	if [[ $HIGHLIGHT_SUB_GC == 10 ]] ; then
		pacstrap /mnt xf86-video-fbdev
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
_jdownloader() {
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
set_mediaelch() {		
	echo "#!/bin/sh" > /mnt/usr/bin/elch
	echo "wol 00:01:2e:3a:5e:81" >> /mnt/usr/bin/elch
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
	#BASE
	arch_strap "base base-devel"
	#GRUB
	if [[ $SYSTEM == "BIOS" ]]; then		
		arch_strap "grub dosfstools"
		arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		genfstab -U -p /mnt > /mnt/etc/fstab
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		arch_strap "efibootmgr dosfstools grub"
		arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		genfstab -U -p /mnt > /mnt/etc/fstab
	fi
	#SWAP	
	echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
	#Hostname
	echo "${HOSTNAME}" > /mnt/etc/hostname
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts
	#Locale
	echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
	echo LC_COLLATE=C >> /mnt/etc/locale.conf
	echo LANGUAGE=${LANGUAGE} >> /mnt/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen
	arch_chroot "locale-gen"
	#Console
	echo -e "KEYMAP=${KEYMAP}" > /mnt/etc/vconsole.conf
	echo FONT=lat9w-16 >> /mnt/etc/vconsole.conf
	#Multi Mirror
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf
	fi
	#Yaourt Mirror
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then echo -e "\n[archlinuxfr]\nSigLevel = Never\nServer = http://repo.archlinux.fr/$(uname -m)" >> /mnt/etc/pacman.conf ; fi
	arch_chroot "pacman -Sy yaourt --needed --noconfirm"
	#Zone
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
	#Zeit
	arch_chroot "hwclock --systohc --utc"
	#Root PW
	arch_chroot "passwd root" < /tmp/.passwd
	#Benutzer
	arch_chroot "groupadd -r autologin -f"
	arch_chroot "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys -s /bin/bash"																 
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
	sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
	arch_chroot "passwd ${USERNAME}" < /tmp/.passwd
	#mkinitcpio
	mv aic94xx-seq.fw /mnt/lib/firmware/
	mv wd719x-risc.bin /mnt/lib/firmware/
	mv wd719x-wcs.bin /mnt/lib/firmware/
	arch_chroot "mkinitcpio -p linux"
	#xorg
	arch_strap "bc rsync mlocate pkgstats ntp bash-completion mesa gamin gksu gnome-keyring gvfs gvfs-mtp gvfs-afc gvfs-gphoto2 gvfs-nfs gvfs-smb polkit poppler python2-xdg ntfs-3g f2fs-tools fuse fuse-exfat mtpfs ttf-dejavu xdg-user-dirs xdg-utils autofs unrar p7zip lzop cpio zip arj unace unzip"
	arch_strap "xorg-server xorg-server-utils xorg-xinit xorg-xkill xorg-twm xorg-xclock xterm xf86-input-keyboard xf86-input-mouse xf86-input-libinput"
	arch_chroot "timedatectl set-ntp true"
	#Drucker
	arch_strap "cups system-config-printer hplip cups-pdf gtk3-print-backends  ghostscript gsfonts gutenprint foomatic-db foomatic-db-engine foomatic-db-nonfree foomatic-filters splix"
	arch_chroot "systemctl enable org.cups.cupsd.service"
	#TLP
	arch_strap "tlp"
	arch_chroot "systemctl enable tlp.service && systemctl enable tlp-sleep.service && systemctl disable systemd-rfkill.service && tlp start"
	#WiFi
	[[ $(lspci | grep -i "Network Controller") != "" ]] && arch_strap "dialog rp-pppoe wireless_tools wpa_actiond wpa_supplicant"												  
	#Bluetoo
	[[ $(dmesg | grep -i Bluetooth) != "" ]] && arch_strap "blueman" && arch_chroot "systemctl enable bluetooth.service"
	#Touchpad
	[[ $(dmesg | grep -i Touchpad) != "" ]] && arch_strap "xf86-input-synaptics"
	#Tablet
	[[ $(dmesg | grep Tablet) != "" ]] && arch_strap "xf86-input-wacom"
	#SSD
	[[ $HD_SD == "SSD" ]] && arch_chroot "systemctl enable fstrim.service && systemctl enable fstrim.timer"
	#wine
	[[ $WINE == "YES" ]] && arch_chroot "pacman -S wine wine_gecko wine-mono winetricks lib32-libxcomposite --needed --noconfirm"
	#Grafikkarte
	ins_graphics_card &>> /tmp/error.log | dialog --title " Grafikkarte " --infobox "\nBitte warten" 0 0
	#audio
	arch_strap "pulseaudio pulseaudio-alsa pavucontrol alsa-utils alsa-plugins nfs-utils jre7-openjdk wol nss-mdns"
	[[ ${ARCHI} == x86_64 ]] && arch_chroot "pacman -S lib32-alsa-plugins lib32-libpulse --needed --noconfirm"
	arch_chroot "systemctl enable avahi-daemon && systemctl enable avahi-dnsconfd && systemctl enable rpcbind && systemctl enable nfs-client.target && systemctl enable remote-fs.target"
	#libs
	arch_strap "libquicktime cdrdao libaacs libdvdcss libdvdnav libdvdread gtk-engine-murrine"
	arch_strap "gstreamer0.10-base gstreamer0.10-ugly gstreamer0.10-good gstreamer0.10-bad gstreamer0.10 gstreamer0.10-plugins"
	arch_strap "gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav"
	#Oberfäche
	arch_strap "cinnamon nemo-fileroller nemo-preview gnome-terminal gnome-screenshot eog gnome-calculator"
	#Anmeldescreen
	arch_strap "lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
	sed -i "s/#pam-service=lightdm/pam-service=lightdm/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#pam-autologin-service=lightdm-autologin/pam-autologin-service=lightdm-autologin/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#session-wrapper=\/etc\/lightdm\/Xsession/session-wrapper=\/etc\/lightdm\/Xsession/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user=/autologin-user=${USERNAME}/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf
	arch_chroot "systemctl enable lightdm.service"
	#x11 Tastatur
	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
	#Netzwerkkarte
	arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service"
	#Office
	arch_strap "libreoffice-fresh libreoffice-fresh-de ttf-liberation hunspell-de aspell-de firefox firefox-i18n-de flashplugin icedtea-web thunderbird thunderbird-i18n-de"
	#Grafik
	arch_strap "gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur shotwell simple-scan vlc handbrake clementine mkvtoolnix-gui meld deluge geany geany-plugins gtk-recordmydesktop picard gparted gthumb xfburn filezilla"
	#jdownloader
	_jdownloader | dialog --title " JDownloader " --infobox "\nBitte warten" 0 0
	#pamac
	arch_chroot "su - ${USERNAME} -c 'yaourt -S pamac-aur --noconfirm'"
	sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
	sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
	sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
	sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
	#Skype
	#  arch_chroot "su - ${USERNAME} -c 'yaourt -S skype --noconfirm'"
	#Teamviewer
	arch_chroot "su - ${USERNAME} -c 'yaourt -S teamviewer --noconfirm'" 
	arch_chroot "systemctl enable teamviewerd"
	#Fingerprint
	if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
		arch_chroot "su - ${USERNAME} -c 'yaourt -S fingerprint-gui --noconfirm'"
		arch_chroot "usermod -a -G plugdev,scanner ${USERNAME}"
		if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
		if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
	fi
	#Mediaelch
	[[ $ELCH == "YES" ]] && arch_chroot "su - ${USERNAME} -c 'yaourt -S mediaelch --noconfirm'" && set_mediaelch
	#Settings
	tar -xf usr.tar.gz -C /mnt
	arch_chroot "glib-compile-schemas /usr/share/glib-2.0/schemas/"
	#Benutzerrechte
	sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/g' /mnt/etc/sudoers
	cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$USERNAME/.xinitrc
	cp xinitrc /mnt/home/$USERNAME/.xinitrc
	arch_chroot "chown -R ${USERNAME}:users /home/${USERNAME}"
	arch_chroot "pacman -Syu --noconfirm"
	#Error
	check_error
	cp -f /tmp/error.log /mnt/home/$USERNAME/error.log
	#Herunterfahren
	swapoff -a
	umount -R /mnt
	reboot
}
_sys
