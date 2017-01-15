#!/bin/bash
arch_chroot() {
	arch-chroot /mnt /bin/bash -c "${1}"
}
id_sys() {
	# update
	dialog --title " System-refresh " --infobox "\nneuste Version wird gesucht" 0 0 && sleep 2
	clear
	echo "" > /tmp/.errlog
	clear
	pacman -Syy
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
}
sel_info() {
	#kein schwarzes Bild
	setterm -blank 0 -powersave off
	# default
	LOCALE="de_CH.UTF-8"
	LANGUAGE="de_DE"
	KEYMAP="de_CH-latin1"
	ZONE="Europe"
	SUBZONE="Zurich"
	XKBMAP="ch"
	# Keymap
	export LANG=${LOCALE}
	loadkeys $KEYMAP
	#Benutzer?
	sel_user() {
		FULLNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Vornamen & Nachnamen" 0 0 "")
		USERNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Anmeldenamen" 0 0 "")
		if [[ $USERNAME =~ \ |\' ]] || [[ $USERNAME =~ [^a-z0-9\ ] ]]; then
			dialog --title " FEHLER " --msgbox "\nUngültiger Benutzername" 0 0
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
		DEVICE=$(dialog --nocancel --title " Laufwerk " --menu "zum Installieren" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
		IDEV=`echo $DEVICE | cut -c6-`
		HD_SD="HDD"
		if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
		dialog --title " Wipen " --yesno "\nWARNUNG:\nAlle Daten unwiederuflich auf ${DEVICE} löschen" 0 0
		if [[ $? -eq 0 ]]; then WIPE="YES" ; fi
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
	if [[ $WIPE == "YES" ]]; then
		dialog --title " Harddisk " --infobox "\nWipe Bitte warten" 0 0
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm wipe
		fi	
		wipe -Ifre ${DEVICE}
	else
		dialog --title " Harddisk " --infobox "\nlöschen Bitte warten" 0 0
		sgdisk --zap-all ${DEVICE}
		wipefs -a ${DEVICE}
	fi
	#BIOS Part?
	if [[ $SYSTEM == "BIOS" ]]; then
		dialog --title " Harddisk " --infobox "\nHarddisk $DEVICE wird Formatiert" 0 0
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE}
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2
		mount ${DEVICE}2 /mnt
	fi
	#UEFI Part?
	if [[ $SYSTEM == "UEFI" ]]; then
		dialog --title " Harddisk " --infobox "\nHarddisk $DEVICE wird Formatiert" 0 0
		echo -e "o\ny\nn\n1\n\n+512M\nEF00\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE}	
		echo j | mkfs.vfat -F32 ${DEVICE}1 
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2
		mount ${DEVICE}2 /mnt
		mkdir -p /mnt/boot
		mount ${DEVICE}1 /mnt/boot
	fi		
	#Swap?
	if [[ $HD_SD == "HDD" ]]; then
		dialog --title " Swap " --infobox "\nBitte warten" 0 0
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile
		swapon /mnt/swapfile
	fi
	#Mirror?
	if ! (</etc/pacman.d/mirrorlist grep "reflector" &>/dev/null) then
		dialog --title " Mirror " --infobox "\nBitte warten" 0 0
		pacman -Sy reflector --needed --noconfirm &>>/tmp/error.log
		reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
		(pacman-key --init
		pacman-key --populate archlinux)
		pacman -Syy &>>/tmp/error.log
	fi
}
ins_base() {
ins_graphics_card() {
	ins_intel(){
		pacstrap /mnt xf86-video-intel libva-intel-driver intel-ucode --needed
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
		pacstrap /mnt xf86-video-ati --needed
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
		pacstrap /mnt xf86-video-nouveau --needed
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pacstrap /mnt ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings --needed
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings --needed
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-304xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-304xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-304xx-libgl nvidia-304xx-utils nvidia-settings --needed
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 7 ]] ; then
		pacstrap /mnt xf86-video-openchrome --needed
	fi
	if [[ $HIGHLIGHT_SUB_GC == 8 ]] ; then
		[[ -e /mnt/boot/initramfs-linux.img ]] && VB_MOD="linux-headers"
		[[ -e /mnt/boot/initramfs-linux-grsec.img ]] && VB_MOD="$VB_MOD linux-grsec-headers"
		[[ -e /mnt/boot/initramfs-linux-zen.img ]] && VB_MOD="$VB_MOD linux-zen-headers"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && VB_MOD="$VB_MOD linux-lts-headers"
		pacstrap /mnt virtualbox-guest-utils virtualbox-guest-dkms $VB_MOD --needed
		umount -l /mnt/dev
		arch_chroot "modprobe -a vboxguest vboxsf vboxvideo"
		arch_chroot "systemctl enable vboxservice"
		echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 9 ]] ; then
		pacstrap /mnt xf86-video-vmware xf86-input-vmmouse --needed
	fi
	if [[ $HIGHLIGHT_SUB_GC == 10 ]] ; then
		pacstrap /mnt xf86-video-fbdev --needed
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
	dialog --title " Installiere Base " --infobox "\nBitte warten" 0 0
	pacstrap /mnt base base-devel --needed
	#GRUB
	if [[ $SYSTEM == "BIOS" ]]; then		
		dialog --title " Installiere Grub " --infobox "\nBitte warten" 0 0
		pacstrap /mnt grub dosfstools --needed
		arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		genfstab -U -p /mnt > /mnt/etc/fstab
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		dialog --title " Installiere Grub " --infobox "\nBitte warten" 0 0
		pacstrap /mnt efibootmgr dosfstools grub gptfdisk --needed
		arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot"
		arch_chroot "bootctl --path=/boot install"
		genfstab -t PARTUUID -p /mnt > /mnt/etc/fstab
		bl_root=$"PARTUUID="$(blkid -s PARTUUID ${DEVICE}2 | sed 's/.*=//g' | sed 's/"//g')
 		echo -e "default  arch\ntimeout 1" > /mnt/boot/loader/loader.conf
		echo -e "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\troot=${bl_root} rw" > /mnt/boot/loader/entries/arch.conf
	fi
	#SWAP
	dialog --title " erstelle Swap " --infobox "\nBitte warten" 0 0
	echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
	#Hostname
	dialog --title " Hostname " --infobox "\nBitte warten" 0 0
	echo "${HOSTNAME}" > /mnt/etc/hostname
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts
	#Locale
	dialog --title " Sprache " --infobox "\nBitte warten" 0 0
	echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
	echo LC_COLLATE=C >> /mnt/etc/locale.conf
	echo LANGUAGE=${LANGUAGE} >> /mnt/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen
	arch_chroot "locale-gen" >/dev/null
	export LANG=${LOCALE}
	#Console
	dialog --title " Konsole " --infobox "\nBitte warten" 0 0
	echo -e "KEYMAP=${KEYMAP}" > /mnt/etc/vconsole.conf
	echo FONT=lat9w-16 >> /mnt/etc/vconsole.conf
	#Multi Mirror
	if [ $(uname -m) == x86_64 ]; then
		dialog --title " Mirror 64 " --infobox "\nBitte warten" 0 0
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf
	fi
	#Yaourt Mirror
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then echo -e "\n[archlinuxfr]\nSigLevel = Never\nServer = http://repo.archlinux.fr/$(uname -m)" >> /mnt/etc/pacman.conf ; fi
	dialog --title " Yaourt " --infobox "\nBitte warten" 0 0
	arch_chroot "pacman -Sy yaourt --needed --noconfirm"
	#Zone
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
	#Zeit
	arch_chroot "hwclock --systohc --utc"
	#PW
	dialog --title " Benutzer " --infobox "\nBitte warten" 0 0
	arch_chroot "passwd root" < /tmp/.passwd >/dev/null
	#Benutzer
	arch_chroot "groupadd -r autologin -f"
	arch_chroot "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys -s /bin/bash"																 
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
	sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
	arch_chroot "passwd ${USERNAME}" < /tmp/.passwd >/dev/null && rm /tmp/.passwd
	#mkinitcpio
	dialog --title " mkinitcpio " --infobox "\nBitte warten" 0 0
	mv aic94xx-seq.fw /mnt/lib/firmware/
	mv wd719x-risc.bin /mnt/lib/firmware/
	mv wd719x-wcs.bin /mnt/lib/firmware/
	KERNEL=""
	KERNEL=$(ls /mnt/boot/*.img | grep -v "fallback" | sed "s~/mnt/boot/initramfs-~~g" | sed s/\.img//g | uniq)
	for i in ${KERNEL}; do
		arch_chroot "mkinitcpio -p ${i}"
	done
	#xorg
	dialog --title " XORG " --infobox "\nBitte warten" 0 0
	pacstrap /mnt bc rsync mlocate pkgstats ntp bash-completion mesa gamin gksu gnome-keyring gvfs gvfs-mtp gvfs-afc gvfs-gphoto2 gvfs-nfs gvfs-smb polkit poppler python2-xdg ntfs-3g exfat-utils f2fs-tools fuse fuse-exfat mtpfs ttf-dejavu xdg-user-dirs xdg-utils autofs unrar p7zip lzop cpio zip arj unace unzip --needed &>>/tmp/error.log
	pacstrap /mnt xorg-server xorg-server-utils xorg-xinit xorg-xkill xorg-twm xorg-xclock xterm xf86-input-keyboard xf86-input-mouse xf86-input-libinput --needed &>>/tmp/error.log
	arch_chroot "timedatectl set-ntp true"
	#Drucker
	dialog --title " Drucker " --infobox "\nBitte warten" 0 0
	pacstrap /mnt cups system-config-printer hplip cups-filters cups-pdf ghostscript gsfonts gutenprint foomatic-db foomatic-db-engine foomatic-db-nonfree foomatic-filters splix --needed &>>/tmp/error.log
	arch_chroot "systemctl enable org.cups.cupsd.service"
	#TLP
	dialog --title " suche Hardware " --infobox "\nBitte warten" 0 0
	pacstrap /mnt tlp --needed
	arch_chroot "systemctl enable tlp.service && systemctl enable tlp-sleep.service && systemctl disable systemd-rfkill.service && tlp start"
	#WiFi
	[[ $(lspci | grep -i "Network Controller") != "" ]] && pacstrap /mnt dialog iw rp-pppoe wireless_tools wpa_actiond wpa_supplicant --needed &>>/tmp/error.log													  
	#Bluetoo
	[[ $(dmesg | grep -i Bluetooth) != "" ]] && pacstrap /mnt blueman --needed && arch_chroot "systemctl enable bluetooth.service"
	#Touchpad
	[[ $(dmesg | grep -i Touchpad) != "" ]] && pacstrap /mnt xf86-input-synaptics --needed &>>/tmp/error.log
	#Tablet
	[[ $(dmesg | grep Tablet) != "" ]] && pacstrap /mnt xf86-input-wacom --needed &>>/tmp/error.log
	#SSD
	[[ $HD_SD == "SSD" ]] && arch_chroot "systemctl enable fstrim.service && systemctl enable fstrim.timer"
	#wine
	[[ $WINE == "YES" ]] && arch_chroot "pacman -S wine wine_gecko wine-mono winetricks xf86-input-joystick lib32-libxcomposite --needed --noconfirm"
	#Grafikkarte
	dialog --title " Grafikkarte " --infobox "\nBitte warten" 0 0
	ins_graphics_card
	#audio
	dialog --title " Sound " --infobox "\nBitte warten" 0 0
	pacstrap /mnt pulseaudio pulseaudio-alsa pavucontrol alsa-utils alsa-plugins nfs-utils jre7-openjdk wol avahi nss-mdns --needed &>>/tmp/error.log
	[[ ${ARCHI} == x86_64 ]] && arch_chroot "pacman -S lib32-alsa-plugins lib32-libpulse --needed --noconfirm"
	arch_chroot "systemctl enable avahi-daemon && systemctl enable avahi-dnsconfd && systemctl enable rpcbind && systemctl enable nfs-client.target && systemctl enable remote-fs.target"
	#libs
	dialog --title " Runtime " --infobox "\nBitte warten" 0 0
	pacstrap /mnt libquicktime cdrdao libaacs libdvdcss libdvdnav libdvdread gtk-engine-murrine --needed &>>/tmp/error.log
	pacstrap /mnt gstreamer0.10-base gstreamer0.10-base-plugins gstreamer0.10-ugly gstreamer0.10-ugly-plugins gstreamer0.10-good gstreamer0.10-good-plugins gstreamer0.10-bad gstreamer0.10-bad-plugins gstreamer0.10-ffmpeg gstreamer0.10 gstreamer0.10-plugins --needed &>>/tmp/error.log
	pacstrap /mnt gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav --needed &>>/tmp/error.log
	#Oberfäche
	dialog --title " Oberfläche " --infobox "\nBitte warten" 0 0
	pacstrap /mnt cinnamon nemo-fileroller nemo-preview gnome-terminal gnome-screenshot eog gnome-calculator --needed &>>/tmp/error.log
	#Anmeldescreen
	dialog --title " Anmeldung " --infobox "\nBitte warten" 0 0
	pacstrap /mnt lightdm lightdm-gtk-greeter accountsservice --needed &>>/tmp/error.log
	sed -i "s/#pam-service=lightdm/pam-service=lightdm/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#pam-autologin-service=lightdm-autologin/pam-autologin-service=lightdm-autologin/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#session-wrapper=\/etc\/lightdm\/Xsession/session-wrapper=\/etc\/lightdm\/Xsession/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user=/autologin-user=${USERNAME}/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf
	arch_chroot "systemctl enable lightdm.service"
	#x11 Tastatur
	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
	#Netzwerkkarte
	pacstrap /mnt networkmanager network-manager-applet --needed &>>/tmp/error.log
	arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service"
	#Office
	dialog --title " Office " --infobox "\nBitte warten" 0 0
	pacstrap /mnt libreoffice-fresh libreoffice-fresh-de ttf-liberation hunspell-de aspell-de firefox firefox-i18n-de flashplugin icedtea-web thunderbird thunderbird-i18n-de --needed &>>/tmp/error.log
	#Grafik
	dialog --title " Grafik " --infobox "\nBitte warten" 0 0
	pacstrap /mnt gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur shotwell simple-scan vlc handbrake clementine mkvtoolnix-gui meld deluge geany geany-plugins gtk-recordmydesktop picard gparted gthumb xfburn filezilla --needed &>>/tmp/error.log
	#jdownloader
	dialog --title " JDownloader " --infobox "\nBitte warten" 0 0
	_jdownloader
	#pamac
	dialog --title " Pamac " --infobox "\nBitte warten" 0 0
	arch_chroot "su - ${USERNAME} -c 'yaourt -S pamac-aur --noconfirm'"
	sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
	sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
	sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
	sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
	#Skype
	dialog --title " Skype " --infobox "\nBitte warten" 0 0
	arch_chroot "su - ${USERNAME} -c 'yaourt -S skype --noconfirm'"
	#Teamviewer
	dialog --title " Teamviewer " --infobox "\nBitte warten" 0 0
	arch_chroot "su - ${USERNAME} -c 'yaourt -S teamviewer --noconfirm'" 
	arch_chroot "systemctl enable teamviewerd"
	#Fingerprint
	if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
		dialog --title " Fingerprint " --infobox "\nBitte warten" 0 0
		arch_chroot "su - ${USERNAME} -c 'yaourt -S fingerprint-gui --noconfirm'"
		arch_chroot "usermod -a -G plugdev,scanner ${USERNAME}"
		if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
		if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
	fi
	#Mediaelch
	dialog --title " Einstellungen " --infobox "\nBitte warten" 0 0
	[[ $ELCH == "YES" ]] && arch_chroot "su - ${USERNAME} -c 'yaourt -S mediaelch --noconfirm'" && set_mediaelch
	#Settings
	tar -xf usr.tar.gz -C /mnt && arch_chroot "glib-compile-schemas /usr/share/glib-2.0/schemas/"
	#Benutzerrechte
	sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/g' /mnt/etc/sudoers
	cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$USERNAME/.xinitrc
	arch_chroot "chown -R ${USERNAME}:users /home/${USERNAME}"
	arch_chroot "pacman -Syu --noconfirm"
}
check_error() {
	if [[ $? -eq 0 ]] && [[ $(cat /tmp/error.log | grep -i "Fehler") != "" ]]; then
		dialog --title " Fehler " --msgbox "$(cat /tmp/error.log | grep -i "Fehler")" 0 0
		echo "" > /tmp/error.log
	fi 
	if [[ $? -eq 0 ]] && [[ $(cat /tmp/error.log | grep -i "Warnung") != "" ]]; then
		dialog --title " Warnung " --msgbox "$(cat /tmp/error.log | grep -i "Warnung")" 0 0
		echo "" > /tmp/error.log
	fi 
	if [[ $? -eq 0 ]] && [[ $(cat /tmp/error.log | grep -i "error") != "" ]]; then
		dialog --title " ERROR " --msgbox "$(cat /tmp/error.log | grep -i "error")" 0 0
		echo "" > /tmp/error.log
	fi 
}
id_sys
check_error
sel_info
check_error
ins_base
check_error
swapoff -a
umount -R /mnt
reboot
