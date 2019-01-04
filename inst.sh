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
	sgdisk --zap-all ${DEVICE} 2>> monty.log
	wipefs -a ${DEVICE} 2>> monty.log
	#BIOS Part?
	if [[ $SYSTEM == "BIOS" ]]; then
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} 2>> monty.log
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 2>> monty.log
		mount ${DEVICE}2 /mnt
	fi
	#UEFI Part?
	if [[ $SYSTEM == "UEFI" ]]; then
		echo -e "o\ny\nn\n1\n\n+512M\nEF00\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} 2>> monty.log
		echo j | mkfs.vfat -F32 ${DEVICE}1 2>> monty.log
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 2>> monty.log
		mount ${DEVICE}2 /mnt
		mkdir -p /mnt/boot
		mount ${DEVICE}1 /mnt/boot
	fi		
	#Swap?
	if [[ $HD_SD == "HDD" ]]; then
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile 2>> monty.log
		swapon /mnt/swapfile 2>> monty.log
	fi
	#Mirror?
	reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist 2>> monty.log
	pacman-key --init 2>> monty.log
	pacman-key --populate archlinux 2>> monty.log
	pacman -Sy 2>> monty.log
	_base
}
_base() {
ins_graphics_card() {
	ins_intel(){
		pacstrap /mnt xf86-video-intel libva-intel-driver intel-ucode --needed --noconfirm
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
		pacstrap /mnt xf86-video-ati --needed --noconfirm
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
		pacstrap /mnt xf86-video-nouveau --needed --noconfirm
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pacstrap /mnt ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings --needed --noconfirm
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings --needed --noconfirm
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] && ins_ati || ins_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-304xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-304xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-304xx-libgl nvidia-304xx-utils nvidia-settings --needed --noconfirm
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 7 ]] ; then
		pacstrap /mnt xf86-video-openchrome --needed --noconfirm
	fi
	if [[ $HIGHLIGHT_SUB_GC == 8 ]] ; then
		[[ -e /mnt/boot/initramfs-linux.img ]] && VB_MOD="linux-headers"
		[[ -e /mnt/boot/initramfs-linux-grsec.img ]] && VB_MOD="$VB_MOD linux-grsec-headers"
		[[ -e /mnt/boot/initramfs-linux-zen.img ]] && VB_MOD="$VB_MOD linux-zen-headers"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && VB_MOD="$VB_MOD linux-lts-headers"
		pacstrap /mnt virtualbox-guest-utils virtualbox-guest-dkms $VB_MOD --needed --noconfirm
		umount -l /mnt/dev
		arch_chroot "modprobe -a vboxguest vboxsf vboxvideo"
		arch_chroot "systemctl enable vboxservice"
		echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf
	fi
	if [[ $HIGHLIGHT_SUB_GC == 9 ]] ; then
		pacstrap /mnt xf86-video-vmware xf86-input-vmmouse --needed --noconfirm
	fi
	if [[ $HIGHLIGHT_SUB_GC == 10 ]] ; then
		pacstrap /mnt xf86-video-fbdev --needed --noconfirm
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
	pacstrap /mnt base $UCODE base-devel wpa_supplicant dialog reflector --needed --noconfirm 2>> monty.log
	genfstab -Up /mnt > /mnt/etc/fstab 2>> monty.log
	echo "${HOSTNAME}" > /mnt/etc/hostname 2>> monty.log
