#!/bin/bash
	#CPU?
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
	if [[ -d /sys/firmware/efi/efivars ]]; then
		grep -q /sys/firmware/efi/efivars /proc/mounts || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
		SYSTEM="UEFI"
	else
		SYSTEM="BIOS"
	fi
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
		 5 "FileBot - Mediafiles Manager - Scripts erstellen für Pascal?" off
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
	#BASE
	pacstrap /mnt base base-devel linux-lts linux-firmware nano networkmanager grub wpa_supplicant wireless-regdb dialog reflector haveged $UCODE
	genfstab -Up /mnt > /mnt/etc/fstab
	arch-chroot /mnt /bin/bash -c "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
	arch-chroot /mnt /bin/bash -c "pacman-key --init"
	arch-chroot /mnt /bin/bash -c "pacman-key --populate archlinux"
	arch-chroot /mnt /bin/bash -c "pacman-key --refresh-keys"
#	if [ $(uname -m) == x86_64 ]; then
#		sed -i '/\[multilib]$/ {
#		N
#		/Include/s/#//g}' /mnt/etc/pacman.conf
#	fi
	arch-chroot /mnt /bin/bash -c "pacman -Syy"
	arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
	arch-chroot /mnt /bin/bash -c "hwclock --systohc --utc"
	echo LANG=de_CH.UTF-8 > /mnt/etc/locale.conf
	echo KEYMAP=de_CH-latin1 > /mnt/etc/vconsole.conf
	echo "${HOSTNAME}" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<- EOF
	127.0.0.1	localhost
	::1			localhost
	127.0.0.1	$HOSTNAME.localdomain $HOSTNAME
	EOF
	sed -i "s/#de_CH.UTF-8/de_CH.UTF-8/" /mnt/etc/locale.gen
	arch-chroot /mnt /bin/bash -c "locale-gen"
	arch-chroot /mnt /bin/bash -c "mkinitcpio -p linux-lts"
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
	arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
	sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
	sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
	echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab

	#Einstellungen
	arch-chroot /mnt /bin/bash -c "groupadd -r autologin -f"
	arch-chroot /mnt /bin/bash -c "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys,rfkill -s /bin/bash"
	sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
	arch-chroot /mnt /bin/bash -c "passwd ${USERNAME}" < /tmp/.passwd
	#Pakete
	arch-chroot /mnt "pacman -S --needed --noconfirm xorg-server xorg-xinit dbus cups acpid avahi cronie networkmanager bash-completion xf86-input-keyboard xf86-input-mouse laptop-detect"
	arch-chroot /mnt "systemctl enable NetworkManager acpid avahi-daemon org.cups.cupsd.service cronie systemd-timesyncd.service"
	#Grafikkarte
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel") != "" ]]; then		
		arch-chroot /mnt "pacman -S --needed --noconfirm xf86-video-intel libva-intel-driver mesa-libgl libvdpau-va-gl"
		sed -i 's/MODULES=()/MODULES=(i915)/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "amd") != "" ]]; then		
		arch-chroot /mnt "pacman -S --needed --noconfirm xf86-video-ati mesa-libgl mesa-vdpau libvdpau-va-gl"
		sed -i 's/MODULES=()/MODULES=(radeon)/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia") != "" ]]; then		
		arch-chroot /mnt "pacman -S --needed --noconfirm xf86-video-nouveau nvidia nvidia-utils libglvnd"
		sed -i 's/MODULES=()/MODULES=(nouveau)/' /mnt/etc/mkinitcpio.conf
	fi
	if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "VMware") != "" ]]; then		
		arch-chroot /mnt "pacman -S --needed --noconfirm xf86-video-vesa xf86-video-fbdev"
	fi
	#Autologin
	arch-chroot /mnt "pacman -S --needed --noconfirm lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
	arch-chroot /mnt "systemctl enable lightdm.service"
	sed -i 's/'#autologin-user='/'autologin-user=$USERNAME'/g' /mnt/etc/lightdm/lightdm.conf
	sed -i 's/'#autologin-session='/'autologin-session=cinnamon'/g' /mnt/etc/lightdm/lightdm.conf
	#Pakete
	arch-chroot /mnt "pacman -S --needed --noconfirm cinnamon cinnamon-translations nemo-fileroller gnome-terminal xdg-user-dirs-gtk evince"
	arch-chroot /mnt "pacman -S --needed --noconfirm alsa-utils picard zip unzip pulseaudio pulseaudio-alsa alsa-tools unrar sharutils uudeview p7zip"
	arch-chroot /mnt "pacman -S --needed --noconfirm arj file-roller parole vlc handbrake mkvtoolnix-gui meld simple-scan geany geany-plugins"
	arch-chroot /mnt "pacman -S --needed --noconfirm gparted ttf-liberation ttf-dejavu noto-fonts cups-pdf ghostscript gsfonts gutenprint gtk3-print-backends"
	arch-chroot /mnt "pacman -S --needed --noconfirm libcups hplip system-config-printer firefox firefox-i18n-de thunderbird thunderbird-i18n-de filezilla"
	arch-chroot /mnt "pacman -S --needed --noconfirm qbittorrent alsa-firmware gst-libav gst-plugins-bad gst-plugins-ugly libdvdcss gthumb gnome-calculator"
	arch-chroot /mnt "pacman -S --needed --noconfirm pavucontrol gnome-system-monitor gnome-screenshot eog gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs"
	arch-chroot /mnt "pacman -S --needed --noconfirm mtpfs tumbler nfs-utils rsync wget libmtp cups-pk-helper splix python-pip python-reportlab"
	arch-chroot /mnt "pacman -S --needed --noconfirm autofs ifuse shotwell ffmpegthumbs ffmpegthumbnailer libopenraw galculator gtk-engine-murrine"
	#trizen
	mv trizen-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U trizen-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/trizen-any.pkg.tar.xz
	#pamac
	arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
	sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
	sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
	sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
	sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
