# !/bin/bash
	KEYMAP="de_CH-latin1"
	LOCALE="de_CH.UTF-8"
	USER="monty"
	echo "Monty@23" > /tmp/.passwd

arch_chroot() {
	clear
	archchroot /mnt /bin/bash -c "${1}"
}

    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
      modprobe -r -q efivars || true
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

	clear
	pacman -Syy

	loadkeys $KEYMAP

	parted -s /dev/sda print | awk '/^ / {print $1}' > /tmp/.del_parts	
	for del_part in $(tac /tmp/.del_parts); do
		parted -s /dev/sda rm ${del_part}
	done

	echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk /dev/sda
	echo j | mkfs.ext4 -q -L arch /dev/sda2 >/dev/null
	mount /dev/sda2 /mnt

	total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
	fallocate -l ${total_memory}M /mnt/swapfile
	chmod 600 /mnt/swapfile
	mkswap /mnt/swapfile >/dev/null
	swapon /mnt/swapfile >/dev/null

	pause
	clear
	pacman-key --init
	pacman-key --populate archlinux
	pacman-key --refresh-keys

	pacstrap /mnt base base-devel
	echo -e "KEYMAP=${KEYMAP}" > /mnt/etc/vconsole.conf

	pause
	clear

	pacstrap /mnt grub
	arch_chroot "grub-install --target=i386-pc --recheck /dev/sda"
	arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

	genfstab -U -p /mnt > /mnt/etc/fstab
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab

	echo "testi" > /mnt/etc/hostname

	echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen
	arch_chroot "locale-gen" >/dev/null

	arch_chroot "ln -s /usr/share/zoneinfo/Europe/Zurich /etc/localtime"

	arch_chroot "hwclock --systohc --utc"
	
	arch_chroot "passwd root" < /tmp/.passwd >/dev/null
	pause
	clear

	arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp -s /bin/bash"
	arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null
	arch_chroot "cp /etc/skel/.bashrc /home/${USER}"
	arch_chroot "chown -R ${USER}:users /home/${USER}"
	[[ -e /mnt/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers

	pause
	clear

	arch_chroot "mkinitcpio -p linux"

	pause
	clear
	pacstrap /mnt xorg-server xorg-server-utils xorg-xinit xf86-input-keyboard xf86-input-mouse xf86-input-synaptics
	user_list=$(ls /mnt/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$i/.xinitrc
		arch_chroot "chown -R ${i}:users /home/${i}"
	done

	pacstrap /mnt xf86-video-intel libva-intel-driver intel-ucode
    sed -i 's/MODULES=""/MODULES="i915"/' /mnt/etc/mkinitcpio.conf

    if [[ -e /mnt/boot/grub/grub.cfg ]]; then
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
	fi

	pause
	clear
	pacstrap /mnt cinnamon bash-completion gamin gksu gnome-icon-theme gnome-keyring gvfs gvfs-afc gvfs-smb polkit poppler python2-xdg ntfs-3g ttf-dejavu xdg-user-dirs xdg-utils xterm

	pause
	clear
	pacstrap /mnt lightdm lightdm-gtk-greeter
	arch_chroot "systemctl enable lightdm"

    echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"ch"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf

	[[ $(lspci | grep -i "Network Controller") == "" ]] && pacstrap /mnt dialog iw rp-pppoe wireless_tools wpa_actiond

	pacstrap /mnt cups ghostscript gsfonts
	arch_chroot "systemctl enable org.cups.cupsd.service"

	pause
	clear
	pacstrap /mnt networkmanager network-manager-applet
	arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service"

	pacstrap /mnt alsa-utils alsa-plugins

	MOUNTED=""
	MOUNTED=$(mount | grep "/mnt" | awk '{print $3}' | sort -r)
	swapoff -a
	for i in ${MOUNTED[@]}; do
	  umount $i >/dev/null
	done
	reboot