#	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > /mnt/etc/hosts
	echo LANG=de_CH.UTF-8 > /mnt/etc/locale.conf 2>> monty.log
	echo LC_COLLATE=C >> /mnt/etc/locale.conf 2>> monty.log
	echo LANGUAGE=de_DE >> /mnt/etc/locale.conf 2>> monty.log
	arch_chroot "ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
	echo KEYMAP=de_CH-latin1 > /mnt/etc/vconsole.conf 2>> monty.log
	echo FONT=lat9w-16 >> /mnt/etc/vconsole.conf 2>> monty.log
	sed -i "s/#de_CH.UTF-8/de_CH.UTF-8/" /mnt/etc/locale.gen 2>> monty.log
	arch_chroot "locale-gen"
	arch_chroot "mkinitcpio -p linux"
	arch_chroot "passwd root" < /tmp/.passwd

	#GRUB
	if [[ $SYSTEM == "BIOS" ]]; then		
		pacstrap /mnt grub dosfstools --needed --noconfirm 2>> monty.log
		arch_chroot "grub-install --target=i386-pc --recheck $DEVICE" 2>> monty.log
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>> monty.log
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>> monty.log
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>> monty.log
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		pacstrap /mnt efibootmgr dosfstools grub --needed --noconfirm 2>> monty.log
		arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot"
		sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>> monty.log
		sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>> monty.log
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
	fi
	echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab

	#Einstellungen
	arch_chroot "groupadd -r autologin -f"
	arch_chroot "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys -s /bin/bash"																 
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers 2>> monty.log
	sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers 2>> monty.log
	arch_chroot "passwd ${USERNAME}" < /tmp/.passwd
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf 2>> monty.log
	fi
	arch_chroot "pacman -Sy"
	arch_chroot "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"

	#Pakete
	pacstrap /mnt acpid dbus avahi cups cronie --needed --noconfirm 2>> monty.log
	arch_chroot "systemctl enable acpid && systemctl enable avahi-daemon && systemctl enable org.cups.cupsd.service && systemctl enable --now systemd-timesyncd.service"
	pacstrap /mnt xorg-server xorg-xinit --needed --noconfirm 2>> monty.log

	#Grafikkarte
	ins_graphics_card 2>> monty.log

	#Autologin
	mkdir /mnt/etc/systemd/system/getty@tty1.service.d/ 2>> monty.log
	cp -f /etc/systemd/system/getty@tty1.service.d/autologin.conf /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf 2>> monty.log
	sed -i "s/root/$USERNAME/g" /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf 2>> monty.log
	cat > /mnt/home/$USERNAME/.bash_profile << EOF
if [ -z "\$DISPLAY" ] && [ \$XDG_VTNR -eq 1 ]; then
    exec startx -- vt1 >/dev/null 2>&1
fi
EOF
	cat > /mnt/home/$USERNAME/.xinitrc << EOF
