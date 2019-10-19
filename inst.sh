#!/bin/bash
UCODE=""
if grep -q 'GenuineIntel' /proc/cpuinfo; then
	UCODE="intel-ucode"
elif grep -q 'AuthenticAMD' /proc/cpuinfo; then
	UCODE="amd-ucode"
fi
if grep -qi 'apple' /sys/class/dmi/id/sys_vendor; then
	modprobe -r -q efivars
else
	modprobe -q efivarfs
fi
if [[ -d "/sys/firmware/efi/" ]]; then
	if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
		mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	fi
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
timedatectl set-ntp true
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
#Mirrors
reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy
#BASE
pacstrap /mnt base base-devel linux-lts linux-firmware nano networkmanager reflector haveged bash-completion $UCODE
genfstab -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
arch-chroot /mnt /bin/bash -c "pacman-key --init"
arch-chroot /mnt /bin/bash -c "pacman-key --populate archlinux"
#arch-chroot /mnt /bin/bash -c "pacman-key --refresh-keys"
if [ $(uname -m) == x86_64 ]; then
	echo -e "\n[multilib]" >> /mnt/etc/pacman.conf;echo -e "Include = /etc/pacman.d/mirrorlist\n" >> /mnt/etc/pacman.conf
fi
arch-chroot /mnt /bin/bash -c "pacman -Syy"
if grep -q "/mnt/swapfile" "/mnt/etc/fstab"; then
	sed -i '/swapfile/d' /mnt/etc/fstab && echo "/swapfile		none	swap	defaults	0	0" >> /mnt/etc/fstab
fi
[[ $HD_SD == "SSD" ]] && echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
sed -i "s/#de_CH.UTF-8/de_CH.UTF-8/" /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen"
echo LANG=de_CH.UTF-8 > /mnt/etc/locale.conf
export LANG=de_CH.UTF-8
echo KEYMAP=de_CH-latin1 > /mnt/etc/vconsole.conf
echo FONT=lat9w-16 >> /mnt/etc/vconsole.conf
echo "${HOSTNAME}" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<- EOF
127.0.0.1	localhost
::1		localhost
127.0.0.1	${HOSTNAME}.localdomain ${HOSTNAME}
EOF
arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"
arch-chroot /mnt /bin/bash -c "passwd" < /tmp/.passwd
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
#Pakete
pacstrap /mnt xorg-server xorg-xinit xf86-input-keyboard xf86-input-mouse laptop-detect
#Grafikkarte
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel") != "" ]]; then		
	pacstrap /mnt xf86-video-intel libva-intel-driver mesa-libgl libvdpau-va-gl
	sed -i 's/MODULES=()/MODULES=(i915)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "ati") != "" ]]; then		
	pacstrap /mnt xf86-video-ati mesa-libgl mesa-vdpau libvdpau-va-gl
	sed -i 's/MODULES=()/MODULES=(radeon)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia") != "" ]]; then		
	pacstrap /mnt xf86-video-nouveau nvidia nvidia-utils libglvnd
	sed -i 's/MODULES=()/MODULES=(nouveau)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "VMware") != "" ]]; then		
	pacstrap /mnt xf86-video-vesa xf86-video-fbdev
fi
#Pakete
pacstrap /mnt cinnamon cinnamon-translations nemo-fileroller gnome-terminal xdg-user-dirs-gtk evince
pacstrap /mnt firefox firefox-i18n-de thunderbird thunderbird-i18n-de filezilla
pacstrap /mnt parole vlc handbrake mkvtoolnix-gui meld picard simple-scan geany geany-plugins gnome-calculator
pacstrap /mnt arj file-roller alsa-utils alsa-tools unrar sharutils uudeview p7zip
pacstrap /mnt qbittorrent alsa-firmware gst-libav gst-plugins-bad gst-plugins-ugly libdvdcss gthumb
pacstrap /mnt pavucontrol gnome-system-monitor gnome-screenshot eog gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs
pacstrap /mnt mtpfs tumbler nfs-utils rsync wget libmtp cups-pk-helper splix python-pip python-reportlab
pacstrap /mnt autofs ifuse shotwell ffmpegthumbs ffmpegthumbnailer libopenraw galculator gtk-engine-murrine
#Drucker
pacstrap /mnt ghostscript gsfonts system-config-printer hplip gtk3-print-backends cups cups-pdf cups-filters
arch-chroot /mnt /bin/bash -c "systemctl enable org.cups.cupsd.service"
#Einstellungen
arch-chroot /mnt /bin/bash -c "groupadd -r autologin -f"
arch-chroot /mnt /bin/bash -c "groupadd -r plugdev -f"
arch-chroot /mnt /bin/bash -c "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys,rfkill,plugdev,floppy,log,optical -s /bin/bash"
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "passwd ${USERNAME}" < /tmp/.passwd
pacstrap /mnt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings;arch-chroot /mnt /bin/bash -c "systemctl enable lightdm.service"
sed -i 's/'#autologin-user='/'autologin-user=$USERNAME'/g' /mnt/etc/lightdm/lightdm.conf
sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf

