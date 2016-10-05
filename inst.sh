#!/bin/bash
op_title=" -| Arch Linux |- "
log="error.log"
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}  
pac_strap() {
    pacstrap /mnt ${1} --needed 2>> $log
}  
load() {
	{	int="1"
        	while ps | grep "$pid" &> /dev/null
    	    	do
    	            sleep $pri
    	            echo $int
    	        	if [ "$int" -lt "100" ]; then
    	        		int=$((int+1))
    	        	fi
    	        done
            echo 100
            sleep 1
	} | dialog --gauge "$msg" 9 79 0
}
_umount() {
	MOUNTED=""
	MOUNTED=$(mount | grep "/mnt" | awk '{print $3}' | sort -r)
	swapoff -a
	for i in ${MOUNTED[@]}; do
		umount $i >/dev/null
	done
}
init() {
	title=" -| Systemprüfung |- "
	#root
	if [[ `whoami` != "root" ]]; then
		dialog --backtitle "$op_title" --title "$title" --msgbox "\ndu bist nicht 'root'\nScript wird beendet" 0 0
		exit 1
	fi
	if [[ ! $(ping -c 1 google.com) ]]; then
		dialog --backtitle "$op_title" --title "$title" --msgbox "\nkein Internet Zugang.\nScript wird beendet" 0 0
		exit 1
	fi
	#update
	clear
	pacman -Syy
	#mac
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true  # if MAC
    else
		modprobe -q efivarfs
    fi
	#efi
    if [[ -d "/sys/firmware/efi/" ]]; then
		if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then mount -t efivarfs efivarfs /sys/firmware/efi/efivars ; fi
		SYSTEM="UEFI"
    else
		SYSTEM="BIOS"
    fi
	_keys
}
_keys() {
	op_title=" -| Tastaturlayout einstellen |- "
	keyboard=$(dialog --backtitle "$op_title" --nocancel --menu "Wählen Sie Ihr Tastatur aus:" 10 35 10 "de_CH-latin1" "Schweiz" "$other" "Auswahl" 3>&1 1>&2 2>&3)
	if [ "$keyboard" = "$other" ]; then
		key_maps=$(find /usr/share/kbd/keymaps -type f | sed -n -e 's!^.*/!!p' | grep ".map.gz" | sed 's/.map.gz//g' | sed 's/$/ -/g')
		keyboard=$(dialog --nocancel --menu "Wählen Sie Ihr Tastatur aus:" 10 35 10  $key_maps 3>&1 1>&2 2>&3)
	fi
	loadkeys $keyboard
	_rpass
}
_rpass() {
	RPASSWD1=$(dialog --backtitle "$op_title" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --backtitle "$op_title" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort bestätigen:" 0 0 "")
	if [[ $RPASSWD1 == $RPASSWD2 ]]; then 
	   echo -e "${RPASSWD1}\n${RPASSWD1}" > /tmp/.rpasswd 2>> $log
	else
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --infobox "\nDie eingegebenen Passwörter stimmen nicht überein." 0 0
		_rpass
	fi
	_nuser
}
_nuser() {
	USER=$(dialog --backtitle "$op_title" --title " -| Benutzer |- " --stdout --inputbox "Namen des Benutzers in Kleinbuchstaben." 0 0 "")
	if [[ $USER -eq 0 ]] || [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --msgbox "Ungültiger Benutzername." 0 0
		_nuser
	fi
	_puser
}
_puser () {
	PASSWD1=$(dialog --backtitle "$op_title" --title " -| Benutzer $USER |- " --stdout --clear --insecure --passwordbox "Passwort" 0 0 "")
	PASSWD2=$(dialog --backtitle "$op_title" --title " -| Benutzer $USER |- " --stdout --clear --insecure --passwordbox "Passwort bestätigen" 0 0 "")
	if [[ $PASSWD1 == $PASSWD2 ]]; then
		echo -e "${PASSWD1}\n${PASSWD1}" > /tmp/.passwd 2>> $log
	else
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --msgbox "\nDie eingegebenen Passwörter stimmen nicht überein." 0 0
		_puser
	fi
	_inst
}
_inst() {
	op_title=" -| Gebietsschema einstellen |- "
	LOCALE=$(dialog --backtitle "$op_title" --nocancel --menu "Wählen Sie Ihr Gebietsschema aus:" 10 35 11 "de_CH.UTF-8" "Schweiz" "$other""Auswahl" 3>&1 1>&2 2>&3)
	if [ "$LOCALE" = "$other" ]; then
		localelist=$(</etc/locale.gen  grep -F ".UTF-8" | awk '{print $1" ""-"}' | sed 's/#//')
		LOCALE=$(dialog --nocancel --menu "Wählen Sie Ihr Gebietsschema aus:" 18 35 11 $localelist 3>&1 1>&2 2>&3)
	fi
	op_title=" -| Tastaturlayout einstellen |- "
	keyde=$(dialog --backtitle "$op_title" --nocancel --menu "Wählen Sie Ihr Tastatur aus:" 10 35 10 "ch" "Schweiz" "$other" "Auswahl" 3>&1 1>&2 2>&3)
	if [ "$keyde" = "$other" ]; then
		keymaps_xkb=("af al am at az ba bd be bg br bt bw by ca cd ch cm cn cz de dk ee es et eu fi fo fr gb ge gh gn gr hr hu ie il in iq ir is it jp ke kg kh kr kz la lk lt lv ma md me mk ml mm mn mt mv ng nl no np pc ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr tw tz ua us uz vn za")
		keyde=$(dialog --nocancel --menu "Wählen Sie Ihr Tastatur aus:" 10 35 10  $keymaps_xkb 3>&1 1>&2 2>&3)
	fi
	op_title=" -| Spiegelserver aktualisieren |- "
	code=$(dialog --backtitle "$op_title" --nocancel --menu "Wählen Sie Ihren Ländercode:" 10 35 10 "CH" "Schweiz" "$other" "Auswahl" 3>&1 1>&2 2>&3)
	if [ "$code" = "$other" ]; then
		countries=$(echo -e "AT Austria\n AU  Australia\n BE Belgium\n BG Bulgaria\n BR Brazil\n BY Belarus\n CA Canada\n CL Chile \n CN China\n CO Columbia\n CZ Czech-Republic\n DE Germany\n DK Denmark\n EE Estonia\n ES Spain\n FI Finland\n FR France\n GB United-Kingdom\n HU Hungary\n IE Ireland\n IL Isreal\n IN India\n IT Italy\n JP Japan\n KR Korea\n KZ Kazakhstan\n LK Sri-Lanka\n LU Luxembourg\n LV Lativia\n MK Macedonia\n NC New-Caledonia\n NL Netherlands\n NO Norway\n NZ New-Zealand\n PL Poland\n PT Portugal\n RO Romania\n RS Serbia\n RU Russia\n SE Sweden\n SG Singapore\n SK Slovakia\n TR Turkey\n TW Taiwan\n UA Ukraine\n US United-States\n UZ Uzbekistan\n VN Viet-Nam\n ZA South-Africa")
		code=$(dialog --nocancel --backtitle "$op_title" --menu "Wählen Sie Ihren Ländercode:" 17 35 10 $countries 3>&1 1>&2 2>&3)
	fi
	op_title=" -| Zeitzone einstellen |- "
	ZONE=$(dialog --backtitle "$op_title" --title "Auswahl" --nocancel --menu "Wählen Sie Ihre Zeitzone aus:" 10 36 11  "Europe/Zurich" "Schweiz" "$other" "Auswahl" 3>&1 1>&2 2>&3)
	if [ "$ZONE" = "$other" ]; then
		ZONE=""
		for i in $(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "/" | sed "s/\/.*//g" | sort -ud); do
			ZONE="$ZONE ${i} -"
		done
		ZONE=$(dialog --nocancel --backtitle "$op_title"  --title "Auswahl" --nocancel --menu "Wählen Sie Ihre Zeitzone aus:" 0 0 10 ${ZONE} 3>&1 1>&2 2>&3)
		SUBZONE=""
		for i in $(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "${ZONE}/" | sed "s/${ZONE}\///g" | sort -ud); do
			SUBZONE="$SUBZONE ${i} -"
		done
		SUBZONE=$(dialog --nocancel --backtitle "$op_title"  --title "Auswahl" --nocancel --menu "Wählen Sie den Ort aus:" 0 0 11 ${SUBZONE} 3>&1 1>&2 2>&3)
		ZONE=${ZONE}/${SUBZONE}
	fi
	op_title=" -| Sprache einstellen |- "
	SPRA=$(dialog --backtitle "$op_title" --nocancel --menu "Wählen Sie Ihre Applikations Sprache aus:" 10 35 10 "de" "Deutsch" "$other" "Auswahl" 3>&1 1>&2 2>&3)
	if [ "$SPRA" = "$other" ]; then
		SPRA=$(dialog --nocancel --backtitle "$op_title" --title " -| Sprache |- " --stdout --inputbox "Sprache de Applikationen z.b. en für Englisch" 0 0 "")
	fi
	HOSTN=$(dialog --backtitle "$op_title" --title " -| Hostname |- " --stdout --inputbox "Identifizierung im Netzwerk" 0 0 "")
	dialog --backtitle "$op_title" --title " -| Wipen |- " --yesno "WARNUNG: Alle Daten unwiederuflich auf /dev/${IDEV} entfernen\nsauber aber dauert etwas" 0 0
	if [[ $? -eq 0 ]]; then WIPE="YES" ; fi
	dialog --backtitle "$op_title" --title " -| MediaElch installieren |- " --yesno "Installieren.\nwird Kompiliert und dauert etwa 10min" 0 0
	if [[ $? -eq 0 ]]; then MPC="YES" ; fi
	DEVHD=""
	devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);   
	for i in ${devices_list[@]}; do
		DEVHD="${DEVHD} ${i}"
	done 
	IDEV=$(dialog --nocancel --backtitle "$op_title" --title " -| Laufwerk |- " --menu "Welche HDD wird verwendet" 10 40 10 ${DEVHD} 3>&1 1>&2 2>&3)
	IDEV=`echo $IDEV | cut -c6-`
	HD_SD="HDD"
	if cat /sys/block/$IDEV/queue/rotational | grep 0; then HD_SD="SSD" ; fi
	op_title=" -| Arch Linux - ($(uname -m)) $SYSTEM $HD_SD |- "
	_mirrors
}
_mirrors() {
	if ! (</etc/pacman.d/mirrorlist2 grep "rankmirrors" &>/dev/null) then
		(wget --no-check-certificate --append-output=/dev/null "https://www.archlinux.org/mirrorlist/?country=$code&protocol=http" -O /etc/pacman.d/mirrorlist.bak
		echo "$?" > /tmp/ex_status.var ; sleep 0.5) &> /dev/null & pid=$! pri=0.1 msg="Eine neue Spiegelserver-Liste wird abgerufen..." load
		sed -i 's/#//' /etc/pacman.d/mirrorlist.bak
		rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist & pid=$! pri=0.8 msg="Bitte warten. Spiegelserver werden nach Schnelligkeit sortiert..." load
		chmod +r /etc/pacman.d/mirrorlist
		pacman-key --init
		pacman-key --populate archlinux >/dev/null
		pacman-key --refresh-keys  2>> $log & pid=$! pri=0.8 msg="Spiegelserver-Schlüssel werden geupdatet..." load
		pacman -Syy
	fi
	_part
}
_part() {
	_umount
	if [[ $WIPE == "YES" ]]; then
		clear
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm --needed wipe
		fi	
		dialog --backtitle "$btitle" --title " -| Wipen |- " --infobox "\n...Bitte warten..." 0 0
		wipe -Ifre /dev/${IDEV}
    fi
    if [[ $SYSTEM == "BIOS" ]]; then
		sgdisk --zap-all /dev/${IDEV}
		echo -e "o\ny\nn\n1\n\n+1M\nEF02\nn\n2\n\n\n\nw\ny" | gdisk /dev/${IDEV} 2>> $log
		dialog --backtitle "$btitle" --title " -| Bereite BIOS Festplatte vor |- " --infobox "\n...Bitte warten..." 0 0
		echo j | mkfs.ext4 -L arch /dev/${IDEV}2 >/dev/null 2>> $log
		mount /dev/${IDEV}2 /mnt
	fi
	if [[ $SYSTEM == "UEFI" ]]; then
		sgdisk --zap-all /dev/${IDEV}
		echo -e "n\n\n\n512M\nef00\nn\n\n\n\n\nw\ny" | gdisk /dev/${IDEV} 2>> $log
		dialog --backtitle "$btitle" --title " -| Bereite UEFI Festplatte vor |- " --infobox "\n...Bitte warten..." 0 0
		echo j | mkfs.vfat -F32 -L boot /dev/${IDEV}1 >/dev/null 2>> $log
		echo j | mkfs.ext4 -L arch /dev/${IDEV}2 >/dev/null 2>> $log
		mount /dev/${IDEV}2 /mnt
		mkdir -p /mnt/boot
		mount /dev/${IDEV}1 /mnt/boot
	fi		
	if [[ $HD_SD == "HDD" ]]; then
		dialog --backtitle "$btitle" --title " -| erstelle SWAP Datei |- " --infobox "\n...Bitte warten..." 0 0
		total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
		fallocate -l ${total_memory}M /mnt/swapfile
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile -L swap >/dev/null
		swapon /mnt/swapfile >/dev/null
	fi
	_base
}
_base() {
	pac_strap "base base-devel"
	if [[ $SYSTEM == "BIOS" ]]; then		
		pac_strap "grub dosfstools"
		dialog --backtitle "$btitle" --title " -| Grub-install |- " --infobox "\nBitte warten..." 0 0
		arch_chroot "grub-install --target=i386-pc --recheck /dev/$IDEV"
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		pac_strap "grub efibootmgr dosfstools"
		dialog --backtitle "$btitle" --title " -| UEFI-Grub-install |- " --infobox "\nBitte warten..." 0 0
		arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck"
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
	fi
	sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>> $log
	sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>> $log
	arch_chroot "grep -q 'timeout=0' /boot/grub/grub.cfg || grub-mkconfig"
	echo "KEYMAP=${ILANG}" > /mnt/etc/vconsole.conf 2>> $log
	cp -f /etc/pacman.conf /mnt/etc/pacman.conf
	if [ $(uname -m) == x86_64 ]; then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf 2>> $log
	fi
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then
		echo -e "\n[archlinuxfr]\nServer = http://repo.archlinux.fr/$(uname -m)\nSigLevel = Never" >> /mnt/etc/pacman.conf 2>> $log
	fi
	arch_chroot "pacman -Syy"
	_sets
}
_sets() { #Einstellungen
	#genf
	genfstab -U -p /mnt >> /mnt/etc/fstab 2>> $log
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab 2>> $log
	#hostname
	echo ${HOSTN} > /mnt/etc/hostname 2>> $log
	sed -i "/127.0.0.1/s/$/ ${HOSTN}/" /mnt/etc/host 2>> $log
	sed -i "/::1/s/$/ ${HOSTN}/" /mnt/etc/hosts 2>> $log
	#loc
	echo "${LOCALE} UTF-8" /mnt/etc/locale.gen 2>> $log
	arch_chroot "locale-gen"
	echo "LANG=${LOCALE}" > /mnt/etc/locale.conf 2>> $log
	export "LANG=${LOCALE}" 2>> $log
	arch_chroot "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
	arch_chroot "hwclock --systohc --utc"
	#rpw
	arch_chroot "passwd root" < /tmp/.rpasswd
	rm /tmp/.rpasswd
	#user
	arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp -s /bin/bash"
	arch_chroot "passwd ${USER}" < /tmp/.passwd
	rm /tmp/.passwd
	arch_chroot "cp /etc/skel/.bashrc /home/${USER}" 2>> $log
	arch_chroot "chown -R ${USER}:users /home/${USER}" 2>> $log
	[[ -e /mnt/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers 2>> $log
	#mkinit
	clear
	KERNEL=""
	KERNEL=$(ls /mnt/boot/*.img | grep -v "fallback" | sed "s~/mnt/boot/initramfs-~~g" | sed s/\.img//g | uniq)
	for i in ${KERNEL}; do
		arch_chroot "mkinitcpio -p ${i}"
	done
	_xorg
}
_xorg() { #XORG
	pac_strap "xorg-server xorg-server-utils xorg-xinit"
	pac_strap "xf86-input-synaptics xf86-input-mouse xf86-input-keyboard xf86-input-libinput"
	user_list=$(ls /mnt/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f /mnt/etc/X11/xinit/xinitrc /mnt/home/$i/.xinitrc
		arch_chroot "chown -R ${i}:users /home/${i}"
	done	
	_graphics_card
}
_graphics_card() {
	install_intel(){
		pacstrap /mnt xf86-video-intel libva-intel-driver intel-ucode
		sed -i 's/MODULES=""/MODULES="i915"/' /mnt/etc/mkinitcpio.conf 2>> $log
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
	install_ati(){
		pacstrap /mnt xf86-video-ati
		sed -i 's/MODULES=""/MODULES="radeon"/' /mnt/etc/mkinitcpio.conf 2>> $log
	}
	NVIDIA=""
	VB_MOD=""
	GRAPHIC_CARD=""
	INTEGRATED_GC="N/A"
	GRAPHIC_CARD=$(lspci | grep -i "vga" | sed 's/.*://' | sed 's/(.*//' | sed 's/^[ \t]*//')

	if 	[[ $(echo $GRAPHIC_CARD | grep -i "nvidia") != "" ]]; then
		[[ $(lscpu | grep -i "intel\|lenovo") != "" ]] && INTEGRATED_GC="Intel" || INTEGRATED_GC="ATI"
		if [[ $(dmesg | grep -i 'chipset' | grep -i 'nvc\|nvd\|nve') != "" ]]; then HIGHLIGHT_SUB_GC=4
			elif [[ $(dmesg | grep -i 'chipset' | grep -i 'nva\|nv5\|nv8\|nv9'﻿) != "" ]]; then HIGHLIGHT_SUB_GC=5
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
		install_ati
	fi
	if [[ $HIGHLIGHT_SUB_GC == 2 ]] ; then
		install_intel
	fi
	if [[ $HIGHLIGHT_SUB_GC == 3 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		pacstrap /mnt xf86-video-nouveau
		sed -i 's/MODULES=""/MODULES="nouveau"/' /mnt/etc/mkinitcpio.conf 2>> $log
	fi
	if [[ $HIGHLIGHT_SUB_GC == 4 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
		pacstrap /mnt ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 5 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
		arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
		([[ -e /mnt/boot/initramfs-linux.img ]] || [[ -e /mnt/boot/initramfs-linux-grsec.img ]] || [[ -e /mnt/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
		[[ -e /mnt/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
		pacstrap /mnt ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings 
		NVIDIA_INST=1
	fi
	if [[ $HIGHLIGHT_SUB_GC == 6 ]] ; then
		[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
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
		echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf 2>> $log
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
	_desktopde
}
_desktopde() {
	pac_strap "cinnamon gnome-terminal nemo-fileroller nemo-preview"
	pac_strap "bash-completion gamin gksu python2-xdg ntfs-3g xdg-user-dirs xdg-utils"

	pac_strap "lightdm lightdm-gtk-greeter"
    arch_chroot "systemctl enable lightdm"

	sed -i "s/#autologin-user=/autologin-user=${USER}/" /mnt/etc/lightdm/lightdm.conf 2>> $log
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf 2>> $log
	arch_chroot "groupadd -r autologin"
	arch_chroot "gpasswd -a ${USER} autologin"

	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"$keyde"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf 2>> $log
	_hardware
}
_hardware() {
	#Wireless
	WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRELESS_DEV ]]; then pac_strap "iw wireless_tools wpa_actiond dialog rp-pppoe" ; fi
	#Netzwerkkarte
	WIRED_DEV=`ip link | grep "ens\|eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRED_DEV ]]; then arch_chroot "systemctl enable dhcpcd@${WIRED_DEV}.service" ; fi
	#Drucker
	pac_strap "cups system-config-printer hplip splix cups-pdf"
	arch_chroot "systemctl enable org.cups.cupsd.service"
	#bluetooth
	if (dmesg | grep -i "blue" &> /dev/null); then 
		pac_strap "bluez bluez-utils blueman"
		arch_chroot "systemctl enable bluetooth.service"
	fi
	#Disable logs
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/journald.conf 2>> $log
	sed -i "s/SystemMaxUse.*/#&/g" /mnt/etc/systemd/journald.conf 2>> $log
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/coredump.conf 2>> $log
	echo "kernel.dmesg_restrict = 1" > /mnt/etc/sysctl.d/50-dmesg-restrict.conf 2>> $log
	_jdownloader
}
_jdownloader() {
	pac_strap "jre7-openjdk"
	mkdir -p /mnt/opt/JDownloader/
	wget -c -O /mnt/opt/JDownloader/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar
	arch_chroot "chown -R 1000:1000 /opt/JDownloader/"
	arch_chroot "chmod -R 0775 /opt/JDownloader/"
	echo "[Desktop Entry]" >> /mnt/usr/share/applications/JDownloader.desktop 2>> $log
	echo "Name=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Comment=JDownloader" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Exec=java -jar /opt/JDownloader/JDownloader.jar" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Icon=/opt/JDownloader/themes/standard/org/jdownloader/images/logo/jd_logo_64_64.png" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Terminal=false" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Type=Application" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "StartupNotify=false" >> /mnt/usr/share/applications/JDownloader.desktop
	echo "Categories=Network;Application;" >> /mnt/usr/share/applications/JDownloader.desktop
	_appsinst
}
_appsinst() {
	pac_strap "libreoffice-fresh-${SPRA} firefox-i18n-${SPRA} thunderbird-i18n-${SPRA} hunspell-${SPRA} aspell-${SPRA} ttf-liberation"
	pac_strap "gimp gimp-help-${SPRA} gthumb simple-scan vlc avidemux-gtk handbrake clementine mkvtoolnix-gui picard meld unrar p7zip lzop cpio"
	pac_strap "flashplugin geany leafpad pitivi frei0r-plugins xfburn simplescreenrecorder qbittorrent mlocate pkgstats"
	pac_strap "libaacs btrfs-progs f2fs-tools tlp tlp-rdw ffmpegthumbs ffmpegthumbnailer x264 upx nss-mdns libquicktime libdvdcss cdrdao"
	pac_strap "alsa-utils fuse-exfat autofs mtpfs icoutils wine-mono playonlinux winetricks nfs-utils gparted gst-plugins-ugly gst-libav"
#	pac_strap "wine wine_gecko steam yaourt"
#	[[ $(uname -m) == x86_64 ]] && pac_strap "lib32-alsa-plugins lib32-libpulse"
	arch_chroot "upx --best /usr/lib/firefox/firefox"
	_MENU
#	_mediaelch
}
_mediaelch() {
	if [[ $MPC == "YES" ]]; then		
#		arch_chroot "yaourt -S mediaelch --noconfirm --needed"
		echo "#!/bin/sh" >> /mnt/usr/bin/elch 2>> $log
		echo "wakeonlan 00:01:2e:3a:5e:81" >> /mnt/usr/bin/elch
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
		mkdir -p /mnt/home/${USER}/.config/kvibes/
		echo "[Directories]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf 2>> $log
		echo "Concerts\size=0" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Downloads\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Downloads\1\path=/home/monty/Downloads" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Downloads\1\sepFolders=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Downloads\size=1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\1\path=/mnt/Filme1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\1\sepFolders=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\2\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\2\path=/mnt/Filme2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\2\sepFolders=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Movies\size=2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Music\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Music\1\path=/mnt/Musik" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Music\1\sepFolders=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Music\size=1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TvShows\1\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TvShows\1\path=/mnt/Serien1" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TvShows\2\autoReload=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TvShows\2\path=/mnt/Serien2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TvShows\size=2" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "[Downloads]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "DeleteArchives=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "KeepSource=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "Unrar=/bin/unrar" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "[Scrapers]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "AEBN\Language=en" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "FanartTv\DiscType=BluRay" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "FanartTv\Language=de" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "FanartTv\PersonalApiKey=" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "ShowAdult=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TMDb\Language=de" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TMDbConcerts\Language=en" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "TheTvDb\Language=de" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "UniversalMusicScraper\Language=en" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "UniversalMusicScraper\Prefer=theaudiodb" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "[TvShows]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "DvdOrder=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "ShowMissingEpisodesHint=true" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "[Warnings]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "DontShowDeleteImageConfirm=false" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "[XBMC]" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "RemoteHost=192.168.2.251" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "RemotePassword=xbmc" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "RemotePort=80" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		echo "RemoteUser=xbmc	" >> /mnt/home/${USER}/.config/kvibes/MediaElch.conf
		chmod +x /mnt/usr/bin/elch
	fi
	_yaourtinst
}
_yaourtinst() {
	[[ $(uname -m) == x86_64 ]] && arch_chroot "yaourt -S codecs64 --noconfirm --needed"
	[[ $(uname -m) == i686  ]] && arch_chroot "yaourt -S codecs --noconfirm --needed"
    arch_chroot "yaourt -S pamac-aur --noconfirm --needed"
    arch_chroot "yaourt -S teamviewer --noconfirm --needed"
	arch_chroot "systemctl enable teamviewerd"
    arch_chroot "yaourt -S wakeonlan --noconfirm --needed"
    arch_chroot "yaourt -S mp3gain --noconfirm --needed"
    arch_chroot "yaourt -S mintstick-git --noconfirm --needed"
    arch_chroot "yaourt -S mp3diags-unstable --noconfirm --needed"
    arch_chroot "yaourt -S skype --noconfirm --needed"
	_MENU
}
_MENU() {
	_umount
	nano $log
#	dialog --backtitle "$btitle" --title " -| Installation Fertig |- " --msgbox "Install Medium entfernen" 0 0
	reboot
	exit 0
}

opt="$1"
init