#!/bin/sh
if [ -d /etc/X11/xinit/xinitrc.d ]; then
    for f in /etc/X11/xinit/xinitrc.d/*.sh; do
        [ -x "$f" ] && . "$f"
    done
fi
[ -f /etc/X11/xinit/.Xmodmap ] && xmodmap /etc/X11/xinit/.Xmodmap
[ -f ~/.Xmodmap ] && xmodmap ~/.Xmodmap
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.xprofile ] && . ~/.xprofile
exec cinnamon-session
EOF

	#Pakete
#	pacstrap /mnt $(grep -hv '^#' packages.txt) --needed --noconfirm

#	pacstrap /mnt ttf-liberation ttf-dejavu --needed --noconfirm
	#audio
#	pacstrap /mnt alsa-utils --needed --noconfirm
	#Fenster
	pacstrap /mnt cinnamon cinnamon-translations nemo-fileroller nemo-preview networkmanager gnome-terminal bash-completion xf86-input-keyboard xf86-input-mouse --needed --noconfirm 2>> monty.log
	#Internet
#	pacstrap /mnt firefox firefox-i18n-de flashplugin thunderbird thunderbird-i18n-de --needed --noconfirm
	#Medien
#	pacstrap /mnt vlc handbrake mkvtoolnix-gui gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur geany geany-plugins --needed --noconfirm
	#Office
#	pacstrap /mnt libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de --needed --noconfirm
	#Dienste

#	#Pakete
#	libquicktime cdrdao libaacs libdvdcss libdvdnav libdvdread gtk-engine-murrine
#	gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav gnome-screenshot eog gnome-calculator
#	pulseaudio pulseaudio-alsa pavucontrol alsa-plugins nfs-utils jre7-openjdk nss-mdns
#	shotwell simple-scan deluge picard gparted gthumb filezilla icedtea-web 
#	rsync mlocate pkgstats ntp gamin gnome-keyring gvfs-mtp ifuse gvfs-afc gvfs-gphoto2 gvfs-nfs gvfs-smb polkit poppler 
#	python2-xdg ntfs-3g f2fs-tools fuse fuse-exfat mtpfs xdg-user-dirs xdg-utils autofs unrar p7zip lzop cpio zip arj unace unzip
#	Xorg-apps xorg-xkill
#	system-config-printer hplip cups-pdf gtk3-print-backends ghostscript gsfonts gutenprint foomatic-db foomatic-db-engine foomatic-db-nonfree splix

	#Service
#	arch_chroot "systemctl enable rpcbind && systemctl enable nfs-client.target && systemctl enable remote-fs.target"
	arch_chroot "systemctl enable NetworkManager"

	#trizen
	mv trizen-any.pkg.tar.xz /mnt/ && arch_chroot "pacman -U trizen-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/trizen-any.pkg.tar.xz

	#pamac
	arch_chroot "su - ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
	sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf 2>> monty.log
	sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf 2>> monty.log
	sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf 2>> monty.log
	sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf 2>> monty.log

	#Treiber
	[[ $WINE == "YES" ]] && arch_chroot "pacman -S wine wine_gecko wine-mono winetricks lib32-libxcomposite --needed --noconfirm"
	[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && arch_chroot "su - ${USERNAME} -c 'trizen -S broadcom-wl --noconfirm'"
	[[ $(lspci | grep -i "Network Controller") != "" ]] && pacstrap /mnt rp-pppoe wireless_tools wpa_actiond --needed --noconfirm
	[[ $(dmesg | egrep Bluetooth) != "" ]] && pacstrap /mnt blueman --needed --noconfirm && arch_chroot "systemctl enable bluetooth"
	[[ $(dmesg | egrep Touchpad) != "" ]] && pacstrap /mnt xf86-input-synaptics --needed --noconfirm
	[[ $(dmesg | egrep Tablet) != "" ]] && pacstrap /mnt xf86-input-wacom --needed --noconfirm
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
	wget -c -O /mnt/opt/JDownloader/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar 2>> monty.log
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
#	arch_chroot "su - ${USERNAME} -c 'trizen -S mintstick-git --noconfirm'"

	#Teamviewer
#	arch_chroot "su - ${USERNAME} -c 'trizen -S teamviewer --noconfirm'"
#	arch_chroot "systemctl enable teamviewerd"

	#Filebot
	pacstrap /mnt java-openjfx libmediainfo --needed --noconfirm 2>> monty.log
	arch_chroot "su - ${USERNAME} -c 'trizen -S filebot47 --noconfirm'"
	sed -i 's/^export LANG="en_US.UTF-8"/export LANG="de_CH.UTF-8"/g' /mnt/bin/filebot
	sed -i 's/^export LC_ALL="en_US.UTF-8"/export LC_ALL="de_CH.UTF-8"/g' /mnt/bin/filebot

	#plexupload
	echo '#!/bin/sh' >> /mnt/bin/plexup 2>> monty.log
	echo "sudo mount -t nfs 192.168.1.121:/multimedia /storage" >> /mnt/bin/plexup
	echo 'filebot -script fn:renall "/home/monty/Downloads" --format "/storage/{plex}" --lang de -non-strict' >> /mnt/bin/plexup
	echo 'filebot -script fn:cleaner "/home/monty/Downloads"' >> /mnt/bin/plexup
	echo "sudo umount /storage" >> /mnt/bin/plexup
	arch_chroot "chmod +x /bin/plexup"

	#myup
	echo '#!/bin/sh' >> /mnt/bin/myup 2>> monty.log
	echo "sudo pacman -Syu --noconfirm" >> /mnt/bin/myup
	echo "trizen -Syu --noconfirm" >> /mnt/bin/myup
	echo "sudo pacman -Rns --noconfirm $(sudo pacman -Qtdq --noconfirm)" >> /mnt/bin/myup
	echo "sudo pacman -Scc --noconfirm" >> /mnt/bin/myup
	echo "sudo fstrim -v /" >> /mnt/bin/myup
	arch_chroot "chmod +x /bin/myup"

	#update
#	mv monty-1-1-any.pkg.tar.xz /mnt/ && arch_chroot "pacman -U monty-1-1-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/monty-1-1-any.pkg.tar.xz
#	arch_chroot "glib-compile-schemas /usr/share/glib-2.0/schemas/"
	arch_chroot "localectl set-x11-keymap ch nodeadkeys"
	sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/g' /mnt/etc/sudoers 2>> monty.log
	arch_chroot "chown -R ${USERNAME}:users /home/${USERNAME}"
	arch_chroot "pacman -Syu --noconfirm"
	arch_chroot "su - ${USERNAME} -c 'trizen -Syu --noconfirm'"

	if [[ $? -eq 0 ]] && [[ $(cat monty.log | grep -i "error") != "" ]]; then
		dialog --title " Error " --msgbox "$(cat monty.log)" 0 0
	fi
	if [[ $? -eq 0 ]] && [[ $(cat monty.log | grep -i "fehler") != "" ]]; then
		dialog --title " Fehler " --msgbox "$(cat monty.log)" 0 0
	fi
	if [[ $? -eq 0 ]] && [[ $(cat monty.log | grep -i "warning") != "" ]]; then
		dialog --title " Fehler " --msgbox "$(cat monty.log)" 0 0
	fi
	cp -f monty.log /mnt/home/$USERNAME/error.log

	#Ende 
	swapoff -a
	umount -R /mnt
	reboot
}
_sys
