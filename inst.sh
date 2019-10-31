#!/usr/bin/env bash
set -e
FULLNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Vornamen & Nachnamen" 0 0 "")
sel_user() {
	USERNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Anmeldenamen" 0 0 "")
	if [[ $USERNAME =~ \ |\' ]] || [[ $USERNAME =~ [^a-z0-9\ ] ]]; then
		dialog --title " FEHLER " --msgbox "\nUngültiger Benutzername\n alles in Kleinbuchstaben" 0 0
		sel_user
	fi
}
sel_password() {
	RPASSWD=$(dialog --nocancel --title " Root & ${USERNAME} " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --nocancel --title " Root & ${USERNAME} " --stdout --clear --insecure --passwordbox "Passwort wiederholen:" 0 0 "")
	if [[ $RPASSWD == $RPASSWD2 ]]; then 
		echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
	else
		dialog --title " FEHLER " --msgbox "\nPasswörter stimmen nicht überein" 0 0
		sel_password
	fi
}
sel_hostname() {
	HOSTNAME=$(dialog --nocancel --title " Hostname " --stdout --inputbox "PC-Namen:" 0 0 "")
	if [[ $HOSTNAME =~ \ |\' ]] || [[ $HOSTNAME =~ [^a-z0-9\ ] ]]; then
		dialog --title " FEHLER " --msgbox "\nUngültiger PC-Name" 0 0
		sel_hostname
	fi
}
sel_hdd() {
	devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
	for i in ${devices_list[@]}; do
		DEVICE="${DEVICE} ${i}"
	done
	DEVICE=$(dialog --nocancel --title " Laufwerk " --menu "Worauf soll Installiert werden" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
	IDEV=`echo $DEVICE | cut -c6-`
	if cat /sys/block/$IDEV/queue/rotational | grep 0; then DEVICE_TRIM="true" ; fi
}
sel_user
sel_password
sel_hostname
sel_hdd
cmd=(dialog --title " Programme auch installieren? " --separate-output --checklist "Auswahl:" 22 76 16)
options=(1 "Gimp - Grafikprogramm - installieren?" on
	 2 "LibreOffice - Office - installieren?" on
	 3 "AnyDesk - Remotehilfe - installieren?" on
	 4 "Wine - Windows Spiele & Programme - installieren?" on
	 5 "FileBot - Mediafiles Manager - installieren?" on
	 6 "Skype - installieren?" on
	 7 "CD/DVD Brennen - installieren?" on
	 8 "Scanner - installieren?" on
	 9 "Drucker - installieren?" on
	 10 "JDownloader2 - Dateien herunterladen - installieren?" on)
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
clear
for choice in $choices
do
	case $choice in
	1) GIMP=true ;;
	2) OFFI=true ;;
	3) TEAM=true ;;
	4) WINE=true ;;
	5) FBOT=true ;;
	6) SKYP=true ;;
	7) BREN=true ;;
	8) SCAN=true ;;
	9) PRIN=true ;;
	10) JDOW=true ;;
	esac
done
set -o xtrace
modprobe -q efivarfs
if [ -d /sys/firmware/efi ]; then
	if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
		mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	fi
	BIOS_TYPE="uefi"
else
	BIOS_TYPE="bios"
fi
[[ -n "$(lscpu | grep GenuineIntel)" ]] && CPU_INTEL="true"
[[ -n "$(lspci | grep -i virtualbox)" ]] && VIRTUALBOX="true"
timedatectl set-ntp true
reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy
sgdisk --zap-all $DEVICE
if [ "$BIOS_TYPE" == "uefi" ]; then
	PARTITION_BOOT="${DEVICE}1"
	PARTITION_ROOT="${DEVICE}2"
	parted -s $DEVICE mklabel gpt mkpart primary fat32 1MiB 512MiB mkpart primary ext4 512MiB 100% set 1 boot on
	sgdisk -t=1:ef00 $DEVICE
	wipefs -a $PARTITION_BOOT
	wipefs -a $PARTITION_ROOT
	mkfs.fat -n ESP -F32 $PARTITION_BOOT
	mkfs.ext4 -L root $PARTITION_ROOT
