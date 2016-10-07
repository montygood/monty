# !/bin/bash
######################################################################
##                   Installer Variables							##
######################################################################

VERSION="Arch Installation"

ANSWER="/tmp/.aif"
PACKAGES="/tmp/.pkgs"
MOUNT_OPTS="/tmp/.mnt_opts"

DM_INST=""							# Which DMs have been installed?
DM_ENABLED=0						# Has a display manager been enabled?
NM_INST=""							# Which NMs have been installed?
NM_ENABLED=0						# Has a network connection manager been enabled?
KERNEL="n"                			# Kernel(s) installed (base install); kernels for mkinitcpio
GRAPHIC_CARD=""						# graphics card
INTEGRATED_GC=""					# Integrated graphics card for NVIDIA
NVIDIA_INST=0         				# Indicates if NVIDIA proprietary driver has been installed
NVIDIA=""							# NVIDIA driver(s) to install depending on kernel(s)
VB_MOD=""							# headers packages to install depending on kernel(s)
SHOW_ONCE=0           				# Show de_wm information only once
COPY_PACCONF=0						# Copy over installer /etc/pacman.conf to installed system?

MOUNTPOINT="/mnt"       			# Installation: Root mount
MOUNT=""							# Installation: All other mounts branching from Root
FS_OPTS=""							# File system special mount options available
CHK_NUM=16							# Used for FS mount options checklist length
INCLUDE_PART='part\|lvm\|crypt'		# Partition types to include for display and selection.
ROOT_PART=""          				# ROOT partition
UEFI_PART=""						# UEFI partition
UEFI_MOUNT=""         				# UEFI mountpoint (/boot or /boot/efi)

HIGHLIGHT=0           				# Highlight items for Main Menu
HIGHLIGHT_SUB=0	    				# Highlight items for submenus
SUB_MENU=""           				# Submenu to be highlighted
# Logical Volume Management
LVM=0                   			# Logical Volume Management Detected?
LVM_SEP_BOOT=0          			# 1 = Seperate /boot, 2 = seperate /boot & LVM
LVM_VG=""               			# Name of volume group to create or use
LVM_VG_MB=0             			# MB remaining of VG
LVM_LV_NAME=""          			# Name of LV to create or use
LV_SIZE_INVALID=0       			# Is LVM LV size entered valid?
VG_SIZE_TYPE=""         			# Is VG in Gigabytes or Megabytes?

# LUKS
LUKS=0                  			# Luks Used?
LUKS_DEV=""							# If encrypted, partition
LUKS_NAME=""						# Name given to encrypted partition
LUKS_UUID=""						# UUID used for comparison purposes
LUKS_OPT=""							# Default or user-defined?

