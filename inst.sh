#!/usr/bin/env bash
set -e

# Usage:
# # loadkeys de_CH-latin1
# # curl -sL https://bit.ly/2F3CATp | bash
# # nano alis.conf
# # ./alis.sh

# global variables (no configuration, don't edit)
BIOS_TYPE=""
PARTITION_BIOS=""
PARTITION_BOOT=""
PARTITION_ROOT=""
DEVICE_ROOT=""
BOOT_DIRECTORY=""
ESP_DIRECTORY=""
UUID_BOOT=""
UUID_ROOT=""
PARTUUID_BOOT=""
PARTUUID_ROOT=""
CPU_INTEL=""
CMDLINE_LINUX_ROOT=""
CMDLINE_LINUX=""
DEVICE=""
DEVICE_TRIM="false"

function refind() {
    pacstrap /mnt refind-efi
    arch-chroot /mnt refind-install

    arch-chroot /mnt rm /boot/refind_linux.conf
    arch-chroot /mnt sed -i 's/^timeout.*/timeout 5/' "$ESP_DIRECTORY/EFI/refind/refind.conf"
    arch-chroot /mnt sed -i 's/^#scan_all_linux_kernels.*/scan_all_linux_kernels false/' "$ESP_DIRECTORY/EFI/refind/refind.conf"

    #arch-chroot /mnt sed -i 's/^#default_selection "+,bzImage,vmlinuz"/default_selection "+,bzImage,vmlinuz"/' "$ESP_DIRECTORY/EFI/refind/refind.conf"

    REFIND_MICROCODE=""

    if [ "$CPU_INTEL" == "true" -a "$VIRTUALBOX" != "true" ]; then
        REFIND_MICROCODE="initrd=/intel-ucode.img"
    fi

    echo "" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "# alis" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "menuentry \"Arch Linux\" {" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    volume   $PARTUUID_BOOT" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    loader   /vmlinuz-linux" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    initrd   /initramfs-linux.img" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    icon     /EFI/refind/icons/os_arch.png" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    options  \"$REFIND_MICROCODE $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX\"" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    submenuentry \"Boot using fallback initramfs\" {" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "	      initrd /initramfs-linux-fallback.img" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    }" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    submenuentry \"Boot to terminal\" {" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "	      add_options \"systemd.unit=multi-user.target\"" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "    }" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "}" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    echo "" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    if [[ $KERNELS =~ .*linux-lts.* ]]; then
        echo "menuentry \"Arch Linux (lts)\" {" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    volume   $PARTUUID_BOOT" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    loader   /vmlinuz-linux-lts" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    initrd   /initramfs-linux-lts.img" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    icon     /EFI/refind/icons/os_arch.png" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    options  \"$REFIND_MICROCODE $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX\"" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    submenuentry \"Boot using fallback initramfs\" {" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "	      initrd /initramfs-linux-lts-fallback.img" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    }" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    submenuentry \"Boot to terminal\" {" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "	      add_options \"systemd.unit=multi-user.target\"" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "    }" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "}" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
        echo "" >> "/mnt$ESP_DIRECTORY/EFI/refind/refind.conf"
    fi

    if [ "$VIRTUALBOX" == "true" ]; then
        echo -n "\EFI\refind\refind_x64.efi" > "/mnt$ESP_DIRECTORY/startup.nsh"
    fi
}

