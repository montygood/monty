#!/bin/bash
#kein schwarzes Bild
case $(tty) in /dev/tty[0-9]*)
    setterm -blank 0 -powersave off ;;
esac
# default
loadkeys de_CH-latin1
export LANG=de_CH.UTF-8
export LANGUAGE=de_CH:de_DE:en
export LC_CTYPE=de_CH.UTF-8
export LC_ALL=de_CH.UTF-8
export EDITOR=nano
timedatectl set-local-rtc 0
UCODE="intel-ucode"
#Prozesse
_sys() {
	#intel?
	if grep 'GenuineIntel' /proc/cpuinfo; then
		UCODE="intel-ucode"
	elif grep 'AuthenticAMD' /proc/cpuinfo; then
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
	#Programme Installieren
	cmd=(dialog --title " Programme auch installieren? " --separate-output --checklist "Auswahl:" 22 76 16)
	options=(1 "Gimp - Grafikprogramm - installieren?" on
		 2 "LibreOffice - Office - installieren?" on
		 3 "AnyDesk - Remotehilfe - installieren?" on
		 4 "Wine - Windows Spiele & Programme - installieren?" on
		 5 "FileBot - Mediafiles Manager - installieren?" on
		 6 "JDownloader2 - Dateien herunterladen - installieren?" on)
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices
	do
	    case $choice in
		1) GIMP=YES ;;
		2) OFFICE=YES ;;
		3) TEAM=YES ;;
		4) WINE=YES ;;
		5) FBOT=YES ;;
		6) JDOW=YES ;;
	    esac
	done
	#HD bereinigen
	echo Bereite Harddisk vor ....
	sgdisk --zap-all ${DEVICE} &> /dev/null
	wipefs -a ${DEVICE} &> /dev/null
	#BIOS Part?
	if [[ $SYSTEM == "BIOS" ]]; then
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} &> /dev/null
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 &> /dev/null
		mount ${DEVICE}2 /mnt
	fi
	#UEFI Part?
	if [[ $SYSTEM == "UEFI" ]]; then
		echo -e "o\ny\nn\n1\n\n+512M\nEF00\nn\n2\n\n\n\nw\ny" | gdisk ${DEVICE} &> /dev/null
		echo j | mkfs.vfat -F32 ${DEVICE}1 &> /dev/null
		echo j | mkfs.ext4 -q -L arch ${DEVICE}2 &> /dev/null
		mount ${DEVICE}2 /mnt
		mkdir -p /mnt/boot
		mount ${DEVICE}1 /mnt/boot
	fi		
	#Swap?
	if [[ $HD_SD == "HDD" ]]; then
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile &> /dev/null
		swapon /mnt/swapfile
	fi
	_base
}
_base() {
	#BASE
	pacstrap /mnt base base-devel wpa_supplicant wireless-regdb dialog reflector $UCODE
	genfstab -Up /mnt > /mnt/etc/fstab
	echo "${HOSTNAME}" > /mnt/etc/hostname
	echo LC_CTYPE=de_CH.UTF-8 > /mnt/etc/locale.conf
	echo LC_ALL=de_CH.UTF-8 > /mnt/etc/locale.conf
	echo LANG=de_CH.UTF-8 > /mnt/etc/locale.conf
	echo LC_COLLATE=C >> /mnt/etc/locale.conf
	echo LANGUAGE=de_CH:de_DE:en >> /mnt/etc/locale.conf
	arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
	echo KEYMAP=de_CH-latin1 > /mnt/etc/vconsole.conf
	echo FONT=lat9w-16 >> /mnt/etc/vconsole.conf
	sed -i "s/#de_CH.UTF-8/de_CH.UTF-8/" /mnt/etc/locale.gen
	sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base systemd autodetect modconf block filesystems keyboard sd-vconsole fsck)/" /mnt/etc/mkinitcpio.conf
	arch-chroot /mnt /bin/bash -c "locale-gen"
	arch-chroot /mnt /bin/bash -c "mkinitcpio -p linux"
	arch-chroot /mnt /bin/bash -c "passwd root" < /tmp/.passwd
	#GRUB
	if [[ $SYSTEM == "BIOS" ]]; then		
		pacstrap /mnt grub dosfstools
		arch-chroot /mnt /bin/bash -c "grub-install $DEVICE"
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		pacstrap /mnt grub dosfstools efibootmgr
		arch-chroot /mnt /bin/bash -c "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot"
	fi
	if [[ -e /mnt/boot/loader/loader.conf ]]; then
		upgate=$(ls /mnt/boot/loader/entries/*.conf)
		for i in ${upgate}; do
			sed -i '/linux \//a initrd \/intel-ucode.img' ${i}
		done
	fi			 
	arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
	sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
	sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
	echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
	#Einstellungen
	arch-chroot /mnt /bin/bash -c "groupadd -r autologin -f"
	arch-chroot /mnt /bin/bash -c "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys -s /bin/bash"																 
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
	sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
	arch-chroot /mnt /bin/bash -c "passwd ${USERNAME}" < /tmp/.passwd
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf
	fi
	arch-chroot /mnt /bin/bash -c "pacman -Syy"
	arch-chroot /mnt /bin/bash -c "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
	#Pakete
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xorg-server xorg-xinit xterm dbus cups acpid avahi cronie networkmanager bash-completion xf86-input-keyboard xf86-input-mouse laptop-detect"
	arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager acpid avahi-daemon org.cups.cupsd.service cronie systemd-timesyncd.service"
	#Grafikkarte
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel") != "" ]]; then		
		arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-intel libva-intel-driver mesa-libgl libvdpau-va-gl"
		sed -i 's/MODULES=()/MODULES=(i915)/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "ati") != "" ]]; then		
		arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-ati mesa-libgl mesa-vdpau libvdpau-va-gl"
		sed -i 's/MODULES=()/MODULES=(radeon)/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia") != "" ]]; then		
		arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-nouveau nvidia nvidia-utils libglvnd"
		sed -i 's/MODULES=()/MODULES=(nouveau)/' /mnt/etc/mkinitcpio.conf
	fi
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-vesa xf86-video-fbdev"
	#Autologin
	mkdir /mnt/etc/systemd/system/getty@tty1.service.d/
	cp -f /etc/systemd/system/getty@tty1.service.d/autologin.conf /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf
	sed -i "s/root/$USERNAME/g" /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf
	sed '/^$/d' /mnt/etc/X11/xinit/xinitrc > /mnt/home/$USERNAME/.xinitrc
	sed -i 's/^twm &/#twm &/g' /mnt/home/$USERNAME/.xinitrc
	sed -i 's/^xclock -geometry 50x50-1+1 &/#xclock -geometry 50x50-1+1 &/g' /mnt/home/$USERNAME/.xinitrc
	sed -i 's/^xterm -geometry 80x50+494+51 &/#xterm -geometry 80x50+494+51 &/g' /mnt/home/$USERNAME/.xinitrc
	sed -i 's/^xterm -geometry 80x20+494-0 &/#xterm -geometry 80x20+494-0 &/g' /mnt/home/$USERNAME/.xinitrc
	sed -i 's/^exec xterm -geometry 80x66+0+0 -name login/#exec xterm -geometry 80x66+0+0 -name login/g' /mnt/home/$USERNAME/.xinitrc
	echo "exec cinnamon-session" >> /mnt/home/$USERNAME/.xinitrc
cat > /mnt/home/$USERNAME/.bash_profile << EOF
if [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF
	#Pakete
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm cinnamon cinnamon-translations nemo-fileroller gnome-terminal xdg-user-dirs-gtk"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm alsa-utils picard zip unzip pulseaudio-alsa alsa-tools unace unrar sharutils uudeview"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm arj cabextract file-roller parole vlc handbrake mkvtoolnix-gui meld simple-scan geany geany-plugins" 
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm gparted ttf-liberation ttf-dejavu noto-fonts cups-pdf ghostscript gsfonts gutenprint gtk3-print-backends"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm libcups hplip system-config-printer firefox firefox-i18n-de thunderbird thunderbird-i18n-de filezilla"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm qbittorrent alsa-firmware gst-libav gst-plugins-bad gst-plugins-ugly libdvdcss gthumb"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm pavucontrol gnome-system-monitor gnome-screenshot eog gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm mtpfs tumbler nfs-utils rsync wget libmtp cups-pk-helper splix python-pip python-reportlab p7zip"
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm autofs ifuse shotwell ffmpegthumbs palore ffmpegthumbnailer libopenraw galculator gtk-engine-murrine"
	#trizen
	mv trizen-any.pkg.tar.xz /mnt/ && arch-chroot /mnt /bin/bash -c "pacman -U trizen-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/trizen-any.pkg.tar.xz
	#pamac
	arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
	sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
	sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
	sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
	sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
	#Zusatz
	[[ $GIMP == "YES" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur"
	[[ $OFFICE == "YES" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de"
	[[ $WINE == "YES" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm wine wine_gecko wine-mono winetricks lib32-libxcomposite lib32-libglvnd"
	[[ $TEAM == "YES" ]] && arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S anydesk --noconfirm'"
	if [[ $FBOT == "YES" ]]; then		
		arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm java-openjfx libmediainfo"
		arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S filebot47 --noconfirm'"
		sed -i 's/^export LANG="en_US.UTF-8"/export LANG="de_CH.UTF-8"/g' /mnt/bin/filebot
		sed -i 's/^export LC_ALL="en_US.UTF-8"/export LC_ALL="de_CH.UTF-8"/g' /mnt/bin/filebot
		echo '#!/bin/sh' >> /mnt/bin/plexup
		echo "sudo mount -t nfs 192.168.1.121:/multimedia /storage" >> /mnt/bin/plexup
		echo 'filebot -script fn:renall "/home/monty/Downloads" --format "/storage/{plex}" --lang de -non-strict' >> /mnt/bin/plexup
		echo 'filebot -script fn:cleaner "/home/monty/Downloads"' >> /mnt/bin/plexup
		echo "sudo umount /storage" >> /mnt/bin/plexup
		arch-chroot /mnt /bin/bash -c "chmod +x /bin/plexup"
	fi
	if [[ $JDOW == "YES" ]]; then		
		mkdir -p /mnt/opt/JDownloader/
		wget -c -O /mnt/opt/JDownloader/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar
		arch-chroot /mnt /bin/bash -c "chown -R 1000:1000 /opt/JDownloader/"
		arch-chroot /mnt /bin/bash -c "chmod -R 0775 /opt/JDownloader/"
		echo "[Desktop Entry]" > /mnt/usr/share/applications/JDownloader.desktop
		echo "Name=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "Comment=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "Exec=java -jar /opt/JDownloader/JDownloader.jar" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "Icon=/opt/JDownloader/themes/standard/org/jdownloader/images/logo/jd_logo_64_64.png" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "Terminal=false" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "Type=Application" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "StartupNotify=false" >> /mnt/usr/share/applications/JDownloader.desktop
		echo "Categories=Network;Application;" >> /mnt/usr/share/applications/JDownloader.desktop
	fi
	#Treiber
	[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm broadcom-wl"
	[[ $(dmesg | egrep Bluetooth) != "" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm blueberry bluez bluez-firmware pulseaudio-bluetooth" && arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth.service"
	[[ $(dmesg | egrep Touchpad) != "" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-input-libinput"
	[[ $HD_SD == "SSD" ]] && arch-chroot /mnt /bin/bash -c "systemctl enable fstrim && systemctl enable fstrim.timer"
	if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
		arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S fingerprint-gui --noconfirm'"
		arch-chroot /mnt /bin/bash -c "usermod -a -G plugdev,scanner ${USERNAME}"
		if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
		if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
	fi
	#Mintstick
	arch-chroot /mnt /bin/bash -c "su - ${USERNAME} -c 'trizen -S mintstick --noconfirm'"
	#myup
	echo '#!/bin/sh' >> /mnt/bin/myup
	echo "sudo pacman -Syu --noconfirm" >> /mnt/bin/myup
	echo "trizen -Syu --noconfirm" >> /mnt/bin/myup
	echo "sudo pacman -Rns --noconfirm $(sudo pacman -Qtdq --noconfirm)" >> /mnt/bin/myup
	echo "sudo pacman -Scc --noconfirm" >> /mnt/bin/myup
	echo "sudo fstrim -v /" >> /mnt/bin/myup
	arch-chroot /mnt /bin/bash -c "chmod +x /bin/myup"
	#update
	mv monty.tar.gz /mnt/ && arch-chroot /mnt /bin/bash -c "tar xvf monty.tar.gz" && rm /mnt/monty.tar.gz
	arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'myup'"
	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"ch"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
	arch-chroot /mnt /bin/bash -c "localectl set-x11-keymap ch nodeadkeys"
	sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
	arch-chroot /mnt /bin/bash -c "chown -R ${USERNAME}:users /home/${USERNAME}"
	arch-chroot /mnt /bin/bash -c "gtk-update-icon-cache /usr/share/icons/McOS/"
	arch-chroot /mnt /bin/bash -c "glib-compile-schemas /usr/share/glib-2.0/schemas/"
	#Ende 
	swapoff -a
	umount -R /mnt
	reboot
}
_sys