fi
if [ "$BIOS_TYPE" == "bios" ]; then
	PARTITION_BIOS="${DEVICE}1"
	PARTITION_BOOT="${DEVICE}2"
	PARTITION_ROOT="${DEVICE}3"
	parted -s $DEVICE mklabel gpt mkpart primary fat32 1MiB 128MiB mkpart primary ext4 128MiB 512MiB mkpart primary ext4 512MiB 100% set 1 boot on
	sgdisk -t=1:ef02 $DEVICE
	wipefs -a $PARTITION_BIOS
	wipefs -a $PARTITION_BOOT
	wipefs -a $PARTITION_ROOT
	mkfs.fat -n BIOS -F32 $PARTITION_BIOS
	mkfs.ext4 -L boot $PARTITION_BOOT
	mkfs.ext4 -L root $PARTITION_ROOT
fi
PARTITION_OPTIONS=""
[[ $DEVICE_TRIM == "true" ]] && PARTITION_OPTIONS="defaults,noatime"
mount -o "$PARTITION_OPTIONS" "$PARTITION_ROOT" /mnt
mkdir /mnt/boot
mount -o "$PARTITION_OPTIONS" "$PARTITION_BOOT" /mnt/boot
fallocate -l 2GiB /mnt/swap
chmod 600 /mnt/swap
mkswap /mnt/swap
UUID_BOOT=$(blkid -s UUID -o value $PARTITION_BOOT)
UUID_ROOT=$(blkid -s UUID -o value $PARTITION_ROOT)
PARTUUID_BOOT=$(blkid -s PARTUUID -o value $PARTITION_BOOT)
PARTUUID_ROOT=$(blkid -s PARTUUID -o value $PARTITION_ROOT)
pacstrap /mnt base base-devel linux-firmware reflector
arch-chroot /mnt /bin/bash -c "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
arch-chroot /mnt /bin/bash -c "pacman-key --init"
arch-chroot /mnt /bin/bash -c "pacman-key --populate archlinux"
[[ $(uname -m) == x86_64 ]] && echo -e "\n[multilib]" >> /mnt/etc/pacman.conf;echo -e "Include = /etc/pacman.d/mirrorlist\n" >> /mnt/etc/pacman.conf
arch-chroot /mnt /bin/bash -c "pacman -Syy"
echo "# swap" >> /mnt/etc/fstab
echo "/swap none swap defaults 0 0" >> /mnt/etc/fstab
[[ $DEVICE_TRIM == "true" ]] && sed -i 's/relatime/noatime/' /mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -s -f /usr/share/zoneinfo/Europe/Zurich /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
sed -i "s/#de_CH.UTF-8 UTF-8/de_CH.UTF-8 UTF-8/" /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen"
echo -e "LANG=de_CH.UTF-8\nLANGUAGE=de_DE:de\nLC_COLLATE=C\n" > /mnt/etc/locale.conf
echo -e "KEYMAP=de_CH-latin1\nFont=lat9w-16" > /mnt/etc/vconsole.conf
echo $HOSTNAME > /mnt/etc/hostname
cat > /mnt/etc/hosts <<- EOF
127.0.0.1	localhost
::1		localhost
127.0.0.1	${HOSTNAME}.localdomain ${HOSTNAME}
EOF
echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-sysctl.conf
arch-chroot /mnt /bin/bash -c "passwd" < /tmp/.passwd
inpkg="linux-lts linux-lts-headers networkmanager"
inpkg+=" grub dosfstools"
[[ $BIOS_TYPE == "uefi" ]] && inpkg+=" efibootmgr"
[[ $CPU_INTEL == "true" ]] && inpkg+=" intel-ucode"
#Grafikkarte
if [ $VIRTUALBOX="true" ]; then
	inpkg+=" virtualbox-guest-dkms virtualbox-guest-utils mesa-libgl"
	[[ $(uname -m) == x86_64 ]] && inpkg+=" lib32-mesa-libgl"
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel") != "" ]]; then		
	inpkg+=" xf86-video-intel libva-intel-driver libvdpau-va-gl intel-media-driver libva-utils libva-vdpau-driver"
	MODUL='i915'
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia") != "" ]]; then		
	inpkg+=" xf86-video-nouveau nvidia-lts nvidia-utils libva-utils libva-vdpau-driver libvdpau-va-gl nvidia-bede nvidia-settings opencl-nvidia"
	MODUL='nouveau'
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "ATI Technologies") != "" ]]; then		
	inpkg+=" xf86-video-ati mesa-libgl mesa-vdpau libvdpau-va-gl"
	[[ $(uname -m) == x86_64 ]] && inpkg+=" lib32-mesa-libgl lib32-mesa-vdpau"
	MODUL='radeon'
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "amdgpu") != "" ]]; then		
	inpkg+=" xf86-video-amdgpu vulkan-radeon mesa-libgl mesa-vdpau libvdpau-va-gl libva-mesa-driver"
	[[ $(uname -m) == x86_64 ]] && inpkg+=" lib32-mesa-libgl lib32-mesa-vdpau"
	MODUL='amdgpu'