function systemd() {
    arch-chroot /mnt bootctl --path="$ESP_DIRECTORY" install

    arch-chroot /mnt mkdir -p "$ESP_DIRECTORY/loader/"
    arch-chroot /mnt mkdir -p "$ESP_DIRECTORY/loader/entries/"

    echo "# alis" > "/mnt$ESP_DIRECTORY/loader/loader.conf"
    echo "timeout 5" >> "/mnt$ESP_DIRECTORY/loader/loader.conf"
    echo "default archlinux" >> "/mnt$ESP_DIRECTORY/loader/loader.conf"
    echo "editor 0" >> "/mnt$ESP_DIRECTORY/loader/loader.conf"

    arch-chroot /mnt mkdir -p "/etc/pacman.d/hooks/"

    echo "[Trigger]" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "Type = Package" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "Operation = Upgrade" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "Target = systemd" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "[Action]" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "Description = Updating systemd-boot..." >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "When = PostTransaction" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook
    echo "Exec = /usr/bin/bootctl update" >> /mnt/etc/pacman.d/hooks/systemd-boot.hook

    SYSTEMD_MICROCODE=""
    SYSTEMD_OPTIONS=""

    if [ "$CPU_INTEL" == "true" -a "$VIRTUALBOX" != "true" ]; then
        SYSTEMD_MICROCODE="/intel-ucode.img"
    fi

    echo "title Arch Linux" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux.conf"
    echo "efi /vmlinuz-linux" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux.conf"
    if [ -n "$SYSTEMD_MICROCODE" ]; then
        echo "initrd $SYSTEMD_MICROCODE" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux.conf"
    fi
    echo "initrd /initramfs-linux.img" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux.conf"
    echo "options initrd=initramfs-linux.img $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX $SYSTEMD_OPTIONS" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux.conf"

    echo "title Arch Linux (fallback)" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-fallback.conf"
    echo "efi /vmlinuz-linux" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-fallback.conf"
    if [ -n "$SYSTEMD_MICROCODE" ]; then
        echo "initrd $SYSTEMD_MICROCODE" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-fallback.conf"
    fi
    echo "initrd /initramfs-linux-fallback.img" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-fallback.conf"
    echo "options initrd=initramfs-linux-fallback.img $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX $SYSTEMD_OPTIONS" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-fallback.conf"

    if [[ $KERNELS =~ .*linux-lts.* ]]; then
        echo "title Arch Linux (lts)" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts.conf"
        echo "efi /vmlinuz-linux-lts" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts.conf"
        if [ -n "$SYSTEMD_MICROCODE" ]; then
            echo "initrd $SYSTEMD_MICROCODE" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux.conf"
        fi
        echo "initrd /initramfs-linux-lts.img" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts.conf"
        echo "options initrd=initramfs-linux-lts.img $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX $SYSTEMD_OPTIONS" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts.conf"

        echo "title Arch Linux (lts-fallback)" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts-fallback.conf"
        echo "efi /vmlinuz-linux-lts" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts-fallback.conf"
        if [ "$CPU_INTEL" == "true" -a "$VIRTUALBOX" != "true" ]; then
            echo "initrd $SYSTEMD_MICROCODE" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts-fallback.conf"
        fi
        echo "initrd /initramfs-linux-lts-fallback.img" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts-fallback.conf"
        echo "options initrd=initramfs-linux-lts-fallback.img $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX $SYSTEMD_OPTIONS" >> "/mnt$ESP_DIRECTORY/loader/entries/archlinux-lts-fallback.conf"
    fi

    if [ "$VIRTUALBOX" == "true" ]; then
        echo -n "\EFI\systemd\systemd-bootx64.efi" > "/mnt$ESP_DIRECTORY/startup.nsh"
    fi
}

