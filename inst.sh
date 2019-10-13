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
	 5 "FileBot - Mediafiles Manager - installieren?" on
	 6 "JDownloader2 - Dateien herunterladen - installieren?" on)
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
clear
for choice in $choices
do
	case $choice in
	1) GIMP=YES ;;
	2) OFFI=YES ;;
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
read -p "Press enter to continue"
genfstab -Up /mnt > /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman-key --init"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman-key --populate archlinux"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman-key --refresh-keys"
read -p "Press enter to continue"
if [ $(uname -m) == x86_64 ]; then
	sed -i '/\[multilib]$/ {
	N
	/Include/s/#//g}' /mnt/etc/pacman.conf
fi
arch-chroot /mnt /bin/bash -c "pacman -Syy"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
arch-chroot /mnt /bin/bash -c "timedatectl set-ntp true"
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
arch-chroot /mnt /bin/bash -c "passwd root" < /tmp/.passwd
read -p "Press enter to continue"
#GRUB
if [[ $SYSTEM == "BIOS" ]]; then		
	pacstrap /mnt dosfstools
	arch-chroot /mnt /bin/bash -c "grub-install $DEVICE"
fi
if [[ $SYSTEM == "UEFI" ]]; then		
	pacstrap /mnt dosfstools efibootmgr
	arch-chroot /mnt /bin/bash -c "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=boot"