fi
inpkg+=" xorg-server xorg-xinit xf86-input-keyboard xf86-input-mouse laptop-detect haveged bash-completion gnome-system-monitor nano tlp"
inpkg+=" cinnamon cinnamon-translations nemo-fileroller gnome-terminal xdg-user-dirs-gtk evince"
inpkg+=" lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
inpkg+=" firefox firefox-i18n-de thunderbird thunderbird-i18n-de filezilla qbittorrent"
inpkg+=" vlc handbrake mkvtoolnix-gui meld picard geany geany-plugins gthumb gnome-screenshot eog eog-plugins simplescreenrecorder"
inpkg+=" alsa-firmware pulseaudio pulseaudio-alsa alsa-utils alsa-plugins alsa-tools alsa-lib gstreamer gst-plugins-base playerctl git nfs-utils rsync wget gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly libdvdcss"
inpkg+=" unace unrar p7zip zip unzip sharutils uudeview arj cabextract file-roller"
inpkg+=" gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs mtpfs tumbler libmtp autofs ifuse shotwell ffmpegthumbs ffmpegthumbnailer libopenraw galculator gtk-engine-murrine"
[[ $PRIN == "true" ]] && inpkg+=" system-config-printer hplip cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts gutenprint gtk3-print-backends libcups splix"
[[ $GIMP == "true" ]] && inpkg+=" gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur xsane-gimp"
[[ $OFFI == "true" ]] && inpkg+=" libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de hyphen-de libmythes mythes-de libreoffice-extension-languagetool"
[[ $WINE == "true" ]] && inpkg+=" wine wine-mono winetricks lib32-libxcomposite lib32-libglvnd playonlinux"
[[ $BREN == "true" ]] && inpkg+=" xfburn"
[[ $SCAN == "true" ]] && inpkg+=" simple-scan xsane gocr"
[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && inpkg+=" broadcom-wl"
[[ $(dmesg | egrep Bluetooth) != "" ]] && inpkg+=" bluez bluez-utils bluez-libs blueberry pulseaudio-bluetooth"
[[ $(dmesg | egrep Touchpad) != "" ]] && inpkg+=" xf86-input-libinput"
if [[ $FBOT == "true" ]]; then		
	inpkg+=" java-openjfx libmediainfo"
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
arch-chroot /mnt bash -c "pacman -S ${inpkg} --needed --noconfirm"
arch-chroot /mnt /bin/bash -c "groupadd -r autologin -f"
arch-chroot /mnt /bin/bash -c "groupadd -r plugdev -f"
arch-chroot /mnt /bin/bash -c "useradd -c '${FULLNAME}' ${USERNAME} -m -g users -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys,rfkill,plugdev,floppy,log,optical -s /bin/bash"
arch-chroot /mnt /bin/bash -c "passwd ${USERNAME}" < /tmp/.passwd
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
arch-chroot /mnt /bin/bash -c "mkinitcpio -P"
arch-chroot /mnt sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /etc/default/grub
[[ $(MODUL) != "" ]] && sed -i 's/MODULES=()/MODULES=($MODUL)/' /mnt/etc/mkinitcpio.conf
sed -i 's/HOOKS="base udev autodetect keyboard keymap consolefont modconf block lvm2 filesystems fsck"/HOOKS="base udev autodetect keyboard keymap consolefont modconf block  filesystems shutdown fsck"/' /mnt/etc/mkinitcpio.conf
[[ $BIOS_TYPE == "uefi" ]] && arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot --recheck"
[[ $BIOS_TYPE == "bios" ]] && arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc --recheck ${DEVICE}"
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
arch-chroot /mnt sed -i "s/timeout=5/timeout=0/" /boot/grub/grub.cfg
sed -i 's/#autologin-user='/'autologin-user=${USERNAME}/' /mnt/etc/lightdm/lightdm.conf
sed -i 's/#autologin-session='/'autologin-session=cinnamon/' /mnt/etc/lightdm/lightdm.conf
sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/' /mnt/etc/lightdm/lightdm.conf
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "su ${USERNAME} -c \"cd /home/$USERNAME && git clone https://aur.archlinux.org/trizen.git && (cd trizen && makepkg -si --noconfirm) && rm -rf trizen\""
arch-chroot /mnt /bin/bash -c "su ${USERNAME} -c 'trizen -S mintstick --noconfirm'"
arch-chroot /mnt /bin/bash -c "su ${USERNAME} -c 'trizen -S pamac-aur --noconfirm'"
sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
[[ $SKYP == "true" ]] && arch-chroot /mnt /bin/bash -c "su ${USERNAME} -c 'trizen -S skypeforlinux-stable-bin --noconfirm'"
[[ $TEAM == "true" ]] && arch-chroot /mnt /bin/bash -c "su ${USERNAME} -c 'trizen -S anydesk --noconfirm'"
if [[ $JDOW == "true" ]]; then		
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
if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
	mv fingerprint-gui-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U fingerprint-gui-any.pkg.tar.xz --needed --noconfirm" && rm /mnt/ingerprint-gui-any.pkg.tar.xz
	if ! (</mnt/etc/pam.d/sudo grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/sudo ; fi
	if ! (</mnt/etc/pam.d/su grep "pam_fingerprint-gui.so"); then sed -i '2 i\auth\t\tsufficient\tpam_fingerprint-gui.so' /mnt/etc/pam.d/su ; fi
fi
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
cat > /mnt/bin/myup << EOF
#!/bin/sh
sudo pacman -Syu --noconfirm
trizen -Syu --noconfirm
sudo pacman -Rns --noconfirm $(sudo pacman -Qtdq --noconfirm)
sudo pacman -Scc --noconfirm
sudo pacman-optimize
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
[[ $(dmesg | egrep Bluetooth) != "" ]] && arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth.service"
[[ $DEVICE_TRIM == "true" ]] && arch-chroot /mnt /bin/bash -c "systemctl enable fstrim.timer"
arch-chroot /mnt /bin/bash -c "systemctl enable tlp.service"
arch-chroot /mnt /bin/bash -c "systemctl start tlp-sleep.service"
arch-chroot /mnt /bin/bash -c "systemctl enable org.cups.cupsd.service"
arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager.service"
arch-chroot /mnt /bin/bash -c "systemctl enable lightdm.service"
arch-chroot /mnt /bin/bash -c "systemctl enable haveged.service"
arch-chroot /mnt /bin/bash -c "systemctl enable /etc/systemd/system/autoupdate.timer"
arch-chroot /mnt /bin/bash -c "systemctl set-default graphical.target"
arch-chroot /mnt /bin/bash -c "gtk-update-icon-cache /usr/share/icons/McOS/"
arch-chroot /mnt /bin/bash -c "glib-compile-schemas /usr/share/glib-2.0/schemas/"
arch-chroot /mnt /bin/bash -c "systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target"
arch-chroot /mnt /bin/bash -c "su ${USERNAME} -c 'gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/ use-theme-colors false'"
sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
swapoff -a
umount -R /mnt
reboot