ARCHI=$(uname -m)
SYSTEM="Unknown"
CURR_LOCALE="de_CH.UTF-8" 
FONT=""
KEYMAP="de_CH-latin1"
XKBMAP="ch"
ZONE="Europe"
SUBZONE="Zurich"
LOCALE="de_CH.UTF-8"
code="CH"
source monty-master/english.trans
######################################################################
##                        Core Functions							##
######################################################################
select_language() {
    sed -i "s/#${CURR_LOCALE}/${CURR_LOCALE}/" /etc/locale.gen
    locale-gen >/dev/null 2>&1
    export LANG=${CURR_LOCALE}
    [[ $FONT != "" ]] && setfont $FONT
}
check_requirements() {
	title=" -| Systemprüfung |- "
	if [[ `whoami` != "root" ]]; then
		dialog --backtitle "$op_title" --title "$title" --msgbox "\ndu bist nicht 'root'\nScript wird beendet" 0 0
		exit 1
	fi
	if [[ ! $(ping -c 1 google.com) ]]; then
		dialog --backtitle "$op_title" --title "$title" --msgbox "\nkein Internet Zugang.\nScript wird beendet" 0 0
		exit 1
	fi
	clear
	echo "" > /tmp/.errlog
	pacman -Syy
}
id_system() {
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true  # if MAC
    else
		modprobe -q efivarfs
    fi
    if [[ -d "/sys/firmware/efi/" ]]; then
		if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then mount -t efivarfs efivarfs /sys/firmware/efi/efivars ; fi
		SYSTEM="UEFI"
    else
		SYSTEM="BIOS"
    fi
}   
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}  
pac_strap() {
    pacstrap /mnt ${1} --needed 2>> /tmp/.errlog
    check_for_error
}  
check_for_error() {
 if [[ $? -eq 1 ]] && [[ $(cat /tmp/.errlog | grep -i "error") != "" ]]; then
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " Fehleranzeige " --msgbox "$(cat /tmp/.errlog)" 0 0
    echo "" > /tmp/.errlog
    main_menu_online
 fi
}
check_mount() {
    if [[ $(lsblk -o /mnt | grep /mnt) == "" ]]; then
       dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " Fehler " --msgbox "Mountpunkt nicht vorhanden" 0 0
       main_menu_online
    fi
}
check_base() {
    if [[ ! -e /mnt/etc ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " Fehler " --msgbox "Base nicht installiert" 0 0
        main_menu_online
    fi
}
show_devices() {
     lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE,MOUNTPOINT | grep "disk\|part\|lvm\|crypt\|NAME\|MODEL\|TYPE\|FSTYPE\|SIZE\|MOUNTPOINT" > /tmp/.devlist
     dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " D " --textbox /tmp/.devlist 0 0
}

######################################################################
##                 Configuration Functions							##
######################################################################
configure_mirrorlist() {
	URL="https://www.archlinux.org/mirrorlist/?country=${code}&use_mirror_status=on"
	MIRROR_TEMP=$(mktemp --suffix=-mirrorlist)
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "  Mirrorlist  " --infobox "\n...Bitte warten..." 0 0
	curl -so ${MIRROR_TEMP} ${URL} 2>/tmp/.errlog
	check_for_error
	sed -i 's/^#Server/Server/g' ${MIRROR_TEMP}
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "  Mirrorlist  " --infobox "$_MirrorRankBody \n...Bitte warten..." 0 0
	cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist 2>/tmp/.errlog
	check_for_error
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "  Mirrorlist  " --infobox "\n$_Done!\n\n" 0 0
	sleep 2
	mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
	mv -f ${MIRROR_TEMP} /etc/pacman.d/mirrorlist
	chmod +r /etc/pacman.d/mirrorlist
}
set_keymap() { 
	loadkeys $KEYMAP 2>/tmp/.errlog
    check_for_error
}
set_xkbmap() {
    echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
}
set_locale() {
  echo "LANG=\"${LOCALE}\"" > /mnt/etc/locale.conf
  sed -i "s/#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen 2>/tmp/.errlog
  arch_chroot "locale-gen" >/dev/null 2>>/tmp/.errlog
  check_for_error
}
set_timezone() {
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime" 2>/tmp/.errlog
	check_for_error
}
set_hw_clock() {
	arch_chroot "hwclock --systohc --utc" 2>/tmp/.errlog
	check_for_error
}
generate_fstab() {
	genfstab -U -p /mnt >> /mnt/etc/fstab 2>/tmp/.errlog
	check_for_error
	[[ -f /mnt/swapfile ]] && sed -i "s/\\/mnt//" /mnt/etc/fstab
}
set_hostname() {
   hostname=$(dialog --backtitle "$op_title" --title " -| Hostname |- " --stdout --inputbox "Identifizierung im Netzwerk" 0 0 "")
   echo "${hostname}" > /mnt/etc/hostname 2>/tmp/.errlog
   echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${hostname}\n::1\tlocalhost.localdomain\tlocalhost\t${hostname}" > /mnt/etc/hosts 2>>/tmp/.errlog
   check_for_error
}
set_root_password() {
	RPASSWD=$(dialog --backtitle "$op_title" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --backtitle "$op_title" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort bestätigen:" 0 0 "")
	if [[ $RPASSWD == $RPASSWD2 ]]; then 
		echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
	else
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --infobox "\nDie eingegebenen Passwörter stimmen nicht überein." 0 0
		set_root_password
	fi

       arch_chroot "passwd root" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
       rm /tmp/.passwd
       check_for_error
}
create_new_user() {
	USER=$(dialog --backtitle "$op_title" --title " -| Benutzer |- " --stdout --inputbox "Namen des Benutzers in Kleinbuchstaben." 0 0 "")
	if [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$op_title" --title " -| FEHLER |- " --msgbox "Ungültiger Benutzername." 0 0
		create_new_user
	fi
    
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrNew " --infobox "$_NUsrSetBody" 0 0
        sleep 2
        arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp -s /bin/bash" 2>/tmp/.errlog
        check_for_error
        echo -e "${PASSWD}\n${PASSWD}" > /tmp/.passwd
        arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
        rm /tmp/.passwd
        check_for_error
        arch_chroot "cp /etc/skel/.bashrc /home/${USER}"
        arch_chroot "chown -R ${USER}:users /home/${USER}"
        [[ -e /mnt/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
}
run_mkinitcpio() {
	clear
	KERNEL=""
	([[ $LVM -eq 1 ]] && [[ $LUKS -eq 0 ]]) && sed -i 's/block filesystems/block lvm2 filesystems/g' /mnt/etc/mkinitcpio.conf 2>/tmp/.errlog
    ([[ $LVM -eq 1 ]] && [[ $LUKS -eq 1 ]]) && sed -i 's/block filesystems/block encrypt lvm2 filesystems/g' /mnt/etc/mkinitcpio.conf 2>/tmp/.errlog
    ([[ $LVM -eq 0 ]] && [[ $LUKS -eq 1 ]]) && sed -i 's/block filesystems/block encrypt filesystems/g' /mnt/etc/mkinitcpio.conf 2>/tmp/.errlog
    check_for_error
	KERNEL=$(ls /mnt/boot/*.img | grep -v "fallback" | sed "s~/mnt/boot/initramfs-~~g" | sed s/\.img//g | uniq)
	for i in ${KERNEL}; do
		arch_chroot "mkinitcpio -p ${i}" 2>>/tmp/.errlog
	done
	check_for_error
}

######################################################################
##            System and Partitioning Functions						##
######################################################################
umount_partitions(){
	MOUNTED=""
	MOUNTED=$(mount | grep "/mnt" | awk '{print $3}' | sort -r)
	swapoff -a
	for i in ${MOUNTED[@]}; do
		umount $i >/dev/null 2>>/tmp/.errlog
	done
	check_for_error
}
confirm_mount() {
    if [[ $(mount | grep $1) ]]; then   
      dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MntStatusTitle " --infobox "$_MntStatusSucc" 0 0
      sleep 2
      PARTITIONS=$(echo $PARTITIONS | sed "s~${PARTITION} [0-9]*[G-M]~~" | sed "s~${PARTITION} [0-9]*\.[0-9]*[G-M]~~" | sed s~${PARTITION}$' -'~~)
      NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS - 1 ))
    else
      dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MntStatusTitle " --infobox "$_MntStatusFail" 0 0
      sleep 2
      prep_menu
    fi
}
select_device() {
    DEVICE=""
    devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
    for i in ${devices_list[@]}; do
        DEVICE="${DEVICE} ${i}"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_DevSelTitle " --menu "$_DevSelBody" 0 0 4 ${DEVICE} 2>${ANSWER} || prep_menu
    DEVICE=$(cat ${ANSWER})
}
find_partitions() {
	PARTITIONS=""
	NUMBER_PARTITIONS=0	
	partition_list=$(lsblk -lno NAME,SIZE,TYPE | grep $INCLUDE_PART | sed 's/part$/\/dev\//g' | sed 's/lvm$\|crypt$/\/dev\/mapper\//g' | awk '{print $3$1 " " $2}' | sort -u)
    for i in ${partition_list}; do
        PARTITIONS="${PARTITIONS} ${i}"
        NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS + 1 ))
    done
    NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS / 2 ))
	case $INCLUDE_PART in
	'part\|lvm\|crypt') # Deal with incorrect partitioning for main mounting function
		if ([[ $SYSTEM == "UEFI" ]] && [[ $NUMBER_PARTITIONS -lt 2 ]]) || ([[ $SYSTEM == "BIOS" ]] && [[ $NUMBER_PARTITIONS -eq 0 ]]); then
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_PartErrBody" 0 0
			create_partitions
		fi
		;;
	'part\|crypt') # Ensure there is at least one partition for LVM 
		if [[ $NUMBER_PARTITIONS -eq 0 ]]; then
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LvmPartErrBody" 0 0
			create_partitions
		fi
		;;
	'part\|lvm') # Ensure there are at least two partitions for LUKS
		if [[ $NUMBER_PARTITIONS -lt 2 ]]; then
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LuksPartErrBody" 0 0
			create_partitions
		fi
		;;
	esac
}
create_partitions(){

secure_wipe(){
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PartOptWipe " --yesno "$_AutoPartWipeBody1 ${DEVICE} $_AutoPartWipeBody2" 0 0
	if [[ $? -eq 0 ]]; then
		clear
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm wipe 2>/tmp/.errlog
			check_for_error
		fi
		clear
		wipe -Ifre ${DEVICE}
		check_for_error
    else
		create_partitions
    fi
}

auto_partition(){
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepPartDisk " --yesno "$_AutoPartBody1 $DEVICE $_AutoPartBody2 $_AutoPartBody3" 0 0
	if [[ $? -eq 0 ]]; then
		parted -s ${DEVICE} print | awk '/^ / {print $1}' > /tmp/.del_parts
		for del_part in $(tac /tmp/.del_parts); do
			parted -s ${DEVICE} rm ${del_part} 2>/tmp/.errlog
			check_for_error
		done
		part_table=$(parted -s ${DEVICE} print | grep -i 'partition table' | awk '{print $3}' >/dev/null 2>&1)
		([[ $SYSTEM == "BIOS" ]] && [[ $part_table != "msdos" ]]) && parted -s ${DEVICE} mklabel msdos 2>/tmp/.errlog
		([[ $SYSTEM == "UEFI" ]] && [[ $part_table != "gpt" ]]) && parted -s ${DEVICE} mklabel gpt 2>/tmp/.errlog
		check_for_error
		if [[ $SYSTEM == "BIOS" ]]; then
			parted -s ${DEVICE} mkpart primary ext3 1MiB 513MiB 2>/tmp/.errlog
		else
			parted -s ${DEVICE} mkpart ESP fat32 1MiB 513MiB 2>/tmp/.errlog
		fi
		parted -s ${DEVICE} set 1 boot on 2>>/tmp/.errlog
		parted -s ${DEVICE} mkpart primary ext3 513MiB 100% 2>>/tmp/.errlog
		check_for_error
        lsblk ${DEVICE} -o NAME,TYPE,FSTYPE,SIZE > /tmp/.devlist
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "" --textbox /tmp/.devlist 0 0
    else
        create_partitions
    fi
}

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepPartDisk " --menu "$_PartToolBody" 0 0 7 \
    "$_PartOptWipe" "BIOS & UEFI" \
    "$_PartOptAuto" "BIOS & UEFI" \
	"cfdisk" "BIOS" \
	"cgdisk" "UEFI" \
	"fdisk"  "BIOS & UEFI" \
	"gdisk"  "UEFI" \
	"parted" "BIOS & UEFI" 2>${ANSWER}
	clear
	if [[ $(cat ${ANSWER}) != "" ]]; then
		if ([[ $(cat ${ANSWER}) != "$_PartOptWipe" ]] &&  [[ $(cat ${ANSWER}) != "$_PartOptAuto" ]]); then
			$(cat ${ANSWER}) ${DEVICE}
		else
			[[ $(cat ${ANSWER}) == "$_PartOptWipe" ]] && secure_wipe && create_partitions
			[[ $(cat ${ANSWER}) == "$_PartOptAuto" ]] && auto_partition
		fi
	fi
	prep_menu
}	
select_filesystem(){
	fs_opts=""
	CHK_NUM=0
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_FSTitle " --menu "$_FSBody" 0 0 12 \
	"$_FSSkip" "-" \
	"btrfs" "mkfs.btrfs -f" \
	"ext2" "mkfs.ext2 -q" \
	"ext3" "mkfs.ext3 -q" \
	"ext4" "mkfs.ext4 -q" \
	"f2fs" "mkfs.f2fs" \
	"jfs" "mkfs.jfs -q" \
	"nilfs2" "mkfs.nilfs2 -q" \
	"ntfs" "mkfs.ntfs -q" \
	"reiserfs" "mkfs.reiserfs -q" \
	"vfat" "mkfs.vfat -F32" \
	"xfs" "mkfs.xfs -f" 2>${ANSWER}	
	case $(cat ${ANSWER}) in
		"$_FSSkip")	FILESYSTEM="$_FSSkip" ;;
		"btrfs") 	FILESYSTEM="mkfs.btrfs -f"	
					CHK_NUM=16
					fs_opts="autodefrag compress=zlib compress=lzo compress=no compress-force=zlib compress-force=lzo discard noacl noatime nodatasum nospace_cache recovery skip_balance space_cache ssd ssd_spread"
					modprobe btrfs
					;;
		"ext2") 	FILESYSTEM="mkfs.ext2 -q" ;;
		"ext3") 	FILESYSTEM="mkfs.ext3 -q" ;;
		"ext4") 	FILESYSTEM="mkfs.ext4 -q"
					CHK_NUM=8
					fs_opts="data=journal data=writeback dealloc discard noacl noatime nobarrier nodelalloc"
					;;
		"f2fs") 	FILESYSTEM="mkfs.f2fs"
					fs_opts="data_flush disable_roll_forward disable_ext_identify discard fastboot flush_merge inline_xattr inline_data inline_dentry no_heap noacl nobarrier noextent_cache noinline_data norecovery"
					CHK_NUM=16
					modprobe f2fs
					;;
		"jfs") 		FILESYSTEM="mkfs.jfs -q" 
					CHK_NUM=4
					fs_opts="discard errors=continue errors=panic nointegrity"
					;;
		"nilfs2") 	FILESYSTEM="mkfs.nilfs2 -q" 
					CHK_NUM=7
					fs_opts="discard nobarrier errors=continue errors=panic order=relaxed order=strict norecovery"
					;;
		"ntfs") 	FILESYSTEM="mkfs.ntfs -q" ;;
		"reiserfs") FILESYSTEM="mkfs.reiserfs -q"
					CHK_NUM=5
					fs_opts="acl nolog notail replayonly user_xattr"
					;;
		"vfat") 	FILESYSTEM="mkfs.vfat -F32" ;;
		"xfs") 		FILESYSTEM="mkfs.xfs -f" 
					CHK_NUM=9
					fs_opts="discard filestreams ikeep largeio noalign nobarrier norecovery noquota wsync"
					;;
		*) 			prep_menu ;;
	esac
	if [[ $FILESYSTEM != $_FSSkip ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_FSTitle " --yesno "\n$FILESYSTEM $PARTITION\n\n" 0 0
		if [[ $? -eq 0 ]]; then
			${FILESYSTEM} ${PARTITION} >/dev/null 2>/tmp/.errlog
			check_for_error
		else
			select_filesystem
		fi
	fi
 }
mount_partitions() {

mount_opts() {
	FS_OPTS=""
	echo "" > ${MOUNT_OPTS}
	for i in ${fs_opts}; do
		FS_OPTS="${FS_OPTS} ${i} - off"
	done
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $(echo $FILESYSTEM | sed "s/.*\.//g" | sed "s/-.*//g") " --checklist "$_btrfsMntBody" 0 0 $CHK_NUM \
	$FS_OPTS 2>${MOUNT_OPTS}
	sed -i 's/ /,/g' ${MOUNT_OPTS}
	sed -i '$s/,$//' ${MOUNT_OPTS}
	if [[ $(cat ${MOUNT_OPTS}) != "" ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MntStatusTitle " --yesno "\n${_btrfsMntConfBody}$(cat ${MOUNT_OPTS})\n" 10 75
		[[ $? -eq 1 ]] && mount_opts
	fi 
}

mount_current_partition(){
	mkdir -p ${MOUNTPOINT}${MOUNT} 2>/tmp/.errlog
    [[ $fs_opts != "" ]] && mount_opts
	if [[ $(cat ${MOUNT_OPTS}) != "" ]]; then
		mount -o $(cat ${MOUNT_OPTS}) ${PARTITION} ${MOUNTPOINT}${MOUNT} 2>>/tmp/.errlog
	else
		mount ${PARTITION} ${MOUNTPOINT}${MOUNT} 2>>/tmp/.errlog
	fi
	check_for_error
	confirm_mount ${MOUNTPOINT}${MOUNT}
	if [[ $(lsblk -lno TYPE ${PARTITION} | grep "crypt") != "" ]]; then
		LUKS=1
		LUKS_NAME=$(echo ${PARTITION} | sed "s~^/dev/mapper/~~g")
		cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "lvm" | grep -i "crypto_luks" | uniq | awk '{print "/dev/mapper/"$1}')
		for i in ${cryptparts}; do
			if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
				LUKS_DEV="$LUKS_DEV cryptdevice=${i}:$LUKS_NAME"
				LVM=1
				break;
			fi
		done
		cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "part" | grep -i "crypto_luks" | uniq | awk '{print "/dev/"$1}')
		for i in ${cryptparts}; do
			if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
				LUKS_UUID=$(lsblk -lno UUID,TYPE,FSTYPE ${i} | grep "part" | grep -i "crypto_luks" | awk '{print $1}')
				LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
				break;
			fi
		done
	elif [[ $(lsblk -lno TYPE ${PARTITION} | grep "lvm") != "" ]]; then
		LVM=1
		cryptparts=$(lsblk -lno NAME,TYPE,FSTYPE | grep "crypt" | grep -i "lvm2_member" | uniq | awk '{print "/dev/mapper/"$1}')
		for i in ${cryptparts}; do
			if [[ $(lsblk -lno NAME ${i} | grep $(echo $PARTITION | sed "s~^/dev/mapper/~~g")) != "" ]]; then
				LUKS_NAME=$(echo ${i} | sed s~/dev/mapper/~~g)
				break;
			fi
		done
		cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "part" | grep -i "crypto_luks" | uniq | awk '{print "/dev/"$1}')
		for i in ${cryptparts}; do
			if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
				LUKS_UUID=$(lsblk -lno UUID,TYPE,FSTYPE ${i} | grep "part" | grep -i "crypto_luks" | awk '{print $1}')
				if [[ $(echo $LUKS_DEV | grep $LUKS_UUID) == "" ]]; then
					LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
					LUKS=1
				fi
				break;
			fi
		done
	fi
}

make_swap(){
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelSwpBody" 0 0 7 "$_SelSwpNone" $"-" "$_SelSwpFile" $"-" ${PARTITIONS} 2>${ANSWER} || prep_menu  
    if [[ $(cat ${ANSWER}) != "$_SelSwpNone" ]]; then    
       PARTITION=$(cat ${ANSWER})
		if [[ $PARTITION == "$_SelSwpFile" ]]; then
			total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SelSwpFile " --inputbox "\nM = MB, G = GB\n" 9 30 "${total_memory}M" 2>${ANSWER} || make_swap
			m_or_g=$(cat ${ANSWER})
			while [[ $(echo ${m_or_g: -1} | grep "M\|G") == "" ]]; do
				dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SelSwpFile " --msgbox "\n$_SelSwpFile $_ErrTitle: M = MB, G = GB\n\n" 0 0
				dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SelSwpFile " --inputbox "\nM = MB, G = GB\n" 9 30 "${total_memory}M" 2>${ANSWER} || make_swap
				m_or_g=$(cat ${ANSWER})
			done
			fallocate -l ${m_or_g} ${MOUNTPOINT}/swapfile 2>/tmp/.errlog
			chmod 600 ${MOUNTPOINT}/swapfile 2>>/tmp/.errlog
			mkswap ${MOUNTPOINT}/swapfile 2>>/tmp/.errlog
			swapon ${MOUNTPOINT}/swapfile 2>>/tmp/.errlog
			check_for_error
		else # Swap Partition
			if [[ $(lsblk -o FSTYPE  ${PARTITION} | grep -i "swap") != "swap" ]]; then
				dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --yesno "\nmkswap ${PARTITION}\n\n" 0 0
				[[ $? -eq 0 ]] && mkswap ${PARTITION} >/dev/null 2>/tmp/.errlog || mount_partitions
			fi
			swapon  ${PARTITION} >/dev/null 2>>/tmp/.errlog
			check_for_error
			PARTITIONS=$(echo $PARTITIONS | sed "s~${PARTITION} [0-9]*[G-M]~~" | sed "s~${PARTITION} [0-9]*\.[0-9]*[G-M]~~" | sed s~${PARTITION}$' -'~~)
			NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS - 1 ))
		fi
	fi
}
	MOUNT=""
	LUKS_NAME=""
	LUKS_DEV=""
	LUKS_UUID=""
	LUKS=0
	LVM=0
	BTRFS=0
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --msgbox "$_WarnMount1 '$_FSSkip' $_WarnMount2" 0 0
    lvm_detect
	INCLUDE_PART='part\|lvm\|crypt'
    umount_partitions
	find_partitions
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelRootBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu
	PARTITION=$(cat ${ANSWER})
    ROOT_PART=${PARTITION}
	select_filesystem
	mount_current_partition
	make_swap
    if [[ $SYSTEM == "UEFI" ]]; then
       dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelUefiBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu  
       PARTITION=$(cat ${ANSWER})
       UEFI_PART=${PARTITION}
       if [[ $(fsck -N $PARTITION | grep fat) ]]; then
          dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --yesno "$_FormUefiBody $PARTITION $_FormUefiBody2" 0 0 && mkfs.vfat -F32 ${PARTITION} >/dev/null 2>/tmp/.errlog
       else 
          mkfs.vfat -F32 ${PARTITION} >/dev/null 2>/tmp/.errlog
       fi
       check_for_error
       dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_MntUefiBody"  0 0 2 \
 	   "/boot" "systemd-boot"\
	   "/boot/efi" "-" 2>${ANSWER}
	   [[ $(cat ${ANSWER}) != "" ]] && UEFI_MOUNT=$(cat ${ANSWER}) || prep_menu
       mkdir -p ${MOUNTPOINT}${UEFI_MOUNT} 2>/tmp/.errlog
       mount ${PARTITION} ${MOUNTPOINT}${UEFI_MOUNT} 2>>/tmp/.errlog
       check_for_error
       confirm_mount ${MOUNTPOINT}${UEFI_MOUNT}           
    fi
	while [[ $NUMBER_PARTITIONS > 0 ]]; do 
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_ExtPartBody" 0 0 7 "$_Done" $"-" ${PARTITIONS} 2>${ANSWER} || prep_menu 
		PARTITION=$(cat ${ANSWER})
             
		if [[ $PARTITION == $_Done ]]; then
			break;
		else
			MOUNT=""
			select_filesystem
			[[ $SYSTEM == "UEFI" ]] && MNT_EXAMPLES="/home\n/var" || MNT_EXAMPLES="/boot\n/home\n/var"
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart $PARTITON " --inputbox "$_ExtPartBody1$MNT_EXAMPLES\n" 0 0 "/" 2>${ANSWER} || prep_menu
			MOUNT=$(cat ${ANSWER})
			while [[ ${MOUNT:0:1} != "/" ]] || [[ ${#MOUNT} -le 1 ]] || [[ $MOUNT =~ \ |\' ]]; do
				dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_ExtErrBody" 0 0
				dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart $PARTITON " --inputbox "$_ExtPartBody1$MNT_EXAMPLES\n" 0 0 "/" 2>${ANSWER} || prep_menu
				MOUNT=$(cat ${ANSWER})                     
			done
			mount_current_partition
			if  [[ $MOUNT == "/boot" ]]; then
				[[ $(lsblk -lno TYPE ${PARTITION} | grep "lvm") != "" ]] && LVM_SEP_BOOT=2 || LVM_SEP_BOOT=1
			fi
		fi
	done
}	

######################################################################
##                    Installation Functions						##
######################################################################	
install_base() {
	clear
	pac_strap "base base-devel btrfs-progs f2fs-tools sudo"
    echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}" > /mnt/etc/vconsole.conf 2>>/tmp/.errlog
	cp -f /etc/pacman.conf /mnt/etc/pacman.conf 2>>/tmp/.errlog
	check_for_error
	if [ $(uname -m) == x86_64 ]; then
		sed -i '/\[multilib]$/ {
		N
		/Include/s/#//g}' /mnt/etc/pacman.conf 2>>/tmp/.errlog
	fi
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then
		echo -e "\n[archlinuxfr]\nServer = http://repo.archlinux.fr/$(uname -m)\nSigLevel = Never" >> /mnt/etc/pacman.conf 2>>/tmp/.errlog
	fi
	check_for_error	
	arch_chroot "pacman -Syy"
}
install_bootloader() {
    check_mount
	select_device
    arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl" 2>/tmp/.errlog
    check_for_error
	if [[ $SYSTEM == "BIOS" ]]; then		
		if [[ $DEVICE != "" ]]; then
			pac_strap "grub dosfstools"
			arch_chroot "grub-install --target=i386-pc --recheck $DEVICE" 2>/tmp/.errlog
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>> $log
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>> $log
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>/tmp/.errlog
			check_for_error
		fi
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		if [[ $DEVICE != "" ]]; then
			pac_strap "grub efibootmgr dosfstools"
			arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck" 2>/tmp/.errlog
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>> $log
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>> $log
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>/tmp/.errlog
			check_for_error
			arch_chroot "mkdir -p /boot/EFI/boot" 2>/tmp/.errlog
			arch_chroot "cp -r /boot/EFI/arch_grub/grubx64.efi /boot/EFI/boot/bootx64.efi" 2>>/tmp/.errlog
			check_for_error
		fi
	fi
	if [[ $SYSTEM == "systemd" ]]; then		
		if [[ $DEVICE != "" ]]; then
			pac_strap "systemd-boot efibootmgr dosfstools"
			arch_chroot "bootctl --path=/boot install" 2>/tmp/.errlog
			check_for_error
			[[ $(echo $ROOT_PART | grep "/dev/mapper/") != "" ]] && bl_root=$ROOT_PART \
			|| bl_root=$"PARTUUID="$(blkid -s PARTUUID ${ROOT_PART} | sed 's/.*=//g' | sed 's/"//g')
			echo -e "default  arch\ntimeout  1" > /mnt/boot/loader/loader.conf 2>/tmp/.errlog
			[[ -e /mnt/boot/initramfs-linux.img ]] && echo -e "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\troot=${bl_root} rw" > /mnt/boot/loader/entries/arch.conf
			sysdconf=$(ls /mnt/boot/loader/entries/arch*.conf)
		fi
	fi
}
install_network_menu() {
	#Wireless
	WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRELESS_DEV ]]; then 
		pac_strap "iw wireless_tools wpa_actiond dialog rp-pppoe"
	fi
	#Netzwerkkarte
	WIRED_DEV=`ip link | grep "ens\|eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRED_DEV ]]; then 
		pac_strap "networkmanager network-manager-applet"
		arch_chroot "systemctl enable dhcpcd@${WIRED_DEV}.service" 2>/tmp/.errlog
		arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service" 2>/tmp/.errlog
		check_for_error
	fi	
	#Drucker
	pac_strap "cups system-config-printer hplip splix cups-pdf ghostscript gsfonts"
	arch_chroot "systemctl enable org.cups.cupsd.service" 2>/tmp/.errlog
	check_for_error
	#bluetooth
	if (dmesg | grep -i "blue" &> /dev/null); then 
		pac_strap "bluez bluez-utils blueman"
		arch_chroot "systemctl enable bluetooth.service" 2>/tmp/.errlog
		check_for_error
	fi
	#Disable logs
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/journald.conf 2>/tmp/.errlog
	sed -i "s/SystemMaxUse.*/#&/g" /mnt/etc/systemd/journald.conf 2>/tmp/.errlog
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/coredump.conf 2>/tmp/.errlog
	echo "kernel.dmesg_restrict = 1" > /mnt/etc/sysctl.d/50-dmesg-restrict.conf 2>/tmp/.errlog
	check_for_error
}
install_xorg_input() {
	echo "" > ${PACKAGES}
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstGrMenuDS " --checklist "$_InstGrMenuDSBody\n\n$_UseSpaceBar" 0 0 12 \
	"wayland" "-" off \
	"xorg-server" "-" on \
	"xorg-server-common" "-" off \
	"xorg-server-utils" "-" on \
	"xorg-xinit" "-" on \
	"xorg-server-xwayland" "-" off \
	"xf86-input-evdev" "-" off \
	"xf86-input-joystick" "-" off \
	"xf86-input-keyboard" "-" on \
	"xf86-input-libinput" "-" off \
	"xf86-input-mouse" "-" on \
	"xf86-input-synaptics" "-" on 2>${PACKAGES}
	clear
	if [[ $(cat ${PACKAGES}) != "" ]]; then
		pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
		check_for_error
	fi
	user_list=$(ls ${MOUNTPOINT}/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f ${MOUNTPOINT}/etc/X11/xinit/xinitrc ${MOUNTPOINT}/home/$i/.xinitrc
		arch_chroot "chown -R ${i}:users /home/${i}"
	done
	install_graphics_menu
}
setup_graphics_card() {
install_intel(){
	pacstrap ${MOUNTPOINT} xf86-video-intel libva-intel-driver intel-ucode 2>/tmp/.errlog
    sed -i 's/MODULES=""/MODULES="i915"/' ${MOUNTPOINT}/etc/mkinitcpio.conf
    if [[ -e ${MOUNTPOINT}/boot/grub/grub.cfg ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " grub-mkconfig " --infobox "$_PlsWaitBody" 0 0
		sleep 1
		arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>>/tmp/.errlog
	fi
	[[ -e ${MOUNTPOINT}/boot/syslinux/syslinux.cfg ]] && sed -i "s/INITRD /&..\/intel-ucode.img,/g" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
	if [[ -e ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf ]]; then
			update=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/*.conf)
			for i in ${upgate}; do
				sed -i '/linux \//a initrd \/intel-ucode.img' ${i}
			done
	fi
}

install_ati(){
	pacstrap ${MOUNTPOINT} xf86-video-ati 2>/tmp/.errlog
	sed -i 's/MODULES=""/MODULES="radeon"/' ${MOUNTPOINT}/etc/mkinitcpio.conf
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
   dialog --default-item ${HIGHLIGHT_SUB_GC} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_GCtitle " \
    --menu "$GRAPHIC_CARD\n" 0 0 10 \
 	"1" $"xf86-video-ati" \
	"2" $"xf86-video-intel" \
	"3" $"xf86-video-nouveau (+ $INTEGRATED_GC)" \
	"4" $"Nvidia (+ $INTEGRATED_GC)" \
	"5" $"Nvidia-340xx (+ $INTEGRATED_GC)" \
	"6" $"Nvidia-304xx (+ $INTEGRATED_GC)" \
	"7" $"xf86-video-openchrome" \
	"8" $"virtualbox-guest-dkms" \
    "9" $"xf86-video-vmware" \
	"10" "$_GCUnknOpt / xf86-video-fbdev" 2>${ANSWER}
   case $(cat ${ANSWER}) in
        "1") # ATI/AMD
			install_ati
             ;;
        "2") # Intel
			install_intel
             ;;
        "3") # Nouveau / NVIDIA
			[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
			pacstrap ${MOUNTPOINT} xf86-video-nouveau 2>/tmp/.errlog
            sed -i 's/MODULES=""/MODULES="nouveau"/' ${MOUNTPOINT}/etc/mkinitcpio.conf       
             ;;
        "4") # NVIDIA-GF
			[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
			arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
			([[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"
			clear
			pacstrap ${MOUNTPOINT} ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings 2>/tmp/.errlog
            NVIDIA_INST=1
             ;;
        "5") # NVIDIA-340
			[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
			arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
			([[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"
			clear
            pacstrap ${MOUNTPOINT} ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings 2>/tmp/.errlog 
            NVIDIA_INST=1
             ;;
        "6") # NVIDIA-304
			[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
			arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"
  			([[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-304xx"
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-304xx-lts"
			clear
            pacstrap ${MOUNTPOINT} ${NVIDIA} nvidia-304xx-libgl nvidia-304xx-utils nvidia-settings 2>/tmp/.errlog
            NVIDIA_INST=1
             ;;              
        "7") # Via
			pacstrap ${MOUNTPOINT} xf86-video-openchrome 2>/tmp/.errlog
             ;;            
        "8") # VirtualBox
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && VB_MOD="linux-headers"
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && VB_MOD="$VB_MOD linux-grsec-headers"
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && VB_MOD="$VB_MOD linux-zen-headers"
			[[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && VB_MOD="$VB_MOD linux-lts-headers"
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$_VBoxInstTitle" --msgbox "$_VBoxInstBody" 0 0
            clear
            pacstrap ${MOUNTPOINT} virtualbox-guest-utils virtualbox-guest-dkms $VB_MOD 2>/tmp/.errlog
			umount -l /mnt/dev
            # Load modules and enable vboxservice.
            arch_chroot "modprobe -a vboxguest vboxsf vboxvideo"  
            arch_chroot "systemctl enable vboxservice"
            echo -e "vboxguest\nvboxsf\nvboxvideo" > ${MOUNTPOINT}/etc/modules-load.d/virtualbox.conf
             ;;
        "9") # VMWare
			pacstrap ${MOUNTPOINT} xf86-video-vmware xf86-input-vmmouse 2>/tmp/.errlog
             ;;
       "10") # Generic / Unknown
			  pacstrap ${MOUNTPOINT} xf86-video-fbdev 2>/tmp/.errlog
             ;;
          *) install_graphics_menu
             ;;
    esac
    check_for_error
 if [[ $NVIDIA_INST == 1 ]] && [[ ! -e ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf ]]; then
    echo "Section "\"Device"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        Identifier "\"Nvidia Card"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        Driver "\"nvidia"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        VendorName "\"NVIDIA Corporation"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        Option "\"NoLogo"\" "\"true"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        #Option "\"UseEDID"\" "\"false"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        #Option "\"ConnectedMonitor"\" "\"DFP"\"" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "        # ..." >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
    echo "EndSection" >> ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
 fi
 # Where NVIDIA has been installed allow user to check and amend the file
 if [[ $NVIDIA_INST == 1 ]]; then
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_NvidiaConfTitle " --msgbox "$_NvidiaConfBody" 0 0
    nano ${MOUNTPOINT}/etc/X11/xorg.conf.d/20-nvidia.conf
 fi
 install_graphics_menu
}
install_de_wm() {
   if [[ $SHOW_ONCE -eq 0 ]]; then
      dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstDETitle " --msgbox "$_DEInfoBody" 0 0
      SHOW_ONCE=1
   fi
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstDETitle " --checklist "$_InstDEBody $_UseSpaceBar" 0 0 12 \
	"budgie-desktop" "-" off \
	"cinnamon" "-" off \
	"deepin" "-" off \
	"deepin-extra" "-" off \
	"enlightenment + terminology" "-" off \
	"gnome-shell" "-" off \
	"gnome" "-" off \
	"gnome-extra" "-" off \
	"plasma-desktop" "-" off \
	"plasma" "-" off \
	"kde-applications" "-" off \
	"lxde" "-" off \
	"lxqt + oxygen-icons" "-" off \
	"mate" "-" off \
	"mate-extra" "-" off \
	"mate-gtk3" "-" off \
	"mate-extra-gtk3" "-" off \
	"xfce4" "-" off \
	"xfce4-goodies" "-" off \
	"awesome + vicious" "-" off \
	"fluxbox + fbnews" "-" off \
	"i3-wm + i3lock + i3status" "-" off \
	"icewm + icewm-themes" "-" off \
	"openbox + openbox-themes" "-" off \
	"pekwm + pekwm-themes" "-" off \
	"windowmaker" "-" off 2>${PACKAGES}
	if [[ $(cat ${PACKAGES}) != "" ]]; then
		clear
		sed -i 's/+\|\"//g' ${PACKAGES}
		pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
		check_for_error
		echo "" > ${PACKAGES}
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstComTitle " --checklist "$_InstComBody $_UseSpaceBar" 0 50 14 \
		"bash-completion" "-" on \
		"gamin" "-" on \
		"gksu" "-" on \
		"gnome-icon-theme" "-" on \
		"gnome-keyring" "-" on \
		"gvfs" "-" on \
		"gvfs-afc" "-" on \
		"gvfs-smb" "-" on \
		"polkit" "-" on \
		"poppler" "-" on \
		"python2-xdg" "-" on \
		"ntfs-3g" "-" on \
		"ttf-dejavu" "-" on \
		"xdg-user-dirs" "-" on \
		"xdg-utils" "-" on \
		"xterm" "-" on 2>${PACKAGES}
		if [[ $(cat ${PACKAGES}) != "" ]]; then
			clear
			pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
			check_for_error
		fi
	fi
}
install_dm() {

enable_dm() {
	arch_chroot "systemctl enable $(cat ${PACKAGES})" 2>/tmp/.errlog
	check_for_error
	DM=$(cat ${PACKAGES})
	DM_ENABLED=1
}
	if [[ $DM_ENABLED -eq 0 ]]; then
		echo "" > ${PACKAGES}
		dm_list="gdm lxdm lightdm sddm"
		DM_LIST=""
		DM_INST=""
		for i in ${dm_list}; do
			[[ -e ${MOUNTPOINT}/usr/bin/${i} ]] && DM_INST="${DM_INST} ${i}"
			DM_LIST="${DM_LIST} ${i} -"
		done
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_DmChTitle " --menu "$_AlreadyInst$DM_INST\n\n$_DmChBody" 0 0 4 \
		${DM_LIST} 2>${PACKAGES}
		clear
		if [[ $(cat ${PACKAGES}) != "" ]]; then
			for i in ${DM_INST}; do
				if [[ $(cat ${PACKAGES}) == ${i} ]]; then
					enable_dm
					break;
				fi
			done
			if [[ $DM_ENABLED -eq 0 ]]; then
				sed -i 's/lightdm/lightdm lightdm-gtk-greeter/' ${PACKAGES}
				pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
				sed -i 's/lightdm-gtk-greeter//' ${PACKAGES}
				enable_dm
			fi
		fi
	fi
	[[ $DM_ENABLED -eq 1 ]] && dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_DmChTitle " --msgbox "$_DmDoneBody" 0 0       
}
install_multimedia_menu(){

install_alsa_pulse(){
	echo "" > ${PACKAGES}
	ALSA=""
	PULSE_EXTRA=""
	alsa=$(pacman -Ss alsa | awk '{print $1}' | grep "/alsa-" | sed "s/extra\///g" | sort -u)
	pulse_extra=$(pacman -Ss pulseaudio- | awk '{print $1}' | sed "s/extra\///g" | grep "pulseaudio-" | sort -u)
	for i in ${alsa}; do
		ALSA="${ALSA} ${i} - off"
	done
	ALSA=$(echo $ALSA | sed "s/alsa-utils - off/alsa-utils - on/g" | sed "s/alsa-plugins - off/alsa-plugins - on/g")
	for i in ${pulse_extra}; do
		PULSE_EXTRA="${PULSE_EXTRA} ${i} - off"
	done
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstMulSnd " --checklist "$_InstMulSndBody\n\n$_UseSpaceBar" 0 0 14 \
	$ALSA "pulseaudio" "-" off $PULSE_EXTRA \
	"paprefs" "pulseaudio GUI" off \
	"pavucontrol" "pulseaudio GUI" off \
	"ponymix" "pulseaudio CLI" off \
	"volumeicon" "ALSA GUI" off \
	"volwheel" "ASLA GUI" off 2>${PACKAGES}
	clear
	if [[ $(cat ${PACKAGES}) != "" ]]; then
		pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
		check_for_error
	fi
}

install_codecs(){
	echo "" > ${PACKAGES}
	GSTREAMER=""
	gstreamer=$(pacman -Ss gstreamer | awk '{print $1}' | grep "/gstreamer" | sed "s/extra\///g" | sed "s/community\///g" | sort -u)
	echo $gstreamer
	for i in ${gstreamer}; do
		GSTREAMER="${GSTREAMER} ${i} - off"
	done
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstMulCodec " --checklist "$_InstMulCodBody$_UseSpaceBar" 0 0 14 \
	$GSTREAMER "xine-lib" "-" off 2>${PACKAGES}
	if [[ $(cat ${PACKAGES}) != "" ]]; then
		pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
		check_for_error
	fi
}
 
install_cust_pkgs(){
	echo "" > ${PACKAGES}
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstMulCust " --inputbox "$_InstMulCustBody" 0 0 "" 2>${PACKAGES} || install_multimedia_menu
	clear
	if [[ $(cat ${PACKAGES}) != "" ]]; then
		if [[ $(cat ${PACKAGES}) == "hen poem" ]]; then
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " \"My Sweet Buckies\" by Atiya & Carl " --msgbox "\nMy Sweet Buckies,\nYou are the sweetest Buckies that ever did \"buck\",\nLily, Rosie, Trumpet, and Flute,\nMy love for you all is absolute!\n\nThey buck: \"We love our treats, we are the Booyakka sisters,\"\n\"Sometimes we squabble and give each other comb-twisters,\"\n\"And in our garden we love to sunbathe, forage, hop and jump,\"\n\"We love our freedom far, far away from that factory farm dump,\"\n\n\"For so long we were trapped in cramped prisons full of disease,\"\n\"No sunlight, no fresh air, no one who cared for even our basic needs,\"\n\"We suffered in fear, pain, and misery for such a long time,\"\n\"But now we are so happy, we wanted to tell you in this rhyme!\"\n\n" 0 0
		else
			pacstrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>/tmp/.errlog
			check_for_error
		fi
	fi
}

	if [[ $SUB_MENU != "install_multimedia_menu" ]]; then
	   SUB_MENU="install_multimedia_menu"
	   HIGHLIGHT_SUB=1
	else
	   if [[ $HIGHLIGHT_SUB != 5 ]]; then
	      HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
	   fi
	fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstMultMenuTitle " --menu "$_InstMultMenuBody" 0 0 5 \
 	"1" "$_InstMulSnd" \
 	"2" "$_InstMulCodec" \
 	"3" "$_InstMulAcc" \
 	"4" "$_InstMulCust" \
 	"5" "$_Back" 2>${ANSWER}
	HIGHLIGHT_SUB=$(cat ${ANSWER})
	case $(cat ${ANSWER}) in
        "1") install_alsa_pulse
             ;;
        "2") install_codecs
             ;;
        "3") install_acc_menu
             ;;
        "4") install_cust_pkgs
             ;;
		  *) main_menu_online
             ;;
	esac
	install_multimedia_menu
}
security_menu(){
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/journald.conf
	sed -i "s/SystemMaxUse.*/#&/g" /mnt/etc/systemd/journald.conf
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" /mnt/etc/systemd/coredump.conf
	echo "kernel.dmesg_restrict = 1" > /mnt/etc/sysctl.d/50-dmesg-restrict.conf
}

######################################################################
##                 Main Interfaces       							##
######################################################################

prep_menu() {
	if [[ $SUB_MENU != "prep_menu" ]]; then
	   SUB_MENU="prep_menu"
	   HIGHLIGHT_SUB=1
	else
	   if [[ $HIGHLIGHT_SUB != 7 ]]; then
	      HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
	   fi
	fi
	dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMenuTitle " --menu "$_PrepMenuBody" 0 0 7 \
	"1" "$_VCKeymapTitle" \
	"2" "$_DevShowOpt" \
	"3" "$_PrepPartDisk" \
	"4" "$_PrepLUKS" \
	"5" "$_PrepLVM $_PrepLVM2" \
	"6" "$_PrepMntPart" \
	"7" "$_Back" 2>${ANSWER}
    HIGHLIGHT_SUB=$(cat ${ANSWER})
	case $(cat ${ANSWER}) in
        "1") set_keymap 
             ;;
        "2") show_devices
             ;;
        "3") umount_partitions
             select_device
             create_partitions
             ;;
        "4") luks_menu
			;;
        "5") lvm_menu
             ;;
        "6") mount_partitions
             ;;        
          *) main_menu_online
             ;;
    esac
    prep_menu  	
}

install_base_menu() {
	if [[ $SUB_MENU != "install_base_menu" ]]; then
	   SUB_MENU="install_base_menu"
	   HIGHLIGHT_SUB=1
	else
	   if [[ $HIGHLIGHT_SUB != 5 ]]; then
	      HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
	   fi
	fi
   dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstBsMenuTitle " --menu "$_InstBseMenuBody" 0 0 5 \
 	"1"	"$_PrepMirror" \
 	"2" "$_PrepPacKey" \
 	"3" "$_InstBse" \
	"4" "$_InstBootldr" \
	"5" "$_Back" 2>${ANSWER}	
	HIGHLIGHT_SUB=$(cat ${ANSWER})
	case $(cat ${ANSWER}) in
	"1") configure_mirrorlist
		;;
	"2") clear
		 pacman-key --init
		 pacman-key --populate archlinux
		 pacman-key --refresh-keys
		;;
	"3") install_base
		;;
	"4") install_bootloader
		;;
	*) main_menu_online
		;;
	esac
	install_base_menu 	
}

config_base_menu() {
    arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl" 2>/tmp/.errlog
	check_for_error
	if [[ $SUB_MENU != "config_base_menu" ]]; then
	   SUB_MENU="config_base_menu"
	   HIGHLIGHT_SUB=1
	else
	   if [[ $HIGHLIGHT_SUB != 8 ]]; then
	      HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
	   fi
	fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseMenuTitle " --menu "$_ConfBseBody" 0 0 8 \
 	"1" "$_ConfBseFstab" \
	"2" "$_ConfBseHost" \
	"3" "$_ConfBseSysLoc" \
	"4" "$_ConfBseTimeHC" \
	"5" "$_ConfUsrRoot" \
	"6" "$_ConfUsrNew" \
	"7" "$_MMRunMkinit" \
	"8" "$_Back" 2>${ANSWER}	
	HIGHLIGHT_SUB=$(cat ${ANSWER})
	case $(cat ${ANSWER}) in
        "1") generate_fstab 
             ;;
        "2") set_hostname
             ;;
        "3") set_locale
             ;;        
        "4") set_timezone
			 set_hw_clock
             ;;
		"5") set_root_password 
			;;
		"6") create_new_user
			;;
		"7") run_mkinitcpio
			;;
          *) main_menu_online
			;;
    esac
    config_base_menu
}

install_graphics_menu() {
	if [[ $SUB_MENU != "install_graphics_menu" ]]; then
	   SUB_MENU="install_graphics_menu"
	   HIGHLIGHT_SUB=1
	else
	   if [[ $HIGHLIGHT_SUB != 6 ]]; then
	      HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
	   fi
	fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstGrMenuTitle " --menu "$_InstGrMenuBody" 0 0 6 \
 	"1" "$_InstGrMenuDS" \
	"2" "$_InstGrMenuDD" \
	"3" "$_InstGrMenuGE" \
	"4" "$_InstGrMenuDM" \
	"5"	"$_PrepKBLayout" \
	"6" "$_Back" 2>${ANSWER}
	HIGHLIGHT_SUB=$(cat ${ANSWER})
	case $(cat ${ANSWER}) in
        "1") install_xorg_input
			;;
		"2") setup_graphics_card 
             ;;
        "3") install_de_wm
             ;;
        "4") install_dm
             ;;
		"5") set_xkbmap
			;;
          *) main_menu_online
			;;
    esac
    install_graphics_menu
}

install_acc_menu() {
	echo "" > ${PACKAGES}
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstAccTitle " --checklist "$_InstAccBody" 0 0 15 \
	"accerciser" "-" off \
	"at-spi2-atk" "-" off \
	"at-spi2-core" "-" off \
	"brltty" "-" off \
	"caribou" "-" off \
	"dasher" "-" off \
	"espeak" "-" off \
	"espeakup" "-" off \
	"festival" "-" off \
	"java-access-bridge" "-" off \
	"java-atk-wrapper" "-" off \
	"julius" "-" off \
	"orca" "-" off \
	"qt-at-spi" "-" off \
	"speech-dispatcher" "-" off 2>${PACKAGES}
	clear
	if [[ $(cat ${PACKAGES}) != "" ]]; then
		pacstrap ${MOUNTPOINT} ${PACKAGES} 2>/tmp/.errlog
		check_for_error
	fi
	install_multimedia_menu
}

edit_configs() {
	FILE=""
	user_list=""
	if [[ $SUB_MENU != "edit configs" ]]; then
	   SUB_MENU="edit configs"
	   HIGHLIGHT_SUB=1
	else
	   if [[ $HIGHLIGHT_SUB != 12 ]]; then
	      HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
	   fi
	fi
   dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SeeConfOptTitle " --menu "$_SeeConfOptBody" 0 0 13 \
   "1" "/etc/vconsole.conf" \
   "2" "/etc/locale.conf" \
   "3" "/etc/hostname" \
   "4" "/etc/hosts" \
   "5" "/etc/sudoers" \
   "6" "/etc/mkinitcpio.conf" \
   "7" "/etc/fstab" \
   "8" "/etc/crypttab" \
   "9" "grub/syslinux/systemd-boot" \
   "10" "lxdm/lightdm/sddm" \
   "11" "/etc/pacman.conf" \
   "12" "~/.xinitrc" \
   "13" "$_Back" 2>${ANSWER}
	HIGHLIGHT_SUB=$(cat ${ANSWER})
	case $(cat ${ANSWER}) in
	    "1") [[ -e ${MOUNTPOINT}/etc/vconsole.conf ]] && FILE="${MOUNTPOINT}/etc/vconsole.conf"
             ;;
        "2") [[ -e ${MOUNTPOINT}/etc/locale.conf ]] && FILE="${MOUNTPOINT}/etc/locale.conf" 
             ;;
        "3") [[ -e ${MOUNTPOINT}/etc/hostname ]] && FILE="${MOUNTPOINT}/etc/hostname"
             ;;
        "4") [[ -e ${MOUNTPOINT}/etc/hosts ]] && FILE="${MOUNTPOINT}/etc/hosts"
             ;;
        "5") [[ -e ${MOUNTPOINT}/etc/sudoers ]] && FILE="${MOUNTPOINT}/etc/sudoers"
             ;;
        "6") [[ -e ${MOUNTPOINT}/etc/mkinitcpio.conf ]] && FILE="${MOUNTPOINT}/etc/mkinitcpio.conf"
             ;;
        "7") [[ -e ${MOUNTPOINT}/etc/fstab ]] && FILE="${MOUNTPOINT}/etc/fstab"
             ;;
        "8") [[ -e ${MOUNTPOINT}/etc/crypttab ]] && FILE="${MOUNTPOINT}/etc/crypttab"
			 ;;
        "9") [[ -e ${MOUNTPOINT}/etc/default/grub ]] && FILE="${MOUNTPOINT}/etc/default/grub"
			 [[ -e ${MOUNTPOINT}/boot/syslinux/syslinux.cfg ]] && FILE="$FILE ${MOUNTPOINT}/boot/syslinux/syslinux.cfg"
			 if [[ -e ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf ]]; then
				files=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/*.conf)
				for i in ${files}; do
					FILE="$FILE ${i}"
				done
			 fi
            ;;
        "10") [[ -e ${MOUNTPOINT}/etc/lxdm/lxdm.conf ]] && FILE="${MOUNTPOINT}/etc/lxdm/lxdm.conf" 
			  [[ -e ${MOUNTPOINT}/etc/lightdm/lightdm.conf ]] && FILE="${MOUNTPOINT}/etc/lightdm/lightdm.conf"
              [[ -e ${MOUNTPOINT}/etc/sddm.conf ]] && FILE="${MOUNTPOINT}/etc/sddm.conf"
            ;;
        "11") [[ -e ${MOUNTPOINT}/etc/pacman.conf ]] && FILE="${MOUNTPOINT}/etc/pacman.conf"
			;;
		"12") user_list=$(ls ${MOUNTPOINT}/home/ | sed "s/lost+found//")
			  for i in ${user_list}; do
				[[ -e ${MOUNTPOINT}/home/$i/.xinitrc ]] && FILE="$FILE ${MOUNTPOINT}/home/$i/.xinitrc"
			  done
			;;
         *) main_menu_online
            ;;
     esac
	[[ $FILE != "" ]] && nano $FILE \
	|| dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_SeeConfErrBody" 0 0
	edit_configs
}

main_menu_online() {
	if [[ $HIGHLIGHT != 9 ]]; then
	   HIGHLIGHT=$(( HIGHLIGHT + 1 ))
	fi
    dialog --default-item ${HIGHLIGHT} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MMTitle " \
    --menu "$_MMBody" 0 0 9 \
 	"1" "$_PrepMenuTitle" \
	"2" "$_InstBsMenuTitle" \
	"3" "$_ConfBseMenuTitle" \
	"4" "$_InstGrMenuTitle" \
	"5" "$_InstNMMenuTitle" \
    "6" "$_InstMultMenuTitle" \
    "7" "$_SecMenuTitle" \
    "8" "$_SeeConfOptTitle" \
	"9" "$_Done" 2>${ANSWER}
    HIGHLIGHT=$(cat ${ANSWER})
    if [[ $(cat ${ANSWER}) -eq 2 ]]; then
       check_mount
    fi
    if [[ $(cat ${ANSWER}) -ge 3 ]] && [[ $(cat ${ANSWER}) -le 8 ]]; then
       check_mount
       check_base
    fi
    case $(cat ${ANSWER}) in
        "1") prep_menu 
             ;;
        "2") install_base_menu
             ;;
        "3") config_base_menu
             ;;          
        "4") install_graphics_menu
             ;;
        "5") install_network_menu
			;;
        "6") install_multimedia_menu
			;;
        "7") security_menu
			;;
        "8") edit_configs
             ;;            
          *) dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "$_CloseInstBody" 0 0
          
             if [[ $? -eq 0 ]]; then
                umount_partitions
                clear
                exit 0
             else
                main_menu_online
             fi
             ;;
    esac
    main_menu_online 
}

######################################################################
##                        Execution     							##
######################################################################
id_system
select_language
check_requirements

	while true; do
          main_menu_online      
    done