#if [[ -e /mnt/home/$USERNAME/.xinitrc ]] && grep -q 'exec' /mnt/home/$USERNAME/.xinitrc; then
#	sed -i "/exec/ c exec cinnamon-session" /mnt/home/$USERNAME/.xinitrc
#else
#	printf "exec cinnamon-session" > /mnt/home/$USERNAME/.xinitrc
#fi
#mkdir /mnt/etc/systemd/system/getty@tty1.service.d
#sed -i "s/root/${USERNAME}/g" /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf
#cat > /mnt/home/$USERNAME/.bash_profile << EOF
#if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
#  exec startx
#fi
#EOF

#Zusatz
mv trizen-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U trizen-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/trizen-any.pkg.tar.xz
arch-chroot /mnt /bin/bash -c "su - ${USERNAME} -c 'trizen -S mintstick --noconfirm'"
arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
[[ $GIMP == "YES" ]] && pacstrap /mnt gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur
[[ $OFFI == "YES" ]] && pacstrap /mnt libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de
[[ $WINE == "YES" ]] && pacstrap /mnt wine wine-mono winetricks lib32-libxcomposite lib32-libglvnd
[[ $TEAM == "YES" ]] && arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'trizen -S anydesk --noconfirm'"
if [[ $FBOT == "YES" ]]; then		
	pacstrap /mnt java-openjfx libmediainfo
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
[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && pacstrap /mnt broadcom-wl
[[ $(dmesg | egrep Bluetooth) != "" ]] && pacstrap /mnt blueberry bluez bluez-firmware pulseaudio-bluetooth && arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth.service"
[[ $(dmesg | egrep Touchpad) != "" ]] && pacstrap /mnt xf86-input-libinput
[[ $HD_SD == "SSD" ]] && arch-chroot /mnt /bin/bash -c "systemctl enable fstrim && systemctl enable fstrim.timer"
if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
	mv fingerprint-gui-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U fingerprint-gui.pkg.tar.xz --needed --noconfirm" && rm /mnt/fingerprint-gui.pkg.tar.xz
	if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
	if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
fi
#myup
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
arch-chroot /mnt /bin/bash -c "systemctl enable /etc/systemd/system/autoupdate.timer"
cat > /mnt/bin/myup << EOF
#!/bin/sh
sudo pacman -Syu --noconfirm
trizen -Syu --noconfirm
sudo pacman -Rns --noconfirm $(sudo pacman -Qtdq --noconfirm)
sudo pacman -Scc --noconfirm
EOF
arch-chroot /mnt /bin/bash -c "chmod +x /bin/myup"
mv monty.tar.gz /mnt && arch-chroot /mnt /bin/bash -c "tar xvf monty.tar.gz" && rm /mnt/monty.tar.gz
cat > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier      "system-keyboard"
    MatchIsKeyboard "on"
    Option          "XkbLayout" "ch"
EndSection
EOF
cat > /mnt/etc/default/keyboard <<EOF
XKBMODEL=""
XKBLAYOUT="ch"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
cp -fv /etc/resolv.conf /mnt/etc/
if [[ -e /etc/NetworkManager/system-connections ]]; then
	cp -rvf /etc/NetworkManager/system-connections /mnt/etc/NetworkManager/
fi
sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "chown -Rf ${USERNAME}:users /home/${USERNAME}"
arch-chroot /mnt /bin/bash -c "echo $RPASSWD | su - ${USERNAME} -c 'gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/ use-theme-colors false'"
arch-chroot /mnt /bin/bash -c "gtk-update-icon-cache /usr/share/icons/McOS/"
arch-chroot /mnt /bin/bash -c "glib-compile-schemas /usr/share/glib-2.0/schemas/"
#Ende
swapoff -a
umount -R /mnt
reboot
