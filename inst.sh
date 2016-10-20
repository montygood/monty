# !/bin/bash

arch_chroot() {
	arch-chroot /mnt /bin/bash -c "${1}" 2>>/tmp/.errlog
	if [[ $? -eq 1 ]] && [[ $(cat /tmp/.errlog | grep -i "error") != "" ]]; then
		dialog --backtitle "$VERSION" --title "-| Fehler |-" --msgbox "$(cat /tmp/.errlog)" 0 0
	fi
	echo "" > /tmp/.errlog
}

cerrror() {
	if [[ $? -eq 1 ]] && [[ $(cat /tmp/.paklog | grep -i "Reinstalliere") != "" ]]; then
		dialog --backtitle "$VERSION" --title "-| Installiert |-" --msgbox "$(cat /tmp/.paklog)" 0 0
	fi
	echo "" > /tmp/.paklog
}

id_sys() {
	VERSION=" -| Arch Installation ($(uname -m)) |- "

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
	clear
	pacman -Syy

	# Apple System
	if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true
	else
		modprobe -q efivarfs
	fi

	# BIOS or UEFI
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
	LOCALE="de_CH.UTF-8"
	KEYMAP="de_CH-latin1"
	CODE="CH"
	ZONE="Europe"
	SUBZONE="Zurich"
	XKBMAP="ch"

	# Keymap
	loadkeys $KEYMAP

	#Benutzer
	sel_user() {
		FULLNAME=$(dialog --nocancel --backtitle "$VERSION" --title "-| Benutzer |-" --stdout --inputbox "Vornamen & Nachnamen" 0 0 "")
		USERNAME=$(dialog --nocancel --backtitle "$VERSION" --title "-| Benutzer |-" --stdout --inputbox "Anmeldenamen" 0 0 "")
		if [[ $USERNAME =~ \ |\' ]] || [[ $USERNAME =~ [^a-z0-9\ ] ]]; then
			dialog --backtitle "$VERSION" --title "-| FEHLER |-" --msgbox "\nUngültiger Benutzername\n\n" 0 0
			sel_user
		fi
	}
	#PW
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
	#Host
	sel_hostname() {
		HOSTNAME=$(dialog --nocancel --backtitle "$VERSION" --title "-| Hostname |-" --stdout --inputbox "PC-Namen:" 0 0 "")
		if [[ $HOSTNAME =~ \ |\' ]] || [[ $HOSTNAME =~ [^a-z0-9\ ] ]]; then
			dialog --backtitle "$VERSION" --title "-| FEHLER |-" --msgbox "\nUngültiger PC-Name\n\n" 0 0
			sel_hostname
		fi
	}
	#HDD
	sel_hdd() {
		DEVICE=""
		devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
		for i in ${devices_list[@]}; do
			DEVICE="${DEVICE} ${i}"
		done
		DEVICE=$(dialog --nocancel --backtitle "$VERSION" --title "-| Laufwerk |-" --menu "zum Installieren" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
		IDEV=`echo $DEVICE | cut -c6-`
		HD_SD="HDD"
		if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
		VERSION="-| Arch Installation ($(uname -m)) |- $SYSTEM auf $HD_SD |-"
		dialog --backtitle "$VERSION" --title "-| Wipen |-" --yesno "\nWARNUNG:\nAlle Daten unwiederuflich auf ${DEVICE} löschen\n\n" 0 0
		if [[ $? -eq 0 ]]; then WIPE="YES" ; fi
	}

	sel_user
	sel_password
	sel_hostname
	sel_hdd

	dialog --backtitle "$VERSION" --title "-| MediaElch |-" --yesno "\nMediaElch installieren\n" 0 0
	if [[ $? -eq 0 ]]; then ELCH="YES" ; fi

	dialog --backtitle "$VERSION" --title "-| Windows Spiele |-" --yesno "\nWine und Steam installieren\n" 0 0
	if [[ $? -eq 0 ]]; then WINE="YES" ; fi

	#Wipe or zap
	if [[ $WIPE == "YES" ]]; then
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm wipe
		fi	
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --infobox "\nWipe Bitte warten\n\n" 0 0
		wipe -Ifre ${DEVICE}
	else
		sgdisk --zap-all ${DEVICE}
	fi
	
	#BIOS Part
	if [[ $SYSTEM == "BIOS" ]]; then
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE}
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --infobox "\nHarddisk $DEVICE wird Formatiert\n\n" 0 0
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 >/dev/null
		mount ${DEVICE}2 /mnt
	fi
	
	#UEFI Part
	if [[ $SYSTEM == "UEFI" ]]; then
		echo -e "o\ny\nn\n1\n\n+512M\nEF00\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE}
		dialog --backtitle "$VERSION" --title "-| Harddisk |-" --infobox "\nHarddisk $DEVICE wird Formatiert\n\n" 0 0
		echo j | mkfs.vfat -F32 ${DEVICE}1 >/dev/null
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 >/dev/null
		mount ${DEVICE}2 /mnt
		mkdir -p /mnt/boot
		mount ${DEVICE}1 /mnt/boot
	fi		

	#Swap
	if [[ $HD_SD == "HDD" ]]; then
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile >/dev/null
		swapon /mnt/swapfile >/dev/null
	fi

	#Mirror
	if ! (</etc/pacman.d/mirrorlist grep "rankmirrors" &>/dev/null) then
		URL="https://www.archlinux.org/mirrorlist/?country=${CODE}&use_mirror_status=on"
		MIRROR_TEMP=$(mktemp --suffix=-mirrorlist)
		curl -so ${MIRROR_TEMP} ${URL}
		sed -i 's/^#Server/Server/g' ${MIRROR_TEMP}
		mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
		rankmirrors -n 10 ${MIRROR_TEMP} > /etc/pacman.d/mirrorlist
		chmod +r /etc/pacman.d/mirrorlist
		pacman-key --init
		pacman-key --populate archlinux
		pacman -Syy
	fi
}
ins_base() {
ins_graphics_card() {
	ins_intel(){
		pacstrap /mnt xf86-video-intel libva-intel-driver intel-ucode 2>>/tmp/.paklog && cerrror
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
		pacstrap /mnt xf86-video-ati 2>>/tmp/.paklog && cerrror
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
		pacstrap /mnt xf86-video-nouveau 2>>/tmp/.paklog && cerrror
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pacstrap /mnt ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings 2>>/tmp/.paklog && cerrror
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings 2>>/tmp/.paklog && cerrror
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-304xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-304xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-304xx-libgl nvidia-304xx-utils nvidia-settings 2>>/tmp/.paklog && cerrror
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 7 ]] ; then
		pacstrap /mnt xf86-video-openchrome 2>>/tmp/.paklog && cerrror
	fi
	if [[ $HIGHLIGHT_SUB_GC == 8 ]] ; then
		[[ -e /mnt/boot/initramfs-linux.img ]] && VB_MOD="linux-headers"
		[[ -e /mnt/boot/initramfs-linux-grsec.img ]] && VB_MOD="$VB_MOD linux-grsec-headers"
		[[ -e /mnt/boot/initramfs-linux-zen.img ]] && VB_MOD="$VB_MOD linux-zen-headers"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && VB_MOD="$VB_MOD linux-lts-headers"
		pacstrap /mnt virtualbox-guest-utils virtualbox-guest-dkms $VB_MOD 2>>/tmp/.paklog && cerrror
		umount -l /mnt/dev
		arch_chroot "modprobe -a vboxguest vboxsf vboxvideo"  
		arch_chroot "systemctl enable vboxservice"
		echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 9 ]] ; then
		pacstrap /mnt xf86-video-vmware xf86-input-vmmouse 2>>/tmp/.paklog && cerrror
	fi
	if [[ $HIGHLIGHT_SUB_GC == 10 ]] ; then
		pacstrap /mnt xf86-video-fbdev 2>>/tmp/.paklog && cerrror
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
	pacstrap /mnt base base-devel 2>>/tmp/.paklog && cerrror

	if [[ $SYSTEM == "BIOS" ]]; then		
		pacstrap /mnt grub dosfstools 2>>/tmp/.paklog && cerrror
		arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		pacstrap /mnt grub efibootmgr dosfstools 2>>/tmp/.paklog && cerrror
		arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		arch_chroot "mkdir -p /boot/EFI/boot"
		arch_chroot "mv -r /boot/EFI/arch_grub/grubx64.efi /boot/EFI/boot/bootx64.efi"
	fi

	if [[ $SYSTEM == "BIOS" ]]; then
		genfstab -U -p /mnt > /mnt/etc/fstab
	fi
	if [[ $SYSTEM == "UEFI" ]]; then
		genfstab -t PARTUUID -p /mnt > /mnt/etc/fstab
	fi
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab

	#Hostname
	echo "${HOSTNAME}" > /mnt/etc/hostname
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts

	#Locale
	echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
	echo LC_COLLATE=C >> /mnt/etc/locale.conf
	echo LANGUAGE=de_DE >> /mnt/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen
	
	arch_chroot "locale-gen" >/dev/null

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
	pacman -Sy --noconfirm

	#Zone
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"

	#Zeit
	arch_chroot "hwclock --systohc --utc"

	#PW
	arch_chroot "passwd root" < /tmp/.passwd >/dev/null

	#Benutzer
	arch_chroot "groupadd -r autologin -f"
	arch_chroot "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp -s /bin/bash"
	arch_chroot "passwd ${USERNAME}" < /tmp/.passwd >/dev/null
	[[ -e /mnt/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
	rm /tmp/.passwd

	#mkinitcpio
	arch_chroot "mkinitcpio -p linux"

	#xorg
	pacstrap /mnt xorg-server xorg-server-utils xorg-xinit xorg-twm xorg-xclock xterm xf86-input-keyboard xf86-input-mouse xf86-input-libinput xf86-input-joystick 2>>/tmp/.paklog && cerrror
	user_list=$(ls /mnt/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$i/.xinitrc
		arch_chroot "chown -R ${i}:users /home/${i}"
	done

	#Grafikkarte
	ins_graphics_card

	#Oberfaeche
	pacstrap /mnt cinnamon nemo-fileroller nemo-preview gnome-terminal gnome-screenshot nemo-python nemo-qml-plugin-notifications nemo-qt-components nemo-seahorse nemo-share eog gnome-calculator gnome-font-viewer 2>>/tmp/.paklog && cerrror
	pacstrap /mnt bash-completion gamin gksu gnome-keyring gvfs polkit poppler python2-xdg ntfs-3g ttf-dejavu xdg-user-dirs xdg-utils 2>>/tmp/.paklog && cerrror

	#Anmeldescreen
	pacstrap /mnt lightdm lightdm-gtk-greeter 2>>/tmp/.paklog && cerrror
	sed -i "s/#autologin-user=/autologin-user=${USERNAME}/" /mnt/etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf
	arch_chroot "systemctl enable lightdm.service"

	#x11 Tastatur
	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf

	#WiFi
	[[ $(lspci | grep -i "Network Controller") == "" ]] && pacstrap /mnt dialog iw rp-pppoe wireless_tools wpa_actiond 2>>/tmp/.paklog && cerrror

	#Drucker
	pacstrap /mnt cups system-config-printer hplip  2>>/tmp/.paklog && cerrror
	arch_chroot "systemctl enable org.cups.cupsd.service"

	#SSD
	[[ $HD_SD == "SSD" ]] && arch_chroot "systemctl enable fstrim.service && systemctl enable fstrim.timer"

	#Bluetoo
	[[ $(dmesg | grep -i Bluetooth) == "" ]] && pacstrap /mnt blueman bluez-utils  2>>/tmp/.paklog && cerrror && arch_chroot "systemctl enable bluetooth.service"

	#Touchpad
	[[ $(dmesg | grep -i Touchpad) == "" ]] && pacstrap /mnt xf86-input-synaptics 2>>/tmp/.paklog && cerrror

	#Tablet
	[[ $(dmesg | grep -i Tablet) == "" ]] && pacstrap /mnt xf86-input-wacom 2>>/tmp/.paklog && cerrror
}
ins_apps() {
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

	arch_chroot "pacman -Sy --noconfirm"
	arch_chroot "pacman -S yaourt --noconfirm"

	#Office
	pacstrap /mnt libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de firefox firefox-i18n-de flashplugin icedtea-web thunderbird thunderbird-i18n-de 2>>/tmp/.paklog && cerrror

	#Grafik
	pacstrap /mnt gimp shotwell simple-scan vlc handbrake clementine mkvtoolnix-gui meld deluge geany gtk-recordmydesktop picard leafpad gparted gucharmap catfish gthumb 2>>/tmp/.paklog && cerrror

	#audio
	pacstrap /mnt pulseaudio pulseaudio-alsa pavucontrol alsa-utils alsa-plugins 2>>/tmp/.paklog && cerrror
	[[ $(uname -m) == x86_64 ]] && pacstrap /mnt lib32-libpulse lib32-alsa-plugins 2>>/tmp/.paklog && cerrror

  	#packer
	pacstrap /mnt zip unzip unrar p7zip lzop cpio 2>>/tmp/.paklog && cerrror

	#zusatz
	pacstrap /mnt ffmpegthumbs ffmpegthumbnailer x264 cairo-dock cairo-dock-plug-ins 2>>/tmp/.paklog && cerrror

	#Schriften
	pacstrap /mnt ttf-droid ttf-liberation ttf-bitstream-vera wqy-microhei cantarell-fonts 2>>/tmp/.paklog && cerrror

	#FS
	pacstrap /mnt exfat-utils f2fs-tools fuse mtpfs fuse-exfat autofs 2>>/tmp/.paklog && cerrror

	#libs
	pacstrap /mnt libquicktime libdvdnav libdvdcss cdrdao libaacs libdvdread 2>>/tmp/.paklog && cerrror

	#gst
	pacstrap /mnt gstreamer0.10-bad gstreamer0.10-bad-plugins gstreamer0.10-good gstreamer0.10-good-plugins gstreamer0.10-ugly gstreamer0.10-ugly-plugins gstreamer0.10-ffmpeg 2>>/tmp/.paklog && cerrror
	pacstrap /mnt gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav 2>>/tmp/.paklog && cerrror

	#wine
	if [[ $WINE == "YES" ]]; then
		pacstrap /mnt playonlinux winetricks wine wine_gecko wine-mono steam 2>>/tmp/.paklog && cerrror
	fi

	#NFS
	pacstrap /mnt nfs-utils jre7-openjdk wol 2>>/tmp/.paklog && cerrror
	arch_chroot "systemctl enable rpcbind"
	arch_chroot "systemctl enable nfs-client.target"
	arch_chroot "systemctl enable remote-fs.target"

	#jdownloader
	_jdownloader
}
ins_your() {
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

	mkdir -p /mnt/usr/share/linuxmint/locale/de/LC_MESSAGES/
	cp mintstick.mo /mnt/usr/share/linuxmint/locale/de/LC_MESSAGES/

	mv *.png /mnt/usr/share/backgrounds/

	cp cinnamon-utility.tar.gz /mnt/tmp/
	arch_chroot "tar -zxvf /tmp/cinnamon-utility.tar.gz"
	arch_chroot "./tmp/cinnamon-utility"

	pacman -S p7zip --noconfirm
	7za x teamviewer-*.pkg.7z.001
	mv *.pkg.tar.xz /mnt

	arch_chroot "pacman -U aic94xx-firmware-*-any.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U wd719x-firmware-*-any.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U pamac-aur-*-any.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U skype-*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U python2-pyparted-*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U mintstick-git-*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U teamviewer-*.pkg.tar.xz --noconfirm"
	arch_chroot "systemctl enable teamviewerd"
	
	arch_chroot "pacman -U cinnamon-system-adjustments*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U cinnamon-sound-effects*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U mint-sounds*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U mint-x-theme*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U mint-x-icons*.pkg.tar.xz --noconfirm"
	arch_chroot "pacman -U mint-cinnamon-themes*.pkg.tar.xz --noconfirm"
	

	#Fingerprint
	if (lsusb | grep Fingerprint); then
		arch_chroot "pacman -U fingerprint-gui-*.pkg.tar.xz --noconfirm"
		arch_chroot "useradd -G plugdev,scanner ${USERNAME}"
	fi

	#Mediaelch
	if [[ $ELCH == "YES" ]]; then
		arch_chroot "pacman -U mediaelch-*.pkg.tar.xz --noconfirm"
		set_mediaelch
	fi
	rm /mnt/*.pkg.tar.xz
}

id_sys
sel_info
ins_base
ins_apps
ins_your

MOUNTED=""
MOUNTED=$(mount | grep "/mnt" | awk '{print $3}' | sort -r)
swapoff -a
for i in ${MOUNTED[@]}; do
	umount $i >/dev/null
done

reboot