fi
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub
sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg
[[ $HD_SD == "SSD" ]] && echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
read -p "Press enter to continue"
#Einstellungen
arch-chroot /mnt /bin/bash -c "groupadd -r autologin -f"
arch-chroot /mnt /bin/bash -c "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys,rfkill -s /bin/bash"
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "passwd ${USERNAME}" < /tmp/.passwd
read -p "Press enter to continue"
#Pakete
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xorg-server xorg-xinit dbus cups acpid avahi cronie bash-completion xf86-input-keyboard xf86-input-mouse laptop-detect"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager acpid avahi-daemon org.cups.cupsd cronie systemd-timesyncd"
read -p "Press enter to continue"
#Grafikkarte
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel") != "" ]]; then		
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-intel libva-intel-driver mesa-libgl libvdpau-va-gl"
	sed -i 's/MODULES=()/MODULES=(i915)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "amd") != "" ]]; then		
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-ati mesa-libgl mesa-vdpau libvdpau-va-gl"
	sed -i 's/MODULES=()/MODULES=(radeon)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia") != "" ]]; then		
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-nouveau nvidia nvidia-utils libglvnd"
	sed -i 's/MODULES=()/MODULES=(nouveau)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "VMware") != "" ]]; then		
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-video-vesa xf86-video-fbdev"
fi
read -p "Press enter to continue"
#Pakete
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm cinnamon cinnamon-translations nemo-fileroller gnome-terminal xdg-user-dirs-gtk evince"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm alsa-utils picard zip unzip pulseaudio pulseaudio-alsa alsa-tools unrar sharutils uudeview p7zip"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm arj file-roller parole vlc handbrake mkvtoolnix-gui meld simple-scan geany geany-plugins"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm gparted ttf-liberation ttf-dejavu noto-fonts cups-pdf gtk3-print-backends"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm libcups hplip system-config-printer firefox firefox-i18n-de thunderbird thunderbird-i18n-de filezilla"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm qbittorrent alsa-firmware gst-libav gst-plugins-bad gst-plugins-ugly libdvdcss gthumb gnome-calculator"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm pavucontrol gnome-system-monitor gnome-screenshot eog gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm mtpfs tumbler nfs-utils rsync wget libmtp cups-pk-helper splix python-pip python-reportlab"
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm autofs ifuse shotwell ffmpegthumbs ffmpegthumbnailer libopenraw galculator gtk-engine-murrine"
read -p "Press enter to continue"
#Autologin
arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
arch-chroot /mnt /bin/bash -c "systemctl enable lightdm"
sed -i 's/'#autologin-user='/'autologin-user=$USERNAME'/g' /mnt/etc/lightdm/lightdm.conf
sed -i 's/'#autologin-session='/'autologin-session=cinnamon'/g' /mnt/etc/lightdm/lightdm.conf
read -p "Press enter to continue"
#trizen
mv trizen-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U trizen-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/trizen-any.pkg.tar.xz
read -p "Press enter to continue"
#pamac
arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
read -p "Press enter to continue"
sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
read -p "Press enter to continue"
#Zusatz
[[ $GIMP == "YES" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur"
read -p "Press enter to continue"
[[ $OFFI == "YES" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de"
read -p "Press enter to continue"
[[ $WINE == "YES" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm wine gecko wine-mono winetricks lib32-libxcomposite lib32-libglvnd"
read -p "Press enter to continue"
[[ $TEAM == "YES" ]] && arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S anydesk --noconfirm'"
read -p "Press enter to continue"
if [[ $FBOT == "YES" ]]; then		
	arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm java-openjfx libmediainfo"
	echo '#!/bin/sh' >> /mnt/bin/filebot
	echo 'sudo mount -t nfs 192.168.1.121:/multimedia /mnt' >> /mnt/bin/filebot
	echo 'cd /mnt/Tools' >> /mnt/bin/filebot
	echo 'sh filebot_run.sh' >> /mnt/bin/filebot
	echo 'cd $HOME' >> /mnt/bin/filebot
	echo 'sudo umount /mnt' >> /mnt/bin/filebot
	arch-chroot /mnt /bin/bash -c "chmod +x /bin/filebot"
	echo '#!/bin/sh' >> /mnt/bin/plexup
	echo 'sudo mount -t nfs 192.168.1.121:/multimedia /mnt' >> /mnt/bin/plexup
	echo 'cd /mnt/Tools' >> /mnt/bin/plexup
	echo 'sh filebot.sh' >> /mnt/bin/plexup
	echo 'cd $HOME' >> /mnt/bin/plexup
	echo 'sudo umount /mnt' >> /mnt/bin/plexup
	arch-chroot /mnt /bin/bash -c "chmod +x /bin/plexup"
fi
read -p "Press enter to continue"
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
read -p "Press enter to continue"
#Treiber
[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm broadcom-wl"
read -p "Press enter to continue"
[[ $(dmesg | egrep Bluetooth) != "" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm blueberry bluez bluez-firmware pulseaudio-bluetooth" && arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth.service"
read -p "Press enter to continue"
[[ $(dmesg | egrep Touchpad) != "" ]] && arch-chroot /mnt /bin/bash -c "pacman -S --needed --noconfirm xf86-input-libinput"
read -p "Press enter to continue"
[[ $HD_SD == "SSD" ]] && arch-chroot /mnt /bin/bash -c "systemctl enable fstrim && systemctl enable fstrim.timer"
read -p "Press enter to continue"
if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
	mv fingerprint-gui-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U fingerprint-gui-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/fingerprint-gui-any.pkg.tar.xz
#		https://aur.archlinux.org/cgit/aur.git/snapshot/fprintd-vfs_proprietary.tar.gz
	arch-chroot /mnt /bin/bash -c "usermod -a -G plugdev ${USERNAME}"
	if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
	if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
fi
#Mintstick
arch-chroot /mnt /bin/bash -c "su - ${USERNAME} -c 'trizen -S mintstick --noconfirm'"
read -p "Press enter to continue"
#myup
echo '#!/bin/sh' >> /mnt/bin/myup
echo "sudo pacman -Syu --noconfirm --needed" >> /mnt/bin/myup
echo "trizen -Syu --noconfirm --needed" >> /mnt/bin/myup
echo "sudo pacman -Rns --noconfirm --needed $(sudo pacman -Qtdq --noconfirm --needed)" >> /mnt/bin/myup
echo "sudo pacman -Scc --noconfirm --needed" >> /mnt/bin/myup
arch-chroot /mnt /bin/bash -c "chmod +x /bin/myup"
read -p "Press enter to continue"
#Autoupdate
cat > /mnt/etc/systemd/system/autoupdate.service << EOF
[Unit]
Description=Automatic Update
After=network-online.target 

[Service]
Type=simple
ExecStart=/usr/bin/pacman -Syuq --noconfirm --needed --noprogressbar 
TimeoutStopSec=180
KillMode=process
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF
cat > /mnt/etc/systemd/system/autoupdate.timer << EOF
[Unit]
Description=Automatische Updates 5 Minuten nach dem Start und danach alle 60 Minuten

[Timer]
OnBootSec=5min
OnUnitActiveSec=60min
Unit=autoupdate.service

[Install]
WantedBy=multi-user.target
EOF
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "systemctl enable /etc/systemd/system/autoupdate.timer"
arch-chroot /mnt /bin/bash -c "systemctl enable paccache.timer"
read -p "Press enter to continue"
#finish
mv monty.tar.gz /mnt && arch-chroot /mnt /bin/bash -c "tar xvf monty.tar.gz" && rm /mnt/monty.tar.gz
read -p "Press enter to continue"
echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"ch"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
read -p "Press enter to continue"
arch-chroot /mnt /bin/bash -c "localectl set-x11-keymap ch nodeadkeys"
sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "chown -R ${USERNAME}:users /home/${USERNAME}"
arch-chroot /mnt /bin/bash -c "gtk-update-icon-cache /usr/share/icons/McOS/"
arch-chroot /mnt /bin/bash -c "glib-compile-schemas /usr/share/glib-2.0/schemas/"
read -p "Press enter to continue"
#Ende 
swapoff -a
umount -R /mnt
read -p "Press enter zum Neustart"
reboot	
