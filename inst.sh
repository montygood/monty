# !/bin/bash

######################################################################
##                   Installer Variables							##
######################################################################

ANSWER="/tmp/.aif"
PACKAGES="/tmp/.pkgs"
MOUNT_OPTS="/tmp/.mnt_opts"
VERSION="Architect Installation Framework 2.3.1"

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
MOUNT=""							# Installation: All other mounts branching from Root
FS_OPTS=""							# File system special mount options available
CHK_NUM=16							# Used for FS mount options checklist length
INCLUDE_PART='part\|lvm\|crypt'		# Partition types to include for display and selection.
ROOT_PART=""          				# ROOT partition
UEFI_PART=""						# UEFI partition
UEFI_MOUNT=""         				# UEFI mountpoint (/boot or /boot/efi)
ARCHI=$(uname -m)     				# Display whether 32 or 64 bit system
SYSTEM="Unknown"     				# Display whether system is BIOS or UEFI. Default is "unknown"
HIGHLIGHT=0           				# Highlight items for Main Menu
HIGHLIGHT_SUB=0	    				# Highlight items for submenus
SUB_MENU=""           				# Submenu to be highlighted

#Variablen
op_title=" -| Arch Installation - ($(uname -m)) |- "
LOCALE="de_CH.UTF-8"
FONT=""
KEYMAP="de_CH-latin1"
CODE="CH"
ZONE="Europe"
SUBZONE="Zurich"
XKBMAP="ch"
SPRA="de"
FILE=""
MOUNTPOINT="/mnt"

