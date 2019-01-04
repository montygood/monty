#!/bin/bash

#kein schwarzes Bild
case $(tty) in /dev/tty[0-9]*)
    setterm -blank 0 -powersave off ;;
esac

# default
loadkeys de_CH-latin1
timedatectl set-local-rtc 0

#Prozesse
arch_chroot() {
	arch-chroot /mnt /bin/bash -c "$1"
}
_sys() {
 	#intel?
 	if ! grep 'GenuineIntel' /proc/cpuinfo; then
        UCODE="intel-ucode"
    elif ! grep 'AuthenticAMD' /proc/cpuinfo; then
        UCODE="amd-ucode"
    else
        UCODE=""
    fi
  	# Apple?
    if grep -qi 'apple' /sys/class/dmi/id/sys_vendor; then
        modprobe -r -q efivars
    else
        modprobe -q efivarfs
    fi
	# UEFI?
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
	#Wine?
	dialog --title " Windows Spiele " --yesno "\nWine installieren" 0 0
	if [[ $? -eq 0 ]]; then WINE="YES" ; fi
	sgdisk --zap-all ${DEVICE} &> /dev/null | dialog --title " Harddisk " --infobox "\nSammle aktuelle Infos der Harddisk\nBitte warten" 0 0
	wipefs -a ${DEVICE} &> /dev/null | dialog --title " Harddisk " --infobox "\nSammle neue Infos der Harddisk\nBitte warten" 0 0
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
	pacman -Sy reflector --needed --noconfirm
	reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
	pacman-key --init
	pacman-key --populate archlinux
	pacman -Syy
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
	#BASE
	pacstrap /mnt base $UCODE base-devel wpa_supplicant dialog reflector --needed --noconfirm
	#Einstellungen
	echo "${HOSTNAME}" > /mnt/etc/hostname
	echo LANG=de_CH.UTF-8 > /mnt/etc/locale.conf
	sed -i "s/#de_CH.UTF-8/de_CH.UTF-8/" /mnt/etc/locale.gen
	sed -i "s/#en_EN.UTF-8/en_US.UTF-8/" /mnt/etc/locale.gen
	arch_chroot "locale-gen"
	echo -e "KEYMAP=sg-latin1" > /mnt/etc/vconsole.conf
	echo FONT="lat9w-16" >> /mnt/etc/vconsole.conf
	arch_chroot "ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf
	fi
	arch_chroot "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
	#GRUB
	arch_chroot "mkinitcpio -p linux"
	if [[ $SYSTEM == "BIOS" ]]; then		
		pacstrap /mnt grub dosfstools
		arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		genfstab -Up /mnt > /mnt/etc/fstab
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		pacstrap /mnt efibootmgr dosfstools grub
		arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
		genfstab -Up /mnt > /mnt/etc/fstab
	fi
	echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
	#Benutzer
	arch_chroot "passwd root" < /tmp/.passwd
	arch_chroot "groupadd -r autologin -f"
	arch_chroot "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys -s /bin/bash"																 
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
	sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
	arch_chroot "passwd ${USERNAME}" < /tmp/.passwd
	#Pakete
	pacstrap /mnt acpid dbus avahi cups cronie
	arch_chroot "systemctl enable acpid && systemctl enable avahi-daemon && systemctl enable org.cups.cupsd.service && systemctl enable --now systemd-timesyncd.service"
	arch_chroot "hwclock -w"
	pacstrap /mnt xorg-server xorg-xinit
	#Grafikkarte
	ins_graphics_card &>> /tmp/error.log | dialog --title " Grafikkarte " --infobox "\nBitte warten" 0 0
	#Tastatur
	arch_chroot "localectl set-x11-keymap ch nodeadkeys"
#	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
	#Schrift
	pacstrap /mnt ttf-liberation ttf-dejavu 
#	cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$USERNAME/.xinitrc

	arch_chroot "cp /usr/lib/systemd/system/getty@.service /etc/systemd/system/getty@tty1.service"
#	arch_chroot "systemctl enable getty@tty1"

	cp -f /etc/systemd/system/getty@tty1.service.d/autologin.conf /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf
	sed -i "s/root/$USERNAME/g" /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf

	cat > /mnt/home/$USERNAME/.bash_profile << EOF
if [ -z "\$DISPLAY" ] && [ \$XDG_VTNR -eq 1 ]; then
    exec startx -- vt1 >/dev/null 2>&1
fi
EOF

	#audio
	pacstrap /mnt alsa-utils
	#Fenster
	pacstrap /mnt cinnamon cinnamon-translations nemo-fileroller nemo-preview networkmanager
	#Internet
#	pacstrap /mnt firefox firefox-i18n-de flashplugin icedtea-web thunderbird thunderbird-i18n-de
	#Medien
#	pacstrap /mnt vlc handbrake mkvtoolnix-gui
	#Office
#	pacstrap /mnt libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de
	#Dienste
	arch_chroot "systemctl enable NetworkManager"

#	#Pakete
#	pacstrap /mnt libquicktime cdrdao libaacs libdvdcss libdvdnav libdvdread gtk-engine-murrine
#	pacstrap /mnt gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav gnome-terminal gnome-screenshot eog gnome-calculator
#	pacstrap /mnt pulseaudio pulseaudio-alsa pavucontrol alsa-plugins nfs-utils jre7-openjdk wol nss-mdns	 
#	pacstrap /mnt gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur shotwell simple-scan  deluge geany geany-plugins picard gparted gthumb filezilla
#	pacstrap /mnt bc rsync mlocate pkgstats ntp bash-completion mesa gamin gnome-keyring gvfs gvfs-mtp ifuse gvfs-afc gvfs-gphoto2 gvfs-nfs gvfs-smb polkit poppler python2-xdg ntfs-3g f2fs-tools fuse fuse-exfat mtpfs xdg-user-dirs xdg-utils autofs unrar p7zip lzop cpio zip arj unace unzip
#	pacstrap /mnt xorg-apps xorg-xkill xf86-input-keyboard xf86-input-mouse xf86-input-libinput
#	pacstrap /mnt system-config-printer hplip cups-pdf gtk3-print-backends ghostscript gsfonts gutenprint foomatic-db foomatic-db-engine foomatic-db-nonfree splix
#	pacstrap /mnt tlp

	#Service
#	arch_chroot "systemctl enable tlp && systemctl enable tlp-sleep && systemctl disable systemd-rfkill && tlp start"
#	arch_chroot "systemctl enable rpcbind && systemctl enable nfs-client.target && systemctl enable remote-fs.target"

	#lightdm
#	pacstrap /mnt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
#	sed -i "s/#pam-service=lightdm/pam-service=lightdm/" /mnt/etc/lightdm/lightdm.conf
#	sed -i "s/#pam-autologin-service=lightdm-autologin/pam-autologin-service=lightdm-autologin/" /mnt/etc/lightdm/lightdm.conf
#	sed -i "s/#session-wrapper=\/etc\/lightdm\/Xsession/session-wrapper=\/etc\/lightdm\/Xsession/" /mnt/etc/lightdm/lightdm.conf
#	sed -i "s/#autologin-user=/autologin-user=${USERNAME}/" /mnt/etc/lightdm/lightdm.conf
#	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf
#	arch_chroot "systemctl enable lightdm"

	#trizen
	mv trizen-any.pkg.tar.xz /mnt/ && arch_chroot "pacman -U trizen-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/trizen-any.pkg.tar.xz

	#pamac
	arch_chroot "su - ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
	sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
	sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
	sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
	sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf

	#Treiber
	[[ $WINE == "YES" ]] && arch_chroot "pacman -S wine wine_gecko wine-mono winetricks lib32-libxcomposite --needed --noconfirm"
	[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && arch_chroot "su - ${USERNAME} -c 'trizen -S broadcom-wl --noconfirm'"
	[[ $(lspci | grep -i "Network Controller") != "" ]] && pacstrap /mnt rp-pppoe wireless_tools wpa_actiond
	[[ $(dmesg | egrep Bluetooth) != "" ]] && pacstrap /mnt blueman && arch_chroot "systemctl enable bluetooth" && rm /mnt/etc/polkit-1/rules.d/50-default.rules && mv 50-default.rules /mnt/etc/polkit-1/rules.d/
	[[ $(dmesg | egrep Touchpad) != "" ]] && pacstrap /mnt xf86-input-synaptics
	[[ $(dmesg | egrep Tablet) != "" ]] && pacstrap /mnt xf86-input-wacom
	[[ $HD_SD == "SSD" ]] && arch_chroot "systemctl enable fstrim && systemctl enable fstrim.timer"
	[[ ${ARCHI} == x86_64 ]] && arch_chroot "pacman -S lib32-alsa-plugins lib32-libpulse --needed --noconfirm"
	if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
		arch_chroot "su - ${USERNAME} -c 'trizen -S fingerprint-gui --noconfirm'"
		arch_chroot "usermod -a -G plugdev,scanner ${USERNAME}"
		if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
		if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
	fi

	#JDownloader
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

	#Mintstick
	arch_chroot "su - ${USERNAME} -c 'trizen -S mintstick-git --noconfirm'"

	#Teamviewer
#	arch_chroot "su - ${USERNAME} -c 'trizen -S teamviewer --noconfirm'"
#	arch_chroot "systemctl enable teamviewerd"

	#Filebot
#	pacstrap /mnt jre8-openjdk java-openjfx libmediainfo
	arch_chroot "su - ${USERNAME} -c 'trizen -S filebot47 --noconfirm'"
	sed -i 's/^export LANG="en_EN.UTF-8"/export LANG="de_CH.UTF-8"/g' /mnt/bin/filebot
	sed -i 's/^export LC_ALL="en_EN.UTF-8"/export LC_ALL="de_CH.UTF-8"/g' /mnt/bin/filebot

	#Einstellungen
#	mv monty-1-1-any.pkg.tar.xz /mnt/ && arch_chroot "pacman -U monty-1-1-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/monty-1-1-any.pkg.tar.xz
#	arch_chroot "glib-compile-schemas /usr/share/glib-2.0/schemas/"

	#plexupload
	echo '#!/bin/sh' >> /mnt/bin/plexup
	echo "sudo mount -t nfs 192.168.1.121:/multimedia /storage" >> /mnt/bin/plexup
	echo 'filebot -script fn:renall "/home/monty/Downloads" --format "/storage/{plex}" --lang de -non-strict' >> /mnt/bin/plexup
	echo 'filebot -script fn:cleaner "/home/monty/Downloads"' >> /mnt/bin/plexup
	echo "sudo umount /storage" >> /mnt/bin/plexup
	arch_chroot "chmod +x /bin/plexup"

	#myup
	echo '#!/bin/sh' >> /mnt/bin/myup
	echo "sudo pacman -Syu --noconfirm" >> /mnt/bin/myup
	echo "trizen -Syu --noconfirm" >> /mnt/bin/myup
	echo "sudo pacman -Rns --noconfirm $(sudo pacman -Qtdq --noconfirm)" >> /mnt/bin/myup
	echo "sudo pacman -Scc --noconfirm" >> /mnt/bin/myup
	echo "sudo fstrim -v /" >> /mnt/bin/myup
	arch_chroot "chmod +x /bin/myup"

	#update
	arch_chroot "chown -R ${USERNAME}:users /home/${USERNAME}"
	arch_chroot "pacman -Syu --noconfirm"
	arch_chroot "su - ${USERNAME} -c 'trizen -Syu --noconfirm'"

	#Ende 
	swapoff -a
	umount -R /mnt
	reboot
}
_sys