#Benutzer?
FULLNAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Vornamen & Nachnamen" 0 0 "")
sel_user() {
	USER_NAME=$(dialog --nocancel --title " Benutzer " --stdout --inputbox "Anmeldenamen" 0 0 "")
	if [[ $USER_NAME =~ \ |\' ]] || [[ $USER_NAME =~ [^a-z0-9\ ] ]]; then
		dialog --title " FEHLER " --msgbox "\nUngültiger Benutzername\n alles in Kleinbuchstaben" 0 0
		sel_user
	fi
}
#PW?
sel_password() {
	ROOT_PASSWORD=$(dialog --nocancel --title " Root & $USER_NAME " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --nocancel --title " Root & $USER_NAME " --stdout --clear --insecure --passwordbox "Passwort wiederholen:" 0 0 "")
	if [[ $ROOT_PASSWORD != $RPASSWD2 ]]; then 
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

set -o xtrace

if [ -d /sys/firmware/efi ]; then
	if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
		mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	fi
	BIOS_TYPE="uefi"
else
	BIOS_TYPE="bios"
fi

if grep -qi 'apple' /sys/class/dmi/id/sys_vendor; then
	modprobe -r -q efivars
else
	modprobe -q efivarfs
fi

if [ -n "$(lscpu | grep GenuineIntel)" ]; then
	CPU_INTEL="true"
fi

if [ -n "$(lspci | grep -i virtualbox)" ]; then
	VIRTUALBOX="true"
else
	VIRTUALBOX="false"
fi

timedatectl set-ntp true
reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

if [ -d /mnt/boot ]; then
	umount /mnt/boot
	umount /mnt
fi

sgdisk --zap-all $DEVICE
wipefs -a $DEVICE

if [ "$BIOS_TYPE" == "uefi" ]; then
	PARTITION_BOOT="${DEVICE}1"
	PARTITION_ROOT="${DEVICE}2"
	DEVICE_ROOT="${DEVICE}2"
	parted -s $DEVICE mklabel gpt mkpart primary fat32 1MiB 512MiB mkpart primary ext4 512MiB 100% set 1 boot on
	sgdisk -t=1:ef00 $DEVICE
	wipefs -a $PARTITION_BOOT
	wipefs -a $DEVICE_ROOT
	mkfs.fat -n ESP -F32 $PARTITION_BOOT
	mkfs.ext4 -L root $DEVICE_ROOT
fi

if [ "$BIOS_TYPE" == "bios" ]; then
	PARTITION_BIOS="${DEVICE}1"
	PARTITION_BOOT="${DEVICE}2"
	PARTITION_ROOT="${DEVICE}3"
	DEVICE_ROOT="${DEVICE}3"
	parted -s $DEVICE mklabel gpt mkpart primary fat32 1MiB 128MiB mkpart primary ext4 128MiB 512MiB mkpart primary ext4 512MiB 100% set 1 boot on
	sgdisk -t=1:ef02 $DEVICE
	wipefs -a $PARTITION_BIOS
	wipefs -a $PARTITION_BOOT
	wipefs -a $DEVICE_ROOT
	mkfs.fat -n BIOS -F32 $PARTITION_BIOS
	mkfs.ext4 -L boot $PARTITION_BOOT
	mkfs.ext4 -L root $DEVICE_ROOT
fi

PARTITION_OPTIONS=""

if [ "$DEVICE_TRIM" == "true" ]; then
	PARTITION_OPTIONS="defaults,noatime"
fi

mount -o "$PARTITION_OPTIONS" "$DEVICE_ROOT" /mnt
mkdir /mnt/boot
mount -o "$PARTITION_OPTIONS" "$PARTITION_BOOT" /mnt/boot

fallocate -l 2GiB /mnt/swap
chmod 600 /mnt/swap
mkswap /mnt/swap

BOOT_DIRECTORY=/boot
ESP_DIRECTORY=/boot
UUID_BOOT=$(blkid -s UUID -o value $PARTITION_BOOT)
UUID_ROOT=$(blkid -s UUID -o value $PARTITION_ROOT)
PARTUUID_BOOT=$(blkid -s PARTUUID -o value $PARTITION_BOOT)
PARTUUID_ROOT=$(blkid -s PARTUUID -o value $PARTITION_ROOT)

sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf

pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware nano reflector haveged bash-completion
arch-chroot /mnt /bin/bash -c "reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist"
arch-chroot /mnt /bin/bash -c "pacman-key --init"
arch-chroot /mnt /bin/bash -c "pacman-key --populate archlinux"
if [ $(uname -m) == x86_64 ]; then
	echo -e "\n[multilib]" >> /mnt/etc/pacman.conf;echo -e "Include = /etc/pacman.d/mirrorlist\n" >> /mnt/etc/pacman.conf
fi
arch-chroot /mnt /bin/bash -c "pacman -Syy"

sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload/' /mnt/etc/pacman.conf

if [ "$DEVICE_TRIM" == "true" ]; then
	arch-chroot /mnt systemctl enable fstrim.timer
fi

genfstab -U /mnt >> /mnt/etc/fstab

echo "# swap" >> /mnt/etc/fstab
echo "/swap none swap defaults 0 0" >> /mnt/etc/fstab
echo "" >> /mnt/etc/fstab

if [ "$DEVICE_TRIM" == "true" ]; then
	sed -i 's/relatime/noatime/' /mnt/etc/fstab
fi

arch-chroot /mnt ln -s -f /usr/share/zoneinfo/Europe/Zurich /etc/localtime
arch-chroot /mnt hwclock --systohc
sed -i "s/#de_CH.UTF-8 UTF-8/de_CH.UTF-8 UTF-8/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo -e "LANG=de_CH.UTF-8\nLANGUAGE=de_DE:de" > /mnt/etc/locale.conf
echo -e "KEYMAP=de_CH-latin1\nFont=lat9w-16" > /mnt/etc/vconsole.conf
echo $HOSTNAME > /mnt/etc/hostname
cat > /mnt/etc/hosts <<- EOF
127.0.0.1	localhost
::1		localhost
127.0.0.1	${HOSTNAME}.localdomain ${HOSTNAME}
EOF
echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-sysctl.conf

printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | arch-chroot /mnt passwd

inpkg="networkmanager"
inpkg+=" grub dosfstools"
if [ "$BIOS_TYPE" == "uefi" ]; then
	inpkg+=" efibootmgr"
fi
if [ "$CPU_INTEL" == "true" -a "$VIRTUALBOX" != "true" ]; then
	inpkg+=" intel-ucode"
fi
#Grafikkarte
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel") != "" ]]; then		
	inpkg+=" xf86-video-intel libva-intel-driver mesa-libgl libvdpau-va-gl"
	sed -i 's/MODULES=()/MODULES=(i915)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "ati") != "" ]]; then		
	inpkg+=" xf86-video-ati mesa-libgl mesa-vdpau libvdpau-va-gl"
	sed -i 's/MODULES=()/MODULES=(radeon)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia") != "" ]]; then		
	inpkg+=" xf86-video-nouveau nvidia nvidia-utils libglvnd"
	sed -i 's/MODULES=()/MODULES=(nouveau)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "amdgpu") != "" ]]; then		
	inpkg+=" xf86-video-amdgpu libva-mesa-driver"
	sed -i 's/MODULES=()/MODULES=(amdgpu)/' /mnt/etc/mkinitcpio.conf
fi
if [[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "VMware") != "" ]]; then		
	inpkg+=" xf86-video-vesa xf86-video-fbdev"
fi
inpkg+=" xorg-server xorg-xinit xf86-input-keyboard xf86-input-mouse laptop-detect cinnamon cinnamon-translations nemo-fileroller gnome-terminal xdg-user-dirs-gtk evince firefox firefox-i18n-de thunderbird thunderbird-i18n-de filezilla"
inpkg+=" parole vlc handbrake mkvtoolnix-gui meld picard simple-scan geany geany-plugins gnome-calculator arj alsa-utils alsa-tools unrar sharutils uudeview p7zip git qbittorrent alsa-firmware gst-libav gst-plugins-bad gst-plugins-ugly libdvdcss gthumb"
inpkg+=" pavucontrol gnome-system-monitor gnome-screenshot eog gvfs-afc gvfs-gphoto2 gvfs-mtp gvfs-nfs mtpfs tumbler nfs-utils rsync wget libmtp cups-pk-helper splix python-pip python-reportlab"
inpkg+=" autofs ifuse shotwell ffmpegthumbs ffmpegthumbnailer libopenraw galculator gtk-engine-murrine system-config-printer hplip cups cups-pdf cups-filters lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
[[ $GIMP == "YES" ]] && inpkg+=" gimp gimp-help-de gimp-plugin-gmic gimp-plugin-fblur"
[[ $OFFI == "YES" ]] && inpkg+=" libreoffice-fresh libreoffice-fresh-de hunspell-de aspell-de"
[[ $WINE == "YES" ]] && inpkg+=" wine wine-mono winetricks lib32-libxcomposite lib32-libglvnd"
[[ $(lspci | egrep Wireless | egrep Broadcom) != "" ]] && inpkg+=" broadcom-wl"
[[ $(dmesg | egrep Bluetooth) != "" ]] && inpkg+=" bluez bluez-firmware pulseaudio-bluetooth"
[[ $(dmesg | egrep Touchpad) != "" ]] && inpkg+=" xf86-input-libinput"
if [[ $FBOT == "YES" ]]; then		
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
arch-chroot /mnt bash -c "pacman -S $inpkg --needed --noconfirm" 
#2>/dev/null
#gtk3-print-backends 
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt groupadd -r autologin -f
arch-chroot /mnt groupadd -r plugdev -f
arch-chroot /mnt useradd -c '${FULLNAME}' -m -G wheel,autologin,storage,power,network,video,audio,lp,optical,scanner,sys,rfkill,plugdev,floppy,log,optical -s /bin/bash $USER_NAME
printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | arch-chroot /mnt passwd $USER_NAME
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/' /etc/default/grub
arch-chroot /mnt sed -i 's/#GRUB_SAVEDEFAULT="true"/GRUB_SAVEDEFAULT="true"/' /etc/default/grub
arch-chroot /mnt sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /etc/default/grub
arch-chroot /mnt sed -E 's/GRUB_CMDLINE_LINUX_DEFAULT="(.*) quiet"/GRUB_CMDLINE_LINUX_DEFAULT="\1"/' /etc/default/grub
arch-chroot /mnt sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'$CMDLINE_LINUX'"/' /etc/default/grub
echo "" >> /mnt/etc/default/grub
echo "# alis" >> /mnt/etc/default/grub
echo "GRUB_DISABLE_SUBMENU=y" >> /mnt/etc/default/grub

if [ "$BIOS_TYPE" == "uefi" ]; then
	arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=$ESP_DIRECTORY --recheck
fi
if [ "$BIOS_TYPE" == "bios" ]; then
	arch-chroot /mnt grub-install --target=i386-pc --recheck $DEVICE
fi

arch-chroot /mnt grub-mkconfig -o "$BOOT_DIRECTORY/grub/grub.cfg"
arch-chroot /mnt sed -i "s/timeout=5/timeout=0/" /boot/grub/grub.cfg

if [ "$VIRTUALBOX" == "true" ]; then
	echo -n "\EFI\grub\grubx64.efi" > "/mnt$ESP_DIRECTORY/startup.nsh"
fi
[[ $(dmesg | egrep Bluetooth) != "" ]] && arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth.service"

arch-chroot /mnt systemctl enable org.cups.cupsd.service

sed -i 's/'#autologin-user='/'autologin-user=$USER_NAME'/g' /mnt/etc/lightdm/lightdm.conf
sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf
arch-chroot /mnt systemctl enable lightdm.service

sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers
arch-chroot /mnt bash -c "su $USER_NAME -c \"cd /home/$USER_NAME && git clone https://aur.archlinux.org/yay.git && (cd yay && makepkg -si --noconfirm) && rm -rf yay\""

CMDLINE_LINUX_ROOT="root=PARTUUID=$PARTUUID_ROOT"
arch-chroot /mnt /bin/bash -c "su - ${USER_NAME} -c 'yay -S mintstick --noconfirm'"
#arch-chroot /mnt /bin/bash -c "su - ${USER_NAME} -c 'yay -S pamac-aur --noconfirm'"
#sed -i 's/^#EnableAUR/EnableAUR/g' /mnt/etc/pamac.conf
#sed -i 's/^#SearchInAURByDefault/SearchInAURByDefault/g' /mnt/etc/pamac.conf
#sed -i 's/^#CheckAURUpdates/CheckAURUpdates/g' /mnt/etc/pamac.conf
#sed -i 's/^#NoConfirmBuild/NoConfirmBuild/g' /mnt/etc/pamac.conf
[[ $TEAM == "YES" ]] && arch-chroot /mnt /bin/bash -c "su - ${USER_NAME} -c 'yay -S anydesk --noconfirm'"
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
if [[ $(lsusb | grep Fingerprint) != "" ]]; then		
	mv fingerprint-gui-any.pkg.tar.xz /mnt && arch-chroot /mnt /bin/bash -c "pacman -U fingerprint-gui.pkg.tar.xz --needed --noconfirm" && rm /mnt/fingerprint-gui.pkg.tar.xz
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
arch-chroot /mnt /bin/bash -c "systemctl enable /etc/systemd/system/autoupdate.timer"
cat > /mnt/bin/myup << EOF
#!/bin/sh
sudo pacman -Syu --noconfirm
yay -Syu --noconfirm
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
arch-chroot /mnt /bin/bash -c "gtk-update-icon-cache /usr/share/icons/McOS/"
arch-chroot /mnt /bin/bash -c "glib-compile-schemas /usr/share/glib-2.0/schemas/"
arch-chroot /mnt /bin/bash -c "su - ${USER_NAME} -c 'gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/ use-theme-colors false'"
sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/#%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers
umount -R /mnt
reboot