######################################################################
##                   		  Funktionen							##
######################################################################
select_language() {   
	sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen
	locale-gen >/dev/null 2>&1
	export LANG=${LOCALE}
	[[ $FONT != "" ]] && setfont $FONT
}
check_requirements() {
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Systemprüfung |- " --infobox "\nTeste Voraussetzungen" 0 0 && sleep 2
	if [[ `whoami` != "root" ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --infobox "\ndu bist nicht 'root'\nScript wird beendet" 0 0 && sleep 2
		exit 1
	fi
	if [[ ! $(ping -c 1 google.com) ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --infobox "\nkein Internet Zugang.\nScript wird beendet" 0 0 && sleep 2
		exit 1
	fi
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Systemprüfung |- " --infobox "\nalles OK" 0 0 && sleep 2   
	clear
	echo "" > /tmp/.errlog
	pacman -Syy
}
id_system() {
	# Apple System Detection
	if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
		modprobe -r -q efivars || true  # if MAC
	else
		modprobe -q efivarfs            # all others
	fi
	# BIOS or UEFI Detection
	if [[ -d "/sys/firmware/efi/" ]]; then
		# Mount efivarfs if it is not already mounted
		if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
			mount -t efivarfs efivarfs /sys/firmware/efi/efivars
		fi
			SYSTEM="UEFI"
		else
			SYSTEM="BIOS"
	fi
}   
arch_chroot() {
	arch-chroot $MOUNTPOINT /bin/bash -c "${1}"
}  
check_for_error() {
	if [[ $? -eq 1 ]] && [[ $(cat /tmp/.errlog | grep -i "error") != "" ]]; then
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "$(cat /tmp/.errlog)" 0 0
	echo "" > /tmp/.errlog
	main_menu_online
fi
}
check_mount() {
	if [[ $(lsblk -o MOUNTPOINT | grep ${MOUNTPOINT}) == "" ]]; then
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "\nzuerst die Partition Mounten" 0 0
	main_menu_online
fi
}
check_base() {
	if [[ ! -e ${MOUNTPOINT}/etc ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "\nzuerst BASE installieren" 0 0
		main_menu_online
	fi
}
configure_mirrorlist() {
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Spiegelserver |- " --infobox "...Bitte warten..." 0 0
	curl -so /etc/pacman.d/mirrorlist.new https://www.archlinux.org/mirrorlist/?country=${CODE}&use_mirror_status=on
	mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
	sed -i 's/#//' /etc/pacman.d/mirrorlist.new
	chmod +r /etc/pacman.d/mirrorlist.new
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Spiegelserver |- " --infobox "\nsortiere die Spiegelserver\n...Bitte warten..." 0 0
	rankmirrors -n 10 /etc/pacman.d/mirrorlist.new > /etc/pacman.d/mirrorlist 2>/tmp/.errlog
	check_for_error
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Spiegelserver |- " --infobox "\nFertig!\n\n" 0 0 && sleep 2
}
set_keymap() { 
	loadkeys $KEYMAP 2>/tmp/.errlog
	check_for_error
	echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}" > /tmp/vconsole.conf
}
set_xkbmap() {
	echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" > ${MOUNTPOINT}/etc/X11/xorg.conf.d/00-keyboard.conf
}
set_locale() {
	echo "LANG=\"${LOCALE}\"" > ${MOUNTPOINT}/etc/locale.conf
	sed -i "s/#${LOCALE}/${LOCALE}/" ${MOUNTPOINT}/etc/locale.gen 2>/tmp/.errlog
	arch_chroot "locale-gen" >/dev/null 2>>/tmp/.errlog
	check_for_error
}
set_timezone() {
	arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime" 2>/tmp/.errlog && check_for_error
}
set_hw_clock() {
	arch_chroot "hwclock --systohc --utc"  2>/tmp/.errlog && check_for_error
}
generate_fstab() {
	genfstab -U -p ${MOUNTPOINT} > ${MOUNTPOINT}/etc/fstab 2>/tmp/.errlog && check_for_error
	[[ -f ${MOUNTPOINT}/swapfile ]] && sed -i "s/\\${MOUNTPOINT}//" ${MOUNTPOINT}/etc/fstab
	config_base_menu
}
set_hostname() {
	HOSTNAME=$(dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Hostname |- " --stdout --inputbox "Identifizierung im Netzwerk" 0 0 "")
	echo "${HOSTNAME}" > ${MOUNTPOINT}/etc/hostname 2>/tmp/.errlog
	echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}\n::1\tlocalhost.localdomain\tlocalhost\t${HOSTNAME}" > ${MOUNTPOINT}/etc/hosts 2>>/tmp/.errlog
	check_for_error
}
set_root_password() {
	RPASSWD=$(dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort:" 0 0 "")
	RPASSWD2=$(dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Root |- " --stdout --clear --insecure --passwordbox "Passwort bestätigen:" 0 0 "")
	if [[ $RPASSWD == $RPASSWD2 ]]; then 
		echo -e "${RPASSWD}\n${RPASSWD}" > /tmp/.passwd
		arch_chroot "passwd root" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
	else
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| FEHLER |- " --infobox "\nDie eingegebenen Passwörter stimmen nicht überein." 0 0
		set_root_password
	fi
}
create_new_user() {
	USER=$(dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Benutzer |- " --stdout --inputbox "Namen des Benutzers in Kleinbuchstaben." 0 0 "")
	if [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| FEHLER |- " --msgbox "Ungültiger Benutzername." 0 0
		set_user
	fi
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "-| Benutzer |-" --infobox "erstelle Berechtigungen" 0 0 && sleep 2
	arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp -s /bin/bash" 2>/tmp/.errlog
	check_for_error
	arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
	rm /tmp/.passwd
	check_for_error
	arch_chroot "cp /etc/skel/.bashrc /home/${USER}"
	arch_chroot "chown -R ${USER}:users /home/${USER}"
	[[ -e ${MOUNTPOINT}/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' ${MOUNTPOINT}/etc/sudoers
}
run_mkinitcpio() {
	clear
	arch_chroot "mkinitcpio -p linux" 2>>/tmp/.errlog && check_for_error
}

######################################################################
##            System and Partitioning Functions						##
######################################################################
umount_partitions(){
	MOUNTED=""
	MOUNTED=$(mount | grep "${MOUNTPOINT}" | awk '{print $3}' | sort -r)
	swapoff -a
	for i in ${MOUNTED[@]}; do
		umount $i >/dev/null 2>>/tmp/.errlog
	done
	check_for_error
}
confirm_mount() {
	if [[ $(mount | grep $1) ]]; then   
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Mount Status |- " --infobox "\nerstellt" 0 0 && sleep 2
		PARTITIONS=$(echo $PARTITIONS | sed "s~${PARTITION} [0-9]*[G-M]~~" | sed "s~${PARTITION} [0-9]*\.[0-9]*[G-M]~~" | sed s~${PARTITION}$' -'~~)
		NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS - 1 ))
	else
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Mount Status |- " --infobox "\nfehlgeschlagen" 0 0 && sleep 2
		prep_menu
	fi
}
select_device() {
	DEVICE=""
	devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u);
	for i in ${devices_list[@]}; do
		DEVICE="${DEVICE} ${i}"
	done
	DEVICE=$(dialog --nocancel --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Laufwerk |- " --menu "Welche HDD wird verwendet" 0 0 4 ${DEVICE} 3>&1 1>&2 2>&3)
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
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "Partitionen sind falsch" 0 0
		create_partitions
	fi
	;;
	'part\|crypt') # Ensure there is at least one partition for LVM 
	if [[ $NUMBER_PARTITIONS -eq 0 ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "Volumen falsch" 0 0
		create_partitions
	fi
	;;
	'part\|lvm') # Ensure there are at least two partitions for LUKS
	if [[ $NUMBER_PARTITIONS -lt 2 ]]; then
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "Verschlüsselung fehlerhaft" 0 0
		create_partitions
	fi
	;;
	esac
}
create_partitions(){
secure_wipe(){
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "-| Wipen |-" --yesno "unwiederuflich löschen auf ${DEVICE} sauber dauert aber etwas länger" 0 0
	if [[ $? -eq 0 ]]; then
		clear
		if [[ ! -e /usr/bin/wipe ]]; then
			pacman -Sy --noconfirm wipe 2>/tmp/.errlog
			check_for_error
		fi
		clear
		wipe -Ifre ${DEVICE}
		#dd if=/dev/zero | pv | dd of=${DEVICE} iflag=nocache oflag=direct bs=4096 2>/tmp/.errlog && check_for_error
	else
		create_partitions
	fi
}
auto_partition(){
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "-| Harddisk |-" --yesno "Harddisk $DEVICE wird bearbeitet" 0 0
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
		dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "wurde so Erstellt" --textbox /tmp/.devlist 0 0
	else
		create_partitions
	fi
}
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "-| Harddisk | -" --menu "Auswahl" 0 0 7 \
	"Sicher" "Wipen sauber aber langsam" \
	"Automatisch" "BIOS & UEFI" 2>${ANSWER}
	clear
	if ([[ $(cat ${ANSWER}) != "$_PartOptWipe" ]] &&  [[ $(cat ${ANSWER}) != "$_PartOptAuto" ]]); then
	$(cat ${ANSWER}) ${DEVICE}
	else
	[[ $(cat ${ANSWER}) == "Sicher" ]] && secure_wipe && create_partitions
	[[ $(cat ${ANSWER}) == "Automatisch" ]] && auto_partition
	fi
	prep_menu
}	
select_filesystem(){

# prep variables
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

# Warn about formatting!
if [[ $FILESYSTEM != $_FSSkip ]]; then
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " FS-System " --yesno "\n$FILESYSTEM $PARTITION\n\n" 0 0
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

dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $(echo $FILESYSTEM | sed "s/.*\.//g" | sed "s/-.*//g") " --checklist "Auswahl" 0 0 $CHK_NUM \
$FS_OPTS 2>${MOUNT_OPTS}

# Now clean up the file
sed -i 's/ /,/g' ${MOUNT_OPTS}
sed -i '$s/,$//' ${MOUNT_OPTS}

# If mount options selected, confirm choice 
if [[ $(cat ${MOUNT_OPTS}) != "" ]]; then
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Mount Status |- " --yesno "\n${_btrfsMntConfBody}$(cat ${MOUNT_OPTS})\n" 10 75
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

# Identify if mounted partition is type "crypt" (LUKS on LVM, or LUKS alone)
if [[ $(lsblk -lno TYPE ${PARTITION} | grep "crypt") != "" ]]; then

# cryptname for bootloader configuration either way
LUKS=1
LUKS_NAME=$(echo ${PARTITION} | sed "s~^/dev/mapper/~~g")

# Check if LUKS on LVM (parent = lvm /dev/mapper/...) 
cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "lvm" | grep -i "crypto_luks" | uniq | awk '{print "/dev/mapper/"$1}')
for i in ${cryptparts}; do
if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
LUKS_DEV="$LUKS_DEV cryptdevice=${i}:$LUKS_NAME"
LVM=1
break;
fi
done

# Check if LUKS alone (parent = part /dev/...)
cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "part" | grep -i "crypto_luks" | uniq | awk '{print "/dev/"$1}')
for i in ${cryptparts}; do
if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
LUKS_UUID=$(lsblk -lno UUID,TYPE,FSTYPE ${i} | grep "part" | grep -i "crypto_luks" | awk '{print $1}')
LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
break;
fi
done

# If LVM logical volume....
elif [[ $(lsblk -lno TYPE ${PARTITION} | grep "lvm") != "" ]]; then
LVM=1

# First get crypt name (code above would get lv name)
cryptparts=$(lsblk -lno NAME,TYPE,FSTYPE | grep "crypt" | grep -i "lvm2_member" | uniq | awk '{print "/dev/mapper/"$1}')
for i in ${cryptparts}; do
if [[ $(lsblk -lno NAME ${i} | grep $(echo $PARTITION | sed "s~^/dev/mapper/~~g")) != "" ]]; then
LUKS_NAME=$(echo ${i} | sed s~/dev/mapper/~~g)
break;
fi
done

# Now get the device (/dev/...) for the crypt name
cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "part" | grep -i "crypto_luks" | uniq | awk '{print "/dev/"$1}')
for i in ${cryptparts}; do
if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
# Create UUID for comparison
LUKS_UUID=$(lsblk -lno UUID,TYPE,FSTYPE ${i} | grep "part" | grep -i "crypto_luks" | awk '{print $1}')

# Check if not already added as a LUKS DEVICE (i.e. multiple LVs on one crypt). If not, add.
if [[ $(echo $LUKS_DEV | grep $LUKS_UUID) == "" ]]; then
LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
LUKS=1
fi

break;
fi
done
fi


}

# Seperate function due to ability to cancel
make_swap(){

# Ask user to select partition or create swapfile
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelSwpBody" 0 0 7 "$_SelSwpNone" $"-" "$_SelSwpFile" $"-" ${PARTITIONS} 2>${ANSWER} || prep_menu  

if [[ $(cat ${ANSWER}) != "$_SelSwpNone" ]]; then    
PARTITION=$(cat ${ANSWER})

if [[ $PARTITION == "$_SelSwpFile" ]]; then
total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//')
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SelSwpFile " --inputbox "\nM = MB, G = GB\n" 9 30 "${total_memory}M" 2>${ANSWER} || make_swap
m_or_g=$(cat ${ANSWER})

while [[ $(echo ${m_or_g: -1} | grep "M\|G") == "" ]]; do
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SelSwpFile " --msgbox "\n$_SelSwpFile  -| Fehler |- : M = MB, G = GB\n\n" 0 0
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

# prep variables
MOUNT=""
LUKS_NAME=""
LUKS_DEV=""
LUKS_UUID=""
LUKS=0
LVM=0
BTRFS=0

# Warn users that they CAN mount partitions without formatting them!
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --msgbox "$_WarnMount1 '$_FSSkip' $_WarnMount2" 0 0

# LVM Detection. If detected, activate.
lvm_detect

# Ensure partitions are unmounted (i.e. where mounted previously), and then list available partitions
INCLUDE_PART='part\|lvm\|crypt'
umount_partitions
find_partitions

# Identify and mount root
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelRootBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu
PARTITION=$(cat ${ANSWER})
ROOT_PART=${PARTITION}

# Format with FS (or skip)
select_filesystem

# Make the directory and mount. Also identify LUKS and/or LVM
mount_current_partition

# Identify and create swap, if applicable
make_swap

# Extra Step for VFAT UEFI Partition. This cannot be in an LVM container.
if [[ $SYSTEM == "UEFI" ]]; then

dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelUefiBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu  
PARTITION=$(cat ${ANSWER})
UEFI_PART=${PARTITION}

# If it is already a fat/vfat partition...
if [[ $(fsck -N $PARTITION | grep fat) ]]; then
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --yesno "$_FormUefiBody $PARTITION $_FormUefiBody2" 0 0 && mkfs.vfat -F32 ${PARTITION} >/dev/null 2>/tmp/.errlog
else 
mkfs.vfat -F32 ${PARTITION} >/dev/null 2>/tmp/.errlog
fi
check_for_error

# Inform users of the mountpoint options and consequences       
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_MntUefiBody"  0 0 2 \
"/boot" "systemd-boot"\
"/boot/efi" "-" 2>${ANSWER}

[[ $(cat ${ANSWER}) != "" ]] && UEFI_MOUNT=$(cat ${ANSWER}) || prep_menu

mkdir -p ${MOUNTPOINT}${UEFI_MOUNT} 2>/tmp/.errlog
mount ${PARTITION} ${MOUNTPOINT}${UEFI_MOUNT} 2>>/tmp/.errlog
check_for_error
confirm_mount ${MOUNTPOINT}${UEFI_MOUNT}           
fi

# All other partitions
while [[ $NUMBER_PARTITIONS > 0 ]]; do 
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_ExtPartBody" 0 0 7 "Fertig" $"-" ${PARTITIONS} 2>${ANSWER} || prep_menu 
PARTITION=$(cat ${ANSWER})

if [[ $PARTITION == Fertig ]]; then
break;
else
MOUNT=""
select_filesystem

# Ask user for mountpoint. Don't give /boot as an example for UEFI systems!
[[ $SYSTEM == "UEFI" ]] && MNT_EXAMPLES="/home\n/var" || MNT_EXAMPLES="/boot\n/home\n/var"
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart $PARTITON " --inputbox "$_ExtPartBody1$MNT_EXAMPLES\n" 0 0 "/" 2>${ANSWER} || prep_menu
MOUNT=$(cat ${ANSWER})

# loop while the mountpoint specified is incorrect (is only '/', is blank, or has spaces). 
while [[ ${MOUNT:0:1} != "/" ]] || [[ ${#MOUNT} -le 1 ]] || [[ $MOUNT =~ \ |\' ]]; do
# Warn user about naming convention
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Fehler |- " --msgbox "$_ExtErrBody" 0 0
# Ask user for mountpoint again
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart $PARTITON " --inputbox "$_ExtPartBody1$MNT_EXAMPLES\n" 0 0 "/" 2>${ANSWER} || prep_menu
MOUNT=$(cat ${ANSWER})                     
done

# Create directory and mount.
mount_current_partition

# Determine if a seperate /boot is used. 0 = no seperate boot, 1 = seperate non-lvm boot, 
# 2 = seperate lvm boot. For Grub configuration
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
	pacstrap ${MOUNTPOINT} base base-devel btrfs-progs f2fs-tools sudo 2>/tmp/.errlog
	check_for_error
	[[ -e /tmp/vconsole.conf ]] && cp -f /tmp/vconsole.conf ${MOUNTPOINT}/etc/vconsole.conf 2>/tmp/.errlog
	cp -f /etc/pacman.conf ${MOUNTPOINT}/etc/pacman.conf 2>>/tmp/.errlog
	check_for_error
}
uefi_bootloader() {
	check_mount
	arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl" 2>/tmp/.errlog
	check_for_error
	if [[ $SYSTEM == "BIOS" ]]; then		
		if [[ $DEVICE != "" ]]; then
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Grub-install |- " --infobox "...Bitte warten..." 0 0
			pacstrap ${MOUNTPOINT} grub dosfstools 2>/tmp/.errlog
			arch_chroot "grub-install --target=i386-pc --recheck $DEVICE"
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>>/tmp/.errlog
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>>/tmp/.errlog
			check_for_error
		fi
	fi
	if [[ $SYSTEM == "UEFI" ]]; then		
		if [[ $DEVICE != "" ]]; then
			dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " -| Grub-install |- " --infobox "...Bitte warten..." 0 0
			pacstrap ${MOUNTPOINT} grub efibootmgr dosfstools 2>/tmp/.errlog
			arch_chroot "grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=arch_grub --recheck"
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>>/tmp/.errlog
			sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>>/tmp/.errlog
			check_for_error
			arch_chroot "mkdir -p /boot/EFI/boot"
			arch_chroot "cp -r /boot/EFI/arch_grub/grubx64.efi /boot/EFI/boot/bootx64.efi"
		fi
	fi
}
install_network_menu() {
	WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`
	if [[ -n $WIRELESS_DEV ]]; then 
		clear
		pacstrap ${MOUNTPOINT} iw wireless_tools wpa_actiond dialog rp-pppoe 2>/tmp/.errlog
		check_for_error
	fi
#	WIRED_DEV=`ip link | grep "ens\|eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d'`
#	if [[ -n $WIRED_DEV ]]; then arch_chroot "systemctl enable dhcpcd@${WIRED_DEV}.service" ; fi	

	clear
	pacstrap ${MOUNTPOINT} networkmanager network-manager-applet 2>/tmp/.errlog
	arch_chroot "systemctl enable NetworkManager.service && systemctl enable NetworkManager-dispatcher.service" >/tmp/.symlink 2>/tmp/.errlog

	clear
	pacstrap ${MOUNTPOINT} cups system-config-printer ghostscript gsfonts 2>/tmp/.errlog
	arch_chroot "systemctl enable org.cups.cupsd.service" 2>/tmp/.errlog
	check_for_error

	if (dmesg | grep -i "blue" &> /dev/null); then 
		clear
		pacstrap ${MOUNTPOINT} bluez bluez-utils blueman 2>/tmp/.errlog
		arch_chroot "systemctl enable bluetooth.service" 2>/tmp/.errlog
		check_for_error
	fi
}
install_xorg_input() {
	clear
	pacstrap ${MOUNTPOINT} xorg-server xorg-server-utils xorg-xinit xf86-input-keyboard xf86-input-mouse xf86-input-synaptics 2>/tmp/.errlog
	check_for_error
	# now copy across .xinitrc for all user accounts
	user_list=$(ls ${MOUNTPOINT}/home/ | sed "s/lost+found//")
	for i in ${user_list}; do
		cp -f ${MOUNTPOINT}/etc/X11/xinit/xinitrc ${MOUNTPOINT}/home/$i/.xinitrc
		arch_chroot "chown -R ${i}:users /home/${i}"
	done
	install_graphics_menu
}
setup_graphics_card() {
# Save repetition
install_intel(){

pacstrap ${MOUNTPOINT} xf86-video-intel libva-intel-driver intel-ucode 2>/tmp/.errlog
sed -i 's/MODULES=""/MODULES="i915"/' ${MOUNTPOINT}/etc/mkinitcpio.conf

# Intel microcode (Grub, Syslinux and systemd-boot).
# Done as seperate if statements in case of multiple bootloaders.
if [[ -e ${MOUNTPOINT}/boot/grub/grub.cfg ]]; then
dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " grub-mkconfig " --infobox "...Bitte warten..." 0 0
sleep 1
arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>>/tmp/.errlog
fi

# Syslinux
[[ -e ${MOUNTPOINT}/boot/syslinux/syslinux.cfg ]] && sed -i "s/INITRD /&..\/intel-ucode.img,/g" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg

# Systemd-boot
if [[ -e ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf ]]; then
update=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/*.conf)
for i in ${upgate}; do
sed -i '/linux \//a initrd \/intel-ucode.img' ${i}
done
fi

}

# Save repetition
install_ati(){
pacstrap ${MOUNTPOINT} xf86-video-ati 2>/tmp/.errlog
sed -i 's/MODULES=""/MODULES="radeon"/' ${MOUNTPOINT}/etc/mkinitcpio.conf
}

# Main menu. Correct option for graphics card should be automatically highlighted.
NVIDIA=""
VB_MOD=""
GRAPHIC_CARD=""
INTEGRATED_GC="N/A"
GRAPHIC_CARD=$(lspci | grep -i "vga" | sed 's/.*://' | sed 's/(.*//' | sed 's/^[ \t]*//')

# Highlight menu entry depending on GC detected. Extra work is needed for NVIDIA
if 	[[ $(echo $GRAPHIC_CARD | grep -i "nvidia") != "" ]]; then
# If NVIDIA, first need to know the integrated GC
[[ $(lscpu | grep -i "intel\|lenovo") != "" ]] && INTEGRATED_GC="Intel" || INTEGRATED_GC="ATI"

# Second, identity the NVIDIA card and driver / menu entry
if [[ $(dmesg | grep -i 'chipset' | grep -i 'nvc\|nvd\|nve') != "" ]]; then HIGHLIGHT_SUB_GC=4
elif [[ $(dmesg | grep -i 'chipset' | grep -i 'nva\|nv5\|nv8\|nv9'﻿) != "" ]]; then HIGHLIGHT_SUB_GC=5
elif [[ $(dmesg | grep -i 'chipset' | grep -i 'nv4\|nv6') != "" ]]; then HIGHLIGHT_SUB_GC=6
else HIGHLIGHT_SUB_GC=3
fi

# All non-NVIDIA cards / virtualisation
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

# Set NVIDIA driver(s) to install depending on installed kernel(s)
([[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia"
[[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-lts"

clear
pacstrap ${MOUNTPOINT} ${NVIDIA} nvidia-libgl nvidia-utils pangox-compat nvidia-settings 2>/tmp/.errlog
NVIDIA_INST=1
;;
"5") # NVIDIA-340

[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"

# Set NVIDIA driver(s) to install depending on installed kernel(s)
([[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] || [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]]) && NVIDIA="nvidia-340xx"
[[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && NVIDIA="$NVIDIA nvidia-340xx-lts"

clear
pacstrap ${MOUNTPOINT} ${NVIDIA} nvidia-340xx-libgl nvidia-340xx-utils nvidia-settings 2>/tmp/.errlog 
NVIDIA_INST=1
;;
"6") # NVIDIA-304
[[ $INTEGRATED_GC == "ATI" ]] &&  install_ati || install_intel
arch_chroot "pacman -Rdds --noconfirm mesa-libgl mesa"

# Set NVIDIA driver(s) to install depending on installed kernel(s)
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

# Set VB headers to install depending on installed kernel(s)
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

# Create a basic xorg configuration file for NVIDIA proprietary drivers where installed
# if that file does not already exist.
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
	clear
	pacstrap ${MOUNTPOINT} cinnamon 2>/tmp/.errlog
	check_for_error
	clear
	pacstrap ${MOUNTPOINT} bash-completion gamin gksu gnome-icon-theme gnome-keyring gvfs gvfs-afc gvfs-smb polkit poppler python2-xdg ntfs-3g ttf-dejavu xdg-user-dirs xdg-utils xterm 2>/tmp/.errlog
	check_for_error
}
install_dm() {
clear
pacstrap ${MOUNTPOINT} lightdm lightdm-gtk-greeter 2>/tmp/.errlog
arch_chroot "systemctl enable lightdm" 2>/tmp/.errlog
check_for_error
}
security_menu(){
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" ${MOUNTPOINT}/etc/systemd/journald.conf
	sed -i "s/SystemMaxUse.*/#&/g" ${MOUNTPOINT}/etc/systemd/journald.conf
	sed -i "s/#Storage.*\|Storage.*/Storage=none/g" ${MOUNTPOINT}/etc/systemd/coredump.conf
	echo "kernel.dmesg_restrict = 1" > ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf
	dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "-| Protokollierung |-" --infobox "\nFertig!\n\n" 0 0 && sleep 2
}

######################################################################
##                 Main Interfaces       							##
######################################################################

# Preparation
prep_menu() {

if [[ $SUB_MENU != "prep_menu" ]]; then
SUB_MENU="prep_menu"
HIGHLIGHT_SUB=1
else
if [[ $HIGHLIGHT_SUB != 7 ]]; then
HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
fi
fi

dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " _PrepMenuTitle " --menu "_PrepMenuBody" 0 0 7 \
"1" "_VCKeymapTitle" \
"3" "_PrepPartDisk" \
"6" "_PrepMntPart" \
"7" "_Back" 2>${ANSWER}

HIGHLIGHT_SUB=$(cat ${ANSWER})
case $(cat ${ANSWER}) in
"1") set_keymap 
;;
"3") umount_partitions
select_device
create_partitions
;;
"6") mount_partitions
;;        
*) main_menu_online
;;
esac

prep_menu  	

}

# Base Installation
install_base_menu() {

if [[ $SUB_MENU != "install_base_menu" ]]; then
SUB_MENU="install_base_menu"
HIGHLIGHT_SUB=1
else
if [[ $HIGHLIGHT_SUB != 5 ]]; then
HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
fi
fi

dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " _InstBsMenuTitle " --menu "_InstBseMenuBody" 0 0 5 \
"1"	"_PrepMirror" \
"2" "Refresch" \
"3" "_InstBse" \
"4" "_InstBootldr" \
"5" "_Back" 2>${ANSWER}	

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

# Base Configuration
config_base_menu() {

# Set the default PATH variable
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

dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " _ConfBseMenuTitle " --menu "_ConfBseBody" 0 0 8 \
"1" "_ConfBseFstab" \
"2" "_ConfBseHost" \
"3" "_ConfBseSysLoc" \
"4" "_ConfBseTimeHC" \
"5" "_ConfUsrRoot" \
"6" "_ConfUsrNew" \
"7" "_MMRunMkinit" \
"8" "_Back" 2>${ANSWER}	

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

main_menu_online() {

if [[ $HIGHLIGHT != 9 ]]; then
HIGHLIGHT=$(( HIGHLIGHT + 1 ))
fi

dialog --default-item ${HIGHLIGHT} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " _MMTitle " \
--menu "$_MMBody" 0 0 9 \
"1" "_PrepMenuTitle" \
"2" "_InstBsMenuTitle" \
"3" "_ConfBseMenuTitle" \
"4" "_InstGrMenuTitle" \
"5" "_InstNMMenuTitle" \
"6" "_InstMultMenuTitle" \
"7" "_SecMenuTitle" \
"8" "_SeeConfOptTitle" \
"9" "Fertig" 2>${ANSWER}

HIGHLIGHT=$(cat ${ANSWER})

# Depending on the answer, first check whether partition(s) are mounted and whether base has been installed
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
"6") security_menu
;;
*) dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "-| Installer beenden |-" 0 0

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
