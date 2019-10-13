#!/usr/bin/bash

_WelTitle="Welcome to the"
_WelBody="\nThis will help you get $DIST setup on your system.\nHaving GNU/Linux experience is an asset, however we try our best to keep things simple.\n\nIf you are unsure about an option, a default will be listed or\nthe first selected option will be the default (excluding language and timezone).\n\n\nMenu Navigation:\n\n - Select items with the arrow keys or the option number.\n - Use [Space] to toggle options and [Enter] to confirm.\n - Switch between buttons using [Tab] or the arrow keys.\n - Use [Page Up] and [Page Down] to jump whole pages\n - Press the highlighted key of an option to select it.\n"

_PrepBody="\nThis is the menu where you can prepare your system for the install.\n\nTo begin the install you must first have:\n\n  - A root (/) partition mounted (UEFI systems also require a seperate boot partition).\n  - A new user created and the passwords set.\n  - The system configuration finished.\n\nOnce the above requirements are met and you have gone through any optional setup steps you like the install can be started."
_PrepShow="Show lsblk output (optional)"
_PrepPart="Edit partitions (optional)"
_PrepLUKS="LUKS encryption (optional)"
_PrepLVM="Logical volume management (optional)"
_PrepMnt="Mount and format partitions"
_PrepUser="Create user and set passwords"
_PrepConf="Configure system settings"
_PrepWM="Select window manager or desktop (optional)"
_PrepPkg="Select additional packages (optional)"
_PrepChk="Check configuration choices (optional)"
_Install="Start the installation"

_EditBody="\nBefore exiting you can select configuration files to review/change.\n\nIf you need to make other changes with the drives still mounted, use Ctrl-z to pause the installer, when finished type 'fg' and [Enter] or Ctrl-z again to resume the installer."

_TimeZBody="\nThe time zone is used to set the system clock.\n\nSelect your country or continent from the list below"
_TimeSubZBody="\nSelect the nearest city to you or one with the same time zone.\n\nTIP: Pressing the first letter of the city name repeatedly will navigate between entries beggining with that letter."

_MirrorSetup="\nSort the mirrorlist automatically?\n\nTakes longer but gets fastest mirrors.\n"
_MirrorCmd="\nThe command below will be used to sort the mirrorlist, edit if needed.\n"

_WMChoiceBody="\nUse [Space] to toggle available sessions.\n\nFor all sessions a basic package set will be installed for basic compatibilty across sessions. In addition to this extra packages specific to each sessions will also be installed to provide basic functionality most people expect from an environment."

_PackageMenu="\nSelect a category to choose packages from, once finished select the last entery or press [Esc] to return to the main menu."
_PackageBody="\nUse [Space] to toggle packages(s) and press [Enter] to accept the selection.\n\nNOTE: Some packages may already be installed by your desktop environment (if any). Extra packages may also be installed for the selected packages eg. Selecting qutebrowser will also install qt5ct (the Qt5 theme tool) and qt5-styleplugins (for Gtk themes in Qt applications)."

_WMLoginBody="\nSelect which of your session choices to use for the initial login.\n\nYou can be change this later by editing your ~/.xinitrc"

_XMapBody="\nPick your system keymap from the list below\n\nThis is the keymap used once a graphical environment is running (usually Xorg).\n\nSystem default: us"
_LocaleBody="\nLocale determines the system language and currency formats.\n\nThe format for locale names is languagecode_COUNTRYCODE\n\neg. en_US is: english United States\n    en_GB is: english Great Britain"

_CMapBody="\nSelect console keymap, the console is the tty shell you reach before starting a graphical environment (usually Xorg).\n\nIts keymap is seperate from the one used by the graphical environments, though many do use the same such as 'us' English.\n\nSystem default: us"

_HostNameBody="\nEnter a hostname for the new system.\n\nA hostname is used to identify systems on the network.\n\nIt's restricted to alphanumeric characters (a-z, A-Z, 0-9).\nIt can contain hyphens (-) BUT NOT at the beggining or end."

_RootBody="--- Enter root password (empty uses the password entered above) ---"
_UserBody="\nEnter a name and password for the new user account.\n\nThe name must not use capital letters, contain any periods (.), end with a hyphen (-), or include any colons (:)\n\nNOTE: Use the [Up] and [Down] arrows to switch between input fields, [Tab] to toggle between input fields and the buttons, and [Enter] to accept."

_MntBody="\nUse [Space] to toggle mount options from below, press [Enter] when done to confirm selection.\n\nNot selecting any and confirming will run an automatic mount."
_WarnMount="\nIMPORTANT: Please choose carefully during mounting and formatting.\n\nPartitions can be mounted without formatting by selecting skip during mounting, useful for extra or already formatted partitions.\n\nThe exception to this is the root (/) partition, it needs to be formatted before install to ensure system stability.\n"

_DevSelBody="\nSelect a device to use from the list below.\n\nDevices (/dev) are the available drives on the system. /sda, /sdb, /sdc ..."

_ExtPartBody="\nYou can now select additional partitions you want mounted, once choosen you will be asked to enter a mountpoint.\n\nSelect 'done' to finish the mounting step and return to the main menu."
_ExtPartBody1="\nWhere do you want the partition mounted?\n\nEnsure the name begins with a slash (/).\nExamples include: /usr, /home, /var, etc."

_PartBody="\nFull device auto partitioning is available for beginners otherwise cfdisk is recommended.\n\n  - All systems will require a root partition (8G or greater).\n  - UEFI and BIOS using LUKS without LVM will require a boot partition (100-512M)."

_PartBody1="\nWARNING: ALL data on"
_PartBody2="will be destroyed and the following partitions will be created\n\n- A vfat/fat32 boot partition with boot flags enabled (512M)\n- An ext4 partition using all remaining space"
_PartBody3="\n\nDo you want to continue?\n"
_PartWipeBody="will be destroyed using 'wipe -Ifre'.\n\nThis is ONLY intended for use on devices before sale or disposal to reliably destroy the data beyond recovery. This is NOT for devices you intend to continue using.\nThe wiping process can take a long time depending on the size and speed of the drive.\n\nDo you still want to continue?\n"

_SelRootBody="\nSelect the root (/) partition, this is where $DIST will be installed."
_SelUefiBody="\nSelect the EFI boot partition (/boot), required for UEFI boot.\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as vfat/fat32 if not already."
_SelBiosBody="\nDo you want to use a separate boot partition? (optional)\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as ext3/4 if not already."
_SelBiosLuksBody="\nSelect the boot partition (/boot), required for LUKS.\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as ext3/4 if not already."
_FormBootBody="is already formatted correctly.\n\nFor a clean install, previously existing partitions should be reformatted, however this removes ALL data (bootloaders) on the partition so choose carefully.\n\nDo you want to reformat the partition?\n"

_SelSwpErr="\nSwap Setup Error: Must be 1(M|G) or greater, and can only contain whole numbers\n\nSize Entered:"
_SelSwpSize="\nEnter the size of the swapfile in megabytes (M) or gigabytes (G).\n\neg. 100M will create a 100 megabyte swapfile, while 10G will create a 10 gigabyte swapfile.\n\nFor ease of use and as an example it is filled in to match the size of your system memory (RAM).\n\nMust be greater than 1, contain only whole numbers, and end with either M or G."

# LUKS / DM-Crypt / Encryption
_LuksMenuBody="\nDevices and volumes encrypted using dm_crypt cannot be accessed or seen without first being unlocked."
_LuksMenuBody2="\n\nA seperate boot partition without encryption or logical volume management (LVM) is required (unless using BIOS Grub)."
_LuksMenuBody3="\n\nAutomatic uses default encryption settings, and is recommended for beginners, otherwise cypher and key size parameters may be entered manually."
_LuksOpenBody="\nEnter a name and password for the encrypted device.\n\nIt is not necessary to prefix the name with /dev/mapper/,an example has been provided."
_LuksEncrypt="Basic LUKS Encryption"
_LuksEncryptAdv="Advanced LUKS Encryption"
_LuksOpen="Open Encrypted Partition"
_LuksEncryptBody="\nSelect the partition you want to encrypt."
_LuksEncryptSucc="\nDone! encrypted partition opened and ready for mounting.\n"
_LuksPartErrBody="\nA minimum of two partitions are required for encryption:\n\n 1. root (/) - standard or LVM.\n 2. boot (/boot) - standard (unless using LVM on BIOS systems).\n"
_LuksCreateWaitBody="\nCreating encrypted partition:"
_LuksOpenWaitBody="\nOpening encrypted partition:"
_LuksWaitBody2="\n\nDevice or volume used:"
_LuksCipherKey="Once the specified flags have been amended, they will automatically be used with the 'cryptsetup -q luksFormat /dev/...' command.\n\nNOTE: Do not specify any additional flags such as -v (--verbose) or -y (--verify-passphrase)."

_LvmMenu="\nLogical volume management (LVM) allows 'virtual' hard drives (volume groups) and partitions (logical volumes) to be created from existing device partitions.\n\nA volume group must be created first, then one or more logical volumes within it.\n\nLVM can also be used with an encrypted partition to create multiple logical volumes (e.g. root and home) within it."
_LvmNew="Create VG and LV(s)"
_LvmDel="Delete existing VG(s)"
_LvmDelAll="Delete all VGs, LVs, and PVs"
_LvmDetBody="\nExisting logical volume management (LVM) detected.\n\nActivating...\n"
_LvmNameVgBody="\nEnter the name of the volume group (VG) to create.\n\nThe VG is the new virtual device that will be created from the partition(s) selected."
_LvmPvSelBody="\nSelect the partition(s) to use for the physical volume (PV)."
_LvmPvConfBody1="\nConfirm creation of volume group:"
_LvmPvConfBody2="with the following partition(s):"
_LvmPvActBody1="\nCreating and activating volume group:"
_LvmLvNumBody1="\nSelect the number of logical volumes (LVs) to create in:"
_LvmLvNumBody2="\nThe last (or only) logical volume will automatically use all remaining space in the volume group."
_LvmLvNameBody1="\nEnter the name of the logical volume (LV) to create.\n\nThis is like setting a name or label for a partition.\n"
_LvmLvNameBody2="\nNOTE: This LV will use up all remaining space in the volume group"
_LvmLvSizeBody1="remaining"
_LvmLvSizeBody2="\nEnter the size of the logical volume (LV) in megabytes (M) or gigabytes (G). For example, 100M will create a 100 megabyte LV. 10G will create a 10 gigabyte LV.\n"
_LvmCompBody="\nDone! all logical volumes have been created for the volume group.\n\nDo you want to view the device tree for the new LVM scheme?\n"
_LvmDelQ="\nConfirm deletion of volume group(s) and logical volume(s).\n\nDeleting a volume group, will delete all logical volumes within as well.\n"
_LvmSelVGBody="\nSelect volume group to delete.\n\nAll logical volumes within will also be deleted."

_LvmVGErr="\nNo volume groups found."
_LvmNameVgErr="\nInvalid name entered.\n\nThe volume group name may be alpha-numeric, but may not contain spaces, start with a '/', or already be in use.\n"
_LvmPartErrBody="\nThere are no viable partitions available to use for LVM, a minimum of one is required.\n\nIf LVM is already in use, deactivating it will allow the partition(s) to be used again.\n"
_LvmLvNameErrBody="\nInvalid name entered.\n\nThe logical volume (LV) name may be alpha-numeric, but may not contain spaces or be preceded with a '/'\n"
_LvmLvSizeErrBody="\nInvalid value Entered.\n\nMust be a numeric value with 'M' (megabytes) or 'G' (gigabytes) at the end.\n\neg. 400M, 10G, 250G, etc...\n\nThe value may also not be equal to or greater than the remaining size of the volume group.\n"

_ErrTitle="Installation Error"
_ExtErrBody="\nCannot mount partition due to a problem with the mountpoint.\n\nEnsure it begins with a slash (/) followed by atleast one character.\n"
_PartErrBody="\nYou need create the partiton(s) first.\n\n\nBIOS systems require at least one partition (ROOT).\n\nUEFI systems require at least two (ROOT and EFI).\n"

#!/usr/bin/bash

# vim:fdm=marker:fmr={,}
# shellcheck disable=2154

# This program is free software, provided under the GNU GPL
# Written by Nathaniel Maia for use in Archlabs
# Some ideas and code reworked from other resources
# AIF, Cnichi, Calamares, Arch Wiki.. Credit where credit is due

VER="2.0.6"      # version
DIST="ArchLabs"  # distributor
MNT="/mnt"       # mountpoint

# bulk default values {

ROOT_PART=""      # root partition
BOOT_PART=""      # boot partition
BOOT_DEV=""       # device used for BIOS grub install
BOOTLDR=""        # bootloader selected
EXMNT=""          # holder for additional partitions while mounting
EXMNTS=""         # when an extra partition is mounted append it's info
SWAP_PART=""      # swap partition or file path
SWAP_SIZE=""      # when using a swapfile use this size
NEWUSER=""        # username for the primary user
USER_PASS=""      # password for the primary user
ROOT_PASS=""      # root password
LOGIN_WM=""       # default login session
LOGIN_TYPE=""     # login manager can be lightdm or xinit
INSTALL_WMS=""    # space separated list of chosen wm/de
KERNEL=""         # can be linux, linux-lts, linux-zen, or linux-hardened
MYSHELL=""        # login shell for root and the primary user
LOGINRC=""        # login shell rc file
PACKAGES=""       # list of all packages to install including WM_PKGS
USER_PKGS=""      # packages selected by the user during install
WM_PKGS=""        # full list of packages added during wm/de choice
HOOKS="shutdown"  # list of additional HOOKS to add in /etc/mkinitcpio.conf
FONT="ter-i16n"   # font used in the linux console
UCODE=""          # cpu manufacturer microcode filename (if any)

LUKS=""           # empty when not using luks encryption
LUKS_DEV=""       # boot parameter string for LUKS
LUKS_PART=""      # partition used for encryption
LUKS_PASS=""      # encryption password
LUKS_UUID=""      # encrypted partition UUID
LUKS_NAME=""      # name used for encryption

LVM=""            # empty when not using lvm
VGROUP_MB=0       # available space in volume group
LVM_PARTS=()      # partitions used for volume group

WARN=false        # issued mounting/partitioning warning
SEP_BOOT=false    # separate boot partition for BIOS
AUTOLOGIN=false   # enable autologin for xinit
CONFIG_DONE=false # basic configuration is finished
BROADCOM_WL=false # fixes for broadcom cards eg. BCM4352
CHECKED_NET=false # have we checked the network connection already

AUTO_ROOT_PART="" # root value from auto partition
AUTO_BOOT_PART="" # boot value from auto partition
FORMATTED=""      # partitions we formatted and should allow skipping

# baseline
BASE_PKGS="archlabs-scripts archlabs-skel-base archlabs-themes archlabs-dARK archlabs-icons archlabs-wallpapers "
BASE_PKGS+="base-devel xorg xorg-drivers sudo git gvfs gtk3 gtk-engines gtk-engine-murrine pavucontrol tumbler "
BASE_PKGS+="playerctl ffmpeg gstreamer libmad libmatroska gst-libav gst-plugins-base gst-plugins-good"

# extras for window managers
WM_BASE_PKGS="arandr archlabs-networkmanager-dmenu xdg-user-dirs nitrogen polkit-gnome volumeicon xclip exo "
WM_BASE_PKGS+="xdotool compton wmctrl gnome-keyring dunst feh gsimplecal xfce4-power-manager xfce4-settings laptop-detect"

SEL=0                                 # currently selected menu item
ERR="/tmp/errlog"                     # error log used internally
DBG="/tmp/debuglog"                   # debug log when passed -d
RUN="/run/archiso/bootmnt/arch/boot"  # path for live /boot
BT="$DIST Installer - v$VER"          # backtitle used for dialogs
VM="$(dmesg | grep -i "hypervisor")"  # is the system a vm

# }

# giant ugly container :P {

# amount of RAM in the system in Mb
SYS_MEM="$(awk '/MemTotal/ {
    print int($2 / 1024)"M"
}' /proc/meminfo)"

# parsed string of locales from /etc/locale.gen
LOCALES="$(awk '/\.UTF-8/ {
    gsub(/# .*|#/, "")
    if ($1) {
        print $1 " -"
    }
}' /etc/locale.gen)"

# parsed string of linux console keyboard mappings
CMAPS="$(find /usr/share/kbd/keymaps -name '*.map.gz' | awk '{
    gsub(/\.map\.gz|.*\//, "")
    print $1 " -"
}' | sort)"

# make sure these are defined for some dialog size calculation
[[ $LINES ]] || LINES=$(tput lines)
[[ $COLUMNS ]] || COLUMNS=$(tput cols)
SHL=$((LINES - 20))

# various associative arrays
# {

# command used to install each bootloader
declare -A BCMDS=(
[refind-efi]="refind-install"
[grub]="grub-install --recheck --force"
[syslinux]="syslinux-install_update -i -a -m"
[systemd-boot]="bootctl --path=/boot install"
)

# match the wm name with the actual session name used for xinit
declare -A WM_SESSIONS=(
[dwm]='dwm'
[i3-gaps]='i3'
[bspwm]='bspwm'
[plasma]='startkde'
[xfce4]='startxfce4'
[gnome]='gnome-session'
[fluxbox]='startfluxbox'
[openbox]='openbox-session'
[cinnamon]='cinnamon-session'
)

# additional packages installed for each wm/de
declare -A WM_EXT=(
[gnome]=""
[fluxbox]="menumaker"
[plasma]="kdebase-meta"
[bspwm]="sxhkd archlabs-skel-bspwm rofi archlabs-polybar"
[i3-gaps]="i3status perl-anyevent-i3 archlabs-skel-i3-gaps rofi archlabs-polybar"
[openbox]="obconf archlabs-skel-openbox jgmenu archlabs-polybar tint2 conky rofi lxmenu-data"
[xfce4]="xfce4-goodies xfce4-pulseaudio-plugin network-manager-applet volumeicon rofi archlabs-skel-xfce4"
)

# files the user can edit during the final stage of install
declare -A EDIT_FILES=(
[login]=""
[fstab]="/etc/fstab"
[sudoers]="/etc/sudoers"
[crypttab]="/etc/crypttab"
[pacman]="/etc/pacman.conf"
[console]="/etc/vconsole.conf"
[mkinitcpio]="/etc/mkinitcpio.conf"
[hostname]="/etc/hostname /etc/hosts"
[bootloader]="/boot/loader/entries/$DIST.conf"
[locale]="/etc/locale.conf /etc/default/locale"
[keyboard]="/etc/X11/xorg.conf.d/00-keyboard.conf /etc/default/keyboard"
)

# PKG_EXT: if you add a package to $PACKAGES in any dialog
#          and it uses/requires some additional packages,
#          you can add them here to keep it simple: [package]="extra"
#          duplicates are removed with `uniq` before install
declare -A PKG_EXT=(
[vlc]="qt4"
[mpd]="mpc"
[mupdf]="mupdf-tools"
[qt5ct]="qt5-styleplugins"
[vlc]="qt5ct qt5-styleplugins"
[zathura]="zathura-pdf-poppler"
[noto-fonts]="noto-fonts-emoji"
[cairo-dock]="cairo-dock-plug-ins"
[qutebrowser]="qt5ct qt5-styleplugins"
[qbittorrent]="qt5ct qt5-styleplugins"
[transmission-qt]="qt5ct qt5-styleplugins"
[kdenlive]="kdebase-meta dvdauthor frei0r-plugins breeze breeze-gtk qt5ct qt5-styleplugins"
)

# mkfs command to format a partition as a given file system
declare -A FS_CMDS=(
[f2fs]="mkfs.f2fs"
[jfs]="mkfs.jfs -q"
[xfs]="mkfs.xfs -f"
[ntfs]="mkfs.ntfs -q"
[ext2]="mkfs.ext2 -q"
[ext3]="mkfs.ext3 -q"
[ext4]="mkfs.ext4 -q"
[vfat]="mkfs.vfat -F32"
[nilfs2]="mkfs.nilfs2 -q"
[reiserfs]="mkfs.reiserfs -q"
)

# mount options for a given file system
declare -A FS_OPTS=(
[vfat]=""
[ntfs]=""
[ext2]=""
[ext3]=""
[jfs]="discard - off errors=continue - off errors=panic - off nointegrity - off"
[reiserfs]="acl - off nolog - off notail - off replayonly - off user_xattr - off"
[ext4]="discard - off dealloc - off nofail - off noacl - off relatime - off noatime - off nobarrier - off nodelalloc - off"
[xfs]="discard - off filestreams - off ikeep - off largeio - off noalign - off nobarrier - off norecovery - off noquota - off wsync - off"
[nilfs2]="discard - off nobarrier - off errors=continue - off errors=panic - off order=relaxed - off order=strict - off norecovery - off"
[f2fs]="data_flush - off disable_roll_forward - off disable_ext_identify - off discard - off fastboot - off flush_merge - off inline_xattr - off inline_data - off inline_dentry - off no_heap - off noacl - off nobarrier - off noextent_cache - off noinline_data - off norecovery - off"
)
# }

# }

main()
{
    (( SEL < 11 )) && (( SEL++ ))
    tput civis
    SEL=$(dialog --cr-wrap --stdout --backtitle "$BT" \
        --title " Prepare " --default-item $SEL \
        --cancel-label 'Exit' --menu "$_PrepBody" 0 0 0 \
        "1"  "$_PrepShow" \
        "2"  "$_PrepPart" \
        "3"  "$_PrepLUKS" \
        "4"  "$_PrepLVM" \
        "5"  "$_PrepMnt" \
        "6"  "$_PrepUser" \
        "7"  "$_PrepConf" \
        "8"  "$_PrepWM" \
        "9"  "$_PrepPkg" \
        "10" "$_PrepChk" \
        "11" "$_Install")

    [[ $WARN != true && $SEL =~ (2|5) ]] && { WARN=true; msgbox "Prepare" "$_WarnMount"; }

    case $SEL in
        1) dev_tree ;;
        2) part_menu || (( SEL-- )) ;;
        3) luks_menu || (( SEL-- )) ;;
        4) lvm_menu || (( SEL-- )) ;;
        5) mount_menu || (( SEL-- )) ;;
        6) prechecks 0 && { select_mkuser || (( SEL-- )); } ;;
        7) prechecks 1 && { select_config || (( SEL-- )); } ;;
        8) prechecks 2 && { select_sessions || (( SEL-- )); } ;;
        9) prechecks 2 && { select_packages || (( SEL-- )); } ;;
        10) prechecks 2 && show_cfg ;;
        11) prechecks 2 && install_main ;;
        *) yesno "Exit" "\nUnmount partitions (if any) and exit the installer?\n" && die
    esac
}

###############################################################################
# selection menus

show_cfg()
{
    local cmd="${BCMDS[$BOOTLDR]}"
    [[ $BOOT_PART ]] && local mnt="/boot" || local mnt="none"
    local pkgs="${USER_PKGS# }"
    pkgs="${pkgs% }"
    pkgs="${pkgs% } ${PACKAGES# }"
    pkgs="${pkgs//  / }"
    pkgs="${pkgs//  / }"
    [[ $INSTALL_WMS == *dwm* ]] && pkgs="dwm st dmenu ${pkgs# }"
    pkgs="${pkgs# }"
    pkgs="${pkgs% }"
    pkgs="${pkgs//  / }"
    msgbox "Show Configuration" "

---------- PARTITION CONFIGURATION ------------

  Root:  ${ROOT_PART:-none}
  Boot:  ${BOOT_PART:-${BOOT_DEV:-none}}

  Swap:  ${SWAP_PART:-none}
  Size:  ${SWAP_SIZE:-none}

  LVM:   ${LVM:-none}
  LUKS:  ${LUKS:-none}

  Extra: ${EXMNTS:-${EXMNT:-none}}
  Hooks: ${HOOKS:-none}


---------- BOOTLOADER CONFIGURATION -----------

  Bootloader: ${BOOTLDR:-none}
  Mountpoint: ${mnt:-none}
  Command:    ${cmd:-none}


------------ SYSTEM CONFIGURATION -------------

  Locale:   ${LOCALE:-none}
  Keymap:   ${KEYMAP:-none}
  Hostname: ${HOSTNAME:-none}
  Timezone: ${ZONE:-none}/${SUBZONE:-none}


------------ USER CONFIGURATION --------------

  User:         ${NEWUSER:-none}
  Shell:        ${MYSHELL:-none}
  Session:      ${LOGIN_WM:-none}
  Autologin:    ${AUTOLOGIN:-none}
  Login Method: ${LOGIN_TYPE:-none}


------------ PACKAGES AND MIRRORS -------------

  Kernel:   ${KERNEL:-none}
  Sessions: ${INSTALL_WMS:-none}
  Mirrors:  ${MIRROR_CMD:-none}
  Packages: $(print4 "${pkgs:-none}")
"
}

select_login()
{
    LOGIN_TYPE="$(menubox "Login Management" "\nSelect which login management to use." \
        "xinit"   "Console login without a display manager" \
        "lightdm" "Lightweight display manager with a gtk greeter")"

    if [[ $LOGIN_TYPE == "" ]]; then
        return 1
    elif [[ $LOGIN_TYPE == 'lightdm' ]]; then
        WM_PKGS+=" lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice"
        EDIT_FILES[login]="/etc/lightdm/lightdm.conf /etc/lightdm/lightdm-gtk-greeter.conf"
        AUTOLOGIN=false
    else
        if [[ $WM_NUM -eq 1 ]]; then
            LOGIN_WM="${WM_SESSIONS[$INSTALL_WMS]}"
        else
            LOGIN_WM="$(menubox "Login Management" "$_WMLoginBody" $LOGIN_CHOICES)" || return 1
            LOGIN_WM="${WM_SESSIONS[$LOGIN_WM]}"
        fi

        local msg="\nDo you want autologin enabled for $NEWUSER?\n\nPicking yes will create the following files:\n\n  - /home/$NEWUSER/$LOGINRC (run startx when logging in on tty1)\n  - /etc/systemd/system/getty@tty1.service.d/autologin.conf (login $NEWUSER without password)\n\nTo disable autologin remove these files.\n"

        yesno "Autologin" "$msg" && AUTOLOGIN=true || AUTOLOGIN=false

        PACKAGES="${PACKAGES// lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice/}"
        WM_PKGS="${WM_PKGS// lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice/}"
        WM_PKGS+=" xorg-xinit"
        EDIT_FILES[login]="/home/$NEWUSER/.xinitrc /home/$NEWUSER/.xprofile"
    fi
}

select_config()
{
    tput civis
    MYSHELL="$(menubox "Shell" "\nChoose a shell for the new user and root." \
        '/usr/bin/zsh' '-' '/bin/bash' '-' '/usr/bin/mksh' '-')"

    case $MYSHELL in
        "/bin/bash") LOGINRC=".bash_profile" ;;
        "/usr/bin/mksh") LOGINRC=".profile" ;;
        "/usr/bin/zsh") LOGINRC=".zprofile" ;;
        *) return 1 ;;
    esac

    tput cnorm
    HOSTNAME="$(getinput "Hostname" "$_HostNameBody" "${DIST,,}")"
    [[ $HOSTNAME ]] || return 1
    tput civis
    LOCALE="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " Locale " --menu "$_LocaleBody" 0 0 $SHL $LOCALES)"
    [[ $LOCALE ]] || return 1
    select_timezone || return 1
    KERNEL="$(menubox "Kernel" "\nSelect a kernel to use for the install." \
        'linux' 'Vanilla Linux kernel and modules, with a few patches applied.' \
        'linux-lts' 'Long-term support (LTS) Linux kernel and modules.' \
        'linux-zen' 'A collaborative effort of kernel hackers to provide the best Linux kernel for everyday systems' \
        'linux-hardened' 'A security-focused Linux kernel with hardening patches to mitigate kernel and userspace exploits')"

    [[ $KERNEL ]] || return 1
    select_mirrorcmd || return 1
    CONFIG_DONE=true
    return 0
}

select_mkuser()
{
    local v="" u="" p="" p2="" rp="" rp2="" err=0
    local l=$((${#_RootBody} + 1))

    while true; do
        tput cnorm
        v="$(dialog --stdout --no-cancel --separator ';:~:;' \
            --ok-label "Submit" --backtitle "$BT" --title " User Creation " \
            --insecure --mixedform "$_UserBody" 0 0 0 \
            "Username:"  1 1 "$u" 1 11 $COLUMNS 0 0 \
            "Password:"  2 1 ""   2 11 $COLUMNS 0 1 \
            "Password2:" 3 1 ""   3 12 $COLUMNS 0 1 \
            "$_RootBody" 6 1 ""   6 $l $COLUMNS 0 2 \
            "Password:"  8 1 ""   8 11 $COLUMNS 0 1 \
            "Password2:" 9 1 ""   9 12 $COLUMNS 0 1)"

        err=$?
        (( err == 0 )) || break

        u="$(awk -F';:~:;' '{print $1}' <<< "$v")"
        p="$(awk -F';:~:;' '{print $2}' <<< "$v")"
        p2="$(awk -F';:~:;' '{print $3}' <<< "$v")"
        rp="$(awk -F';:~:;' '{print $5}' <<< "$v")"
        rp2="$(awk -F';:~:;' '{print $6}' <<< "$v")"

        # root passwords empty, so use the user passwords
        [[ $rp == "" && $rp2 == "" ]] && { rp="$p"; rp2="$p2"; }

        # make sure a username was entered and that the passwords match
        if [[ ${#u} -eq 0 || $u =~ \ |\' || $u =~ [^a-z0-9] ]]; then
            msgbox "Invalid Username" "\nIncorrect user name.\n\nPlease try again.\n"; u=""
        elif [[ $p == "" ]]; then
            msgbox "Empty Password" "\nThe user password cannot be left empty.\n\nPlease try again.\n"
        elif [[ "$p" != "$p2" ]]; then
            msgbox "Password Mismatch" "\nThe user passwords do not match.\n\nPlease try again.\n"
        elif [[ "$rp" != "$rp2" ]]; then
            msgbox "Password Mismatch" "\nThe root passwords do not match.\n\nPlease try again.\n"
        else
            NEWUSER="$u"
            USER_PASS="$p"
            ROOT_PASS="$rp"
            break
        fi
    done
    return $err
}

select_keymap()
{
    tput civis
    KEYMAP="$(dialog --cr-wrap --stdout --backtitle "$BT" \
        --title " Keyboard Layout " --menu "$_XMapBody" 0 0 $SHL \
        'us' 'English'    'cm'    'English'     'gb' 'English'    'au' 'English'    'gh' 'English' \
        'za' 'English'    'ng'    'English'     'ca' 'French'     'cd' 'French'     'gn' 'French' \
        'tg' 'French'     'fr'    'French'      'de' 'German'     'at' 'German'     'ch' 'German' \
        'es' 'Spanish'    'latam' 'Spanish'     'br' 'Portuguese' 'pt' 'Portuguese' 'ma' 'Arabic' \
        'sy' 'Arabic'     'ara'   'Arabic'      'ua' 'Ukrainian'  'cz' 'Czech'      'ru' 'Russian' \
        'sk' 'Slovak'     'nl'    'Dutch'       'it' 'Italian'    'hu' 'Hungarian'  'cn' 'Chinese' \
        'tw' 'Taiwanese'  'vn'    'Vietnamese'  'kr' 'Korean'     'jp' 'Japanese'   'th' 'Thai' \
        'la' 'Lao'        'pl'    'Polish'      'se' 'Swedish'    'is' 'Icelandic'  'fi' 'Finnish' \
        'dk' 'Danish'     'be'    'Belgian'     'in' 'Indian'     'al' 'Albanian'   'am' 'Armenian' \
        'bd' 'Bangla'     'ba'    'Bosnian'     'bg' 'Bulgarian'  'dz' 'Berber'     'mm' 'Burmese' \
        'hr' 'Croatian'   'gr'    'Greek'       'il' 'Hebrew'     'ir' 'Persian'    'iq' 'Iraqi' \
        'af' 'Afghani'    'fo'    'Faroese'     'ge' 'Georgian'   'ee' 'Estonian'   'kg' 'Kyrgyz' \
        'kz' 'Kazakh'     'lt'    'Lithuanian'  'mt' 'Maltese'    'mn' 'Mongolian'  'ro' 'Romanian' \
        'no' 'Norwegian'  'rs'    'Serbian'     'si' 'Slovenian'  'tj' 'Tajik'      'lk' 'Sinhala' \
        'tr' 'Turkish'    'uz'    'Uzbek'       'ie' 'Irish'      'pk' 'Urdu'       'mv' 'Dhivehi' \
        'np' 'Nepali'     'et'    'Amharic'     'sn' 'Wolof'      'ml' 'Bambara'    'tz' 'Swahili' \
        'ke' 'Swahili'    'bw'    'Tswana'      'ph' 'Filipino'   'my' 'Malay'      'tm' 'Turkmen' \
        'id' 'Indonesian' 'bt'    'Dzongkha'    'lv' 'Latvian'    'md' 'Moldavian' 'mao' 'Maori' \
        'by' 'Belarusian' 'az'    'Azerbaijani' 'mk' 'Macedonian' 'kh' 'Khmer'     'epo' 'Esperanto' \
        'me' 'Montenegrin')"

    [[ $KEYMAP ]] || return 1
    if [[ $CMAPS == *"$KEYMAP"* ]]; then
        CMAP="$KEYMAP"
    else
        CMAP="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " Console Keymap " --menu "$_CMapBody" 0 0 $SHL $CMAPS)"
        [[ $CMAP ]] || return 1
    fi

    if [[ $DISPLAY && $TERM != 'linux' ]]; then
        setxkbmap $KEYMAP >/dev/null 2>&1
    else
        loadkeys $CMAP >/dev/null 2>&1
    fi

    return 0
}

select_timezone()
{
    local f="/usr/share/zoneinfo/zone.tab" err=0

    declare -A subz
    for i in America Australia Asia Atlantic Africa Europe Indian Pacific Arctic Antarctica; do
        subz[$i]="$(awk '/'"$i"'\// {gsub(/'"$i"'\//, ""); print $3, $1}' $f | sort)"
    done

    while true; do
        tput civis
        ZONE="$(menubox "Timezone" "$_TimeZBody" \
            'America' '-' 'Australia' '-' 'Asia' '-' 'Atlantic' '-' 'Africa' '-' \
            'Europe' '-' 'Indian' '-' 'Pacific' '-' 'Arctic' '-' 'Antarctica' '-')"

        [[ $ZONE ]] || { err=1; break; }
        SUBZONE="$(dialog --cr-wrap --stdout --backtitle "$BT" \
            --title " Timezone " --menu "$_TimeSubZBody" 0 0 $SHL ${subz[$ZONE]})"

        [[ $SUBZONE ]] || { err=1; break; }
        yesno "Timezone" "\nConfirm time zone: $ZONE/$SUBZONE\n" && break
    done

    return $err
}

select_sessions()
{
    LOGIN_CHOICES=""

    tput civis
    INSTALL_WMS="$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
        --title " Sessions " --checklist "$_WMChoiceBody\n" 0 0 0 \
        "i3-gaps"  "A fork of i3wm with more features including gaps" off \
        "openbox"  "A lightweight, powerful, and highly configurable stacking wm" off \
        "bspwm"    "A tiling wm that represents windows as the leaves of a binary tree" off \
        "dwm"      "A fork of dwm, with more layouts and features" off \
        "fluxbox"  "A lightweight and highly-configurable window manager" off \
        "gnome"    "A desktop environment that aims to be simple and easy to use" off \
        "cinnamon" "A desktop environment combining traditional desktop with modern effects" off \
        "plasma"   "A kde software project currently comprising a full desktop environment" off \
        "xfce4"    "A lightweight and modular desktop environment based on gtk+2/3" off)"

    [[ $INSTALL_WMS ]] || return 1

    WM_NUM=$(awk '{print NF}' <<< "$INSTALL_WMS")
    WM_PKGS="${INSTALL_WMS/dwm/}"   # remove dwm from package list
    WM_PKGS="${WM_PKGS//  / }"  # remove double spaces
    WM_PKGS="${WM_PKGS# }"      # remove leading space

    for wm in $INSTALL_WMS; do
        LOGIN_CHOICES+="$wm - "
        [[ ${WM_EXT[$wm]} && $WM_PKGS != *"${WM_EXT[$wm]}"* ]] && WM_PKGS+=" ${WM_EXT[$wm]}"
    done

    select_login || return 1

    # add unique wm packages to main package list
    for i in $WM_PKGS; do
        [[ $PACKAGES == *$i* ]] || PACKAGES+=" ${WM_PKGS# }"
    done

    return 0
}

select_packages()
{
    local cur=0 b="" e="" f="" t="" m="" ml="" p="" v="" fn="" to="" s="" x=""

    while true; do
        (( cur < 13 )) && (( cur++ ))

        tput civis
        cur=$(dialog --cr-wrap --stdout --backtitle "$BT" \
            --title " Packages " --default-item $cur \
            --menu "$_PackageMenu" 0 0 0 \
            1 "Web Browsers" \
            2 "Text Editors" \
            3 "File Managers" \
            4 "Terminal Emulators" \
            5 "Music & Video Players" \
            6 "Chat & Mail Clients" \
            7 "Office & Professional" \
            8 "Image & PDF Viewers" \
            9 "Additional Fonts" \
            10 "Torrent Clients" \
            11 "System Management" \
            12 "Miscellaneous" \
            13 "Return to main menu")

        [[ $cur && $cur -lt 13 ]] || break

        case $cur in
            1) b="$(pkg_browsers)" ;;
            2) e="$(pkg_editors)" ;;
            3) f="$(pkg_files)" ;;
            4) t="$(pkg_terms)" ;;
            5) m="$(pkg_media)" ;;
            6) ml="$(pkg_mail)" ;;
            7) p="$(pkg_prof)" ;;
            8) v="$(pkg_viewers)" ;;
            9) fn="$(pkg_fonts)" ;;
            10) to="$(pkg_torrent)" ;;
            11) s="$(pkg_sys)" ;;
            12) x="$(pkg_extra)" ;;
        esac

        # add all to the user package list regardless of what was picked
        USER_PKGS="$b $e $f $t $m $ml $p $v $fn $to $s $x"
    done

    for i in $USER_PKGS; do
        [[ ${PKG_EXT[$i]} && $USER_PKGS != *"${PKG_EXT[$i]}"* ]] && USER_PKGS="${USER_PKGS% } ${PKG_EXT[$i]}"
    done

    USER_PKGS="${USER_PKGS//  / }"
    USER_PKGS="${USER_PKGS//  / }"
    USER_PKGS="${USER_PKGS# }"
    USER_PKGS="${USER_PKGS% }"
    return 0
}

select_mirrorcmd()
{
    local c
    local key="5f29642060ab983b31fdf4c2935d8c56"

    if hash reflector >/dev/null 2>&1; then
        MIRROR_CMD="reflector --score 100 -l 50 -f 5 --sort rate --verbose"
        yesno "Mirrorlist" "$_MirrorSetup" && return 0

        c="$(json 'country_name' "$(json 'ip' "check&?access_key=${key}&fields=ip")?access_key=${key}&fields=country_name")"
        MIRROR_CMD="reflector --country $c --fastest 5 --sort rate --verbose"

        tput cnorm
        MIRROR_CMD="$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
            --title " Mirrorlist " --inputbox "$_MirrorCmd\n
      --score n     Limit the list to the n servers with the highest score.
      --latest n    Limit the list to the n most recently synchronized servers.
      --fastest n   Return the n fastest mirrors that meet the other criteria.
      --sort {age,rate,country,score,delay}

            'age':      Last server synchronization;
            'rate':     Download rate;
            'country':  Server location;
            'score':    MirrorStatus score;
            'delay':    MirrorStatus delay.\n" 0 0 "$MIRROR_CMD")"
    elif hash rankmirrors >/dev/null 2>&1; then
        infobox "Mirrorlist" "\nQuerying mirrors near your location\n"
        c="$(json 'country_code' "$(json 'ip' "check&?access_key=${key}&fields=ip")?access_key=${key}&fields=country_code")"
        local w="https://www.archlinux.org/mirrorlist"
        if [[ $c ]]; then
            if [[ $c =~ (CA|US) ]]; then
                MIRROR_CMD="curl -s '$w/?country=US&country=CA&use_mirror_status=on'"
            else
                MIRROR_CMD="curl -s '$w/?country=${c}&use_mirror_status=on'"
            fi
        else
            MIRROR_CMD="curl -s '$w/?country=US&country=CA&country=NZ&country=GB&country=AU&use_mirror_status=on'"
        fi
    fi

    return 0
}

###############################################################################
# package menus

pkg_browsers()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "firefox"     "A popular open-source graphical web browser from Mozilla" $(ofn 'firefox') \
        "chromium"    "an open-source graphical web browser based on the Blink rendering engine" $(ofn 'chromium') \
        "opera"       "A Fast and secure, free of charge web browser from Opera Software" $(ofn 'opera') \
        "epiphany"    "A GNOME web browser based on the WebKit rendering engine" $(ofn 'epiphany') \
        "surf"        "A simple web browser based on WebKit2/GTK+" $(ofn 'surf') \
        "qutebrowser" "A keyboard-focused vim-like web browser based on Python and PyQt5" $(ofn 'qutebrowser'))"
    printf "%s" "$pkgs"
}

pkg_editors()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "neovim"   "A fork of Vim aiming to improve user experience, plugins, and GUIs." $(ofn 'neovim') \
        "atom"     "An open-source text editor developed by GitHub that is licensed under the MIT License" $(ofn 'atom') \
        "geany"    "A fast and lightweight IDE" $(ofn 'geany') \
        "emacs"    "An extensible, customizable, self-documenting real-time display editor" $(ofn 'emacs') \
        "mousepad" "A simple text editor" $(ofn 'mousepad'))"
    printf "%s" "$pkgs"
}

pkg_files()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "thunar"      "A modern file manager for the Xfce Desktop Environment" $(ofn 'thunar') \
        "pcmanfm"     "A fast and lightweight file manager based in Lxde" $(ofn 'pcmanfm') \
        "nautilus"    "The default file manager for Gnome" $(ofn 'nautilus') \
        "gparted"     "A GUI frontend for creating and manipulating partition tables" $(ofn 'gparted') \
        "file-roller" "Create and modify archives" $(ofn 'file-roller') \
        "xarchiver"   "A GTK+ frontend to various command line archivers" $(ofn 'xarchiver'))"
    printf "%s" "$pkgs"
}

pkg_terms()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "termite"        "A minimal VTE-based terminal emulator" $(ofn 'termite') \
        "rxvt-unicode"   "A unicode enabled rxvt-clone terminal emulator" $(ofn 'rxvt-unicode') \
        "xterm"          "The standard terminal emulator for the X window system" $(ofn 'xterm') \
        "alacritty"      "A cross-platform, GPU-accelerated terminal emulator" $(ofn 'alacritty') \
        "terminator"     "Terminal emulator that supports tabs and grids" $(ofn 'terminator') \
        "sakura"         "A terminal emulator based on GTK and VTE" $(ofn 'sakura') \
        "tilix"          "A tiling terminal emulator for Linux using GTK+ 3" $(ofn 'tilix') \
        "tilda"          "A Gtk based drop down terminal for Linux and Unix" $(ofn 'tilda') \
        "xfce4-terminal" "A terminal emulator based in the Xfce Desktop Environment" $(ofn 'xfce-terminal'))"
    printf "%s" "$pkgs"
}

pkg_media()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "vlc"        "A free and open source cross-platform multimedia player" $(ofn 'vlc') \
        "mpv"        "A media player based on mplayer" $(ofn 'mpv') \
        "mpd"        "A flexible, powerful, server-side application for playing music" $(ofn 'mpd') \
        "ncmpcpp"    "An mpd client and almost exact clone of ncmpc with some new features" $(ofn 'ncmpcpp') \
        "cmus"       "A small, fast and powerful console music player for Unix-like operating systems" $(ofn 'cmus') \
        "audacious"  "A free and advanced audio player based on GTK+" $(ofn 'audacious') \
        "nicotine+"  "A graphical client for Soulseek" $(ofn 'nicotine+') \
        "lollypop"   "A new music playing application" $(ofn 'lollypop') \
        "rhythmbox"  "Music playback and management application" $(ofn 'rhythmbox') \
        "deadbeef"   "A GTK+ audio player for GNU/Linux" $(ofn 'deadbeef') \
        "clementine" "A modern music player and library organizer" $(ofn 'clementine'))"
    printf "%s" "$pkgs"
}

pkg_mail()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "thunderbird" "Standalone mail and news reader from mozilla" $(ofn 'thunderbird') \
        "geary"       "A lightweight email client for the GNOME desktop" $(ofn 'geary') \
        "evolution"   "Manage your email, contacts and schedule" $(ofn 'evolution') \
        "mutt"        "Small but very powerful text-based mail client" $(ofn 'mutt') \
        "hexchat"     "A popular and easy to use graphical IRC client" $(ofn 'hexchat') \
        "pidgin"      "Multi-protocol instant messaging client" $(ofn 'pidgin') \
        "weechat"     "Fast, light and extensible IRC client" $(ofn 'weechat') \
        "irssi"       "Modular text mode IRC client" $(ofn 'irssi'))"
    printf "%s" "$pkgs"
}

pkg_prof()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "libreoffice-fresh"    "Full featured office suite" $(ofn 'libreoffice-fresh') \
        "abiword"              "Fully-featured word processor" $(ofn 'abiword') \
        "calligra"             "A set of applications for productivity" $(ofn 'calligra') \
        "gimp"                 "GNU Image Manipulation Program" $(ofn 'gimp') \
        "inkscape"             "Professional vector graphics editor" $(ofn 'inkscape') \
        "krita"                "Edit and paint images" $(ofn 'krita') \
        "obs-studio"           "Free opensource streaming/recording software" $(ofn 'obs-studio') \
        "kdenlive"             "A non-linear video editor for Linux using the MLT video framework" $(ofn 'kdenlive') \
        "openshot"             "An open-source, non-linear video editor for Linux" $(ofn 'openshot') \
        "audacity"             "A program that lets you manipulate digital audio waveforms" $(ofn 'audacity') \
        "guvcview"             "Capture video from camera devices" $(ofn 'guvcview') \
        "simplescreenrecorder" "A feature-rich screen recorder" $(ofn 'simplescreenrecorder'))"
    printf "%s" "$pkgs"
}

pkg_fonts()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "ttf-hack"   "A hand groomed and optically balanced typeface based on Bitstream Vera Mono" $(ofn 'ttf-hack') \
        "ttf-anonymous-pro" "A family fixed-width fonts designed with coding in mind" $(ofn 'ttf-anonymous-pro') \
        "ttf-font-awesome"  "Iconic font designed for Bootstrap" $(ofn 'ttf-font-awesome') \
        "ttf-fira-code"     "Monospaced font with programming ligatures" $(ofn 'ttf-fira-code') \
        "noto-fonts"        "Google Noto fonts" $(ofn 'noto-fonts') \
        "noto-fonts-cjk"    "Google Noto CJK fonts (Chinese, Japanese, Korean)" $(ofn 'noto-fonts-cjk'))"
    printf "%s" "$pkgs"
}

pkg_viewers()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "evince"   "A document viewer" $(ofn 'evince') \
        "zathura"  "Minimalistic document viewer" $(ofn 'zathura') \
        "qpdfview" "A tabbed PDF viewer" $(ofn 'qpdfview') \
        "mupdf"    "Lightweight PDF and XPS viewer" $(ofn 'mupdf') \
        "gpicview" "Lightweight image viewer" $(ofn 'gpicview'))"
    printf "%s" "$pkgs"
}

pkg_torrent()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "deluge"           "A BitTorrent client written in python" $(ofn 'deluge') \
        "qbittorrent"      "An advanced BitTorrent client" $(ofn 'qbittorrent') \
        "transmission-gtk" "Free BitTorrent client GTK+ GUI" $(ofn 'transmission-gtk') \
        "transmission-qt"  "Free BitTorrent client Qt GUI" $(ofn 'transmission-qt') \
        "transmission-cli" "Free BitTorrent client CLI" $(ofn 'transmission-cli'))"
    printf "%s" "$pkgs"
}

pkg_sys()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "gnome-disk-utility"   "Disk Management Utility" $(ofn 'gnome-disk-utility') \
        "gnome-system-monitor" "View current processes and monitor system state" $(ofn 'gnome-system-monitor') \
        "qt5ct"                "GUI for managing Qt based application themes, icons, and fonts" $(ofn 'qt5ct'))"
    printf "%s" "$pkgs"
}

pkg_extra()
{
    local pkgs=""
    pkgs="$(checkbox "Packages" "$_PackageBody" \
        "steam"      "A popular game distribution platform by Valve" $(ofn 'steam') \
        "gpick"      "Advanced color picker using GTK+ toolkit" $(ofn 'gpick') \
        "gcolor2"    "A simple GTK+2 color selector" $(ofn 'gcolor2') \
        "plank"      "An elegant, simple, and clean dock" $(ofn 'plank') \
        "docky"      "Full fledged dock for opening applications and managing windows" $(ofn 'docky') \
        "cairo-dock" "Light eye-candy fully themable animated dock" $(ofn 'cairo-dock'))"
    printf "%s" "$pkgs"
}

###############################################################################
# partition menus

part_menu()
{
    local device choice

    if [[ $# -eq 1 ]]; then
        device="$1"
    else
        umount_dir $MNT
        select_device || return 1
        device="$DEVICE"
    fi

    tput civis
    if [[ $DISPLAY && $TERM != 'linux' ]] && hash gparted >/dev/null 2>&1; then
        choice="$(menubox "Edit Partitions" "$_PartBody" \
            "view partition table" "Shows output from the lsblk command" \
            "auto partition" "Full device automatic partitioning" \
            "gparted" "GUI front end to parted" \
            "cfdisk" "Curses front end to fdisk" \
            "parted" "GNU partition editor" \
            "secure wipe" "Wipe data before disposal or sale of a device" \
            "done" "return to the main menu")"

    else
        choice="$(menubox "Edit Partitions" "$_PartBody" \
            "view partition table" "Shows output from the lsblk command" \
            "auto partition" "Full device automatic partitioning" \
            "cfdisk" "Curses front end to fdisk" \
            "parted" "GNU partition editor" \
            "secure wipe" "Wipe data before disposal or sale of the device" \
            "done" "return to the main menu")"

    fi

    tput civis
    if [[ $choice == "done" || $choice == "" ]]; then
        return 0
    elif [[ $choice == "view partition table" ]]; then
        msgbox "Partition Table" "\n\n$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINT "$device")\n\n"
    elif [[ $choice == "secure wipe" ]]; then
        yesno "Wipe Partition" "\nWARNING: ALL data on $device $_PartWipeBody" && wipe -Ifrev $device
    elif [[ $choice == "auto partition" ]]; then
        local root_size msg ret table boot_fs
        root_size=$(lsblk -lno SIZE "$device" | awk 'NR == 1 {
            if ($1 ~ "G") {
                sub(/G/, ""); print ($1 * 1000 - 512) / 1000 "G"
            } else {
                sub(/M/, ""); print ($1 - 512) "M"
            }
        }')

        if [[ $SYS == 'BIOS' ]]; then
            msg="$(sed 's|vfat/fat32|ext4|' <<< "$_PartBody2")"; table="msdos"; boot_fs="ext4"
        else
            msg="$_PartBody2"; table="gpt"; boot_fs="fat32"
        fi

        if yesno "Auto Partition" "\nWARNING: ALL data on $device $msg ($root_size)$_PartBody3"; then
            auto_partition "$device" "$table" "$boot_fs" "$root_size" && return 0 || return 1
        fi
    else
        clear; tput cnorm; $choice "$device"
    fi

    part_menu "$device"
}

format_as()
{
    infobox "Format" "\nRunning: ${FS_CMDS[$2]} $1\n" 1
    ${FS_CMDS[$2]} "$1" >/dev/null 2>$ERR
    errshow "${FS_CMDS[$2]} $1" && FORMATTED+=" $part"
}

decr_pcount()
{
    for i in $(printf "%s" "$@"); do
        if (( COUNT > 0 )); then
            PARTS="$(sed "/${i//\//\\/}/d" <<< "$PARTS")" && (( COUNT-- ))
        fi
    done
}

dev_tree()
{
    tput civis
    local msg
    if [[ $IGNORE_DEV != "" ]]; then
        msg="$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINT |
            awk "!/$IGNORE_DEV/"' && /disk|part|lvm|crypt|NAME/')"
    else
        msg="$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINT |
            awk '/disk|part|lvm|crypt|NAME/')"
    fi
    msgbox "Device Tree" "\n\n$msg\n\n"
}

enable_swap()
{
    if [[ $1 == "$MNT/swapfile" && $SWAP_SIZE ]]; then
        fallocate -l $SWAP_SIZE $1 2>$ERR
        errshow "fallocate -l $SWAP_SIZE $1"
        chmod 600 $1 2>$ERR
        errshow "chmod 600 $1"
    fi
    mkswap $1 >/dev/null 2>$ERR
    errshow "mkswap $1"
    swapon $1 >/dev/null 2>$ERR
    errshow "swapon $1"
    return 0
}

select_device()
{
    if [[ $DEV_COUNT -eq 1 && $SYS_DEVS ]]; then
        DEVICE="$(awk '{print $1}' <<< "$SYS_DEVS")"
    elif (( DEV_COUNT > 1 )); then
        tput civis
        if [[ $1 ]]; then
            DEVICE="$(menubox "Boot Device" "\nSelect the device to use for bootloader install." $SYS_DEVS)"
        else
            DEVICE="$(menubox "Select Device" "$_DevSelBody" $SYS_DEVS)"
        fi
        [[ $DEVICE ]] || return 1
    elif [[ $DEV_COUNT -lt 1 && ! $1 ]]; then
        msgbox "$_ErrTitle" "\nNo available devices.\n\nExiting..\n"; die 1
    fi

    [[ $1 ]] && BOOT_DEV="$DEVICE"

    return 0
}

confirm_mount()
{
    if [[ $(mount) == *"$1"* ]]; then
        infobox "Mount Success" "\nPartition $1 mounted at $2\n" 1
        decr_pcount $1
    else
        infobox "Mount Fail" "\nPartition $1 failed to mount at $2\n" 1
        return 1
    fi
    return 0
}

check_cryptlvm()
{
    local dev devs part="$1"
    devs="$(lsblk -lno NAME,FSTYPE,TYPE)"

    # Identify if $part is LUKS+LVM, LVM+LUKS, LVM alone, or LUKS alone
    if [[ $(lsblk -lno TYPE "$part") =~ 'crypt' ]]; then
        LUKS='encrypted'
        LUKS_NAME="${part#/dev/mapper/}"
        for dev in $(awk '/lvm/ && /crypto_LUKS/ {print "/dev/mapper/"$1}' <<< "$devs" | uniq); do
            if grep -q "$LUKS_NAME" <<< "$(lsblk -lno NAME "$dev")"; then
                LUKS_DEV="$LUKS_DEV cryptdevice=$dev:$LUKS_NAME"
                LVM='logical volume'
                break
            fi
        done
        for dev in $(awk '/part/ && /crypto_LUKS/ {print "/dev/"$1}' <<< "$devs" | uniq); do
            if grep -q "$LUKS_NAME" <<< "$(lsblk -lno NAME "$dev")"; then
                LUKS_UUID="$(lsblk -lno UUID,TYPE,FSTYPE "$dev" | awk '/part/ && /crypto_LUKS/ {print $1}')"
                LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
                break
            fi
        done
    elif [[ $(lsblk -lno TYPE "$part") =~ 'lvm' ]]; then
        LVM='logical volume'
        VOLUME_NAME="${part#/dev/mapper/}"
        for dev in $(awk '/crypt/ && /lvm2_member/ {print "/dev/mapper/"$1}' <<< "$devs" | uniq); do
            if grep -q "$VOLUME_NAME" <<< "$(lsblk -lno NAME "$dev")"; then
                LUKS_NAME="$(sed 's~/dev/mapper/~~g' <<< "$dev")"
                break
            fi
        done
        for dev in $(awk '/part/ && /crypto_LUKS/ {print "/dev/"$1}' <<< "$devs" | uniq); do
            if grep -q "$LUKS_NAME" <<< "$(lsblk -lno NAME "$dev")"; then
                LUKS_UUID="$(lsblk -lno UUID,TYPE,FSTYPE "$dev" | awk '/part/ && /crypto_LUKS/ {print $1}')"
                LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
                LUKS='encrypted'
                break
            fi
        done
    fi
}

auto_partition()
{
    local device="$1" table="$2" boot_fs="$3" size="$4"
    local dev_info="$(parted -s $device print)"

    infobox "Auto Partition" "\nRemoving partitions on $device and setting table to $table\n" 2

    # in case the device was previously used for swap
    swapoff -a

    # walk the partitions on the device in reverse order and delete them
    while read -r PART; do
        parted -s $device rm $PART >/dev/null 2>&1
    done <<< "$(awk '/^ [1-9][0-9]?/ {print $1}' <<< "$dev_info" | sort -r)"

    if [[ $(awk '/Table:/ {print $3}' <<< "$dev_info") != "$table" ]]; then
        parted -s $device mklabel $table >/dev/null 2>&1
    fi

    infobox "Auto Partition" "\nCreating a 512M $fs boot partition.\n" 2
    if [[ $SYS == "BIOS" ]]; then
        parted -s $device mkpart primary $fs 1MiB 513MiB >/dev/null 2>&1
    else
        parted -s $device mkpart ESP $fs 1MiB 513MiB >/dev/null 2>&1
    fi

    sleep 0.5
    BOOT_DEV="$device"
    AUTO_BOOT_PART=$(lsblk -lno NAME,TYPE $device | awk 'NR == 2 {print "/dev/"$1}')

    if [[ $SYS == "BIOS" ]]; then
        mkfs.ext4 -q $AUTO_BOOT_PART >/dev/null 2>&1
    else
        mkfs.vfat -F32 $AUTO_BOOT_PART >/dev/null 2>&1
    fi

    infobox "Auto Partition" "\nCreating a $size ext4 root partition.\n" 0
    parted -s $device mkpart primary ext4 513MiB 100% >/dev/null 2>&1
    sleep 0.5
    AUTO_ROOT_PART="$(lsblk -lno NAME,TYPE $device | awk 'NR == 3 {print "/dev/"$1}')"
    mkfs.ext4 -q $AUTO_ROOT_PART >/dev/null 2>&1
    tput civis; sleep 0.5
    msgbox "Auto Partition" "\nProcess complete.\n\n$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE $device)\n"
}

mount_partition()
{
    local part="$1"
    local mountp="${MNT}$2"
    local fs
    fs="$(lsblk -lno FSTYPE $part)"
    mkdir -p "$mountp"

    if [[ $fs && ${FS_OPTS[$fs]} && $part != "$BOOT_PART" ]] && select_mntopts "$part" "$fs"; then
        mount -o $MNT_OPTS "$part" "$mountp" 2>$ERR
    else
        mount "$part" "$mountp" 2>$ERR
    fi

    confirm_mount $part "$mountp" || return 1
    check_cryptlvm "$part"

    return 0
}

find_partitions()
{
    local str="$1" err=''

    # string of partitions as /TYPE/PART SIZE
    if [[ $IGNORE_DEV ]]; then
        PARTS="$(lsblk -lno TYPE,NAME,SIZE |
            awk "/$str/"' && !'"/$IGNORE_DEV/"' {
                sub(/^part/, "/dev/");
                sub(/^lvm|^crypt/, "/dev/mapper/")
                print $1$2 " " $3
            }')"
    else
        PARTS="$(lsblk -lno TYPE,NAME,SIZE |
            awk "/$str/"' {
                sub(/^part/, "/dev/")
                sub(/^lvm|^crypt/, "/dev/mapper/")
                print $1$2 " " $3
            }')"
    fi

    # number of partitions total
    if [[ $PARTS ]]; then
        COUNT=$(wc -l <<< "$PARTS")
    else
        COUNT=0
    fi

    # ensure we have enough partitions for the system and action type
    case "$str" in
        'part|lvm|crypt') [[ $COUNT -lt 1 || ($SYS == 'UEFI' && $COUNT -lt 2) ]] && err="$_PartErrBody" ;;
        'part|crypt') (( COUNT < 1 )) && err="$_LvmPartErrBody" ;;
        'part|lvm') (( COUNT < 2 )) && err="$_LuksPartErrBody" ;;
    esac

    # if there aren't enough partitions show the relevant error message
    [[ $err ]] && { msgbox "Not Enough Partitions" "$err"; return 1; }

    return 0
}

setup_boot_device()
{
    infobox "Boot Device" "\nSetting device flags for: $BOOT_PART\n" 1
    [[ $BOOT_PART = /dev/nvme* ]] && BOOT_DEV="${BOOT_PART%p[1-9]}" || BOOT_DEV="${BOOT_PART%[1-9]}"
    BOOT_PART_NUM="${BOOT_PART: -1}"
    if [[ $SYS == 'UEFI' ]]; then
        parted -s $BOOT_DEV set $BOOT_PART_NUM esp on >/dev/null 2>&1
    else
        parted -s $BOOT_DEV set $BOOT_PART_NUM boot on >/dev/null 2>&1
    fi
    return 0
}

###############################################################################
# mounting menus

mount_menu()
{
    lvm_detect
    umount_dir $MNT
    find_partitions 'part|lvm|crypt' || { SEL=2; return 1; }

    [[ $LUKS_PART ]] && decr_pcount $LUKS_PART
    [[ $LVM_PARTS ]] && decr_pcount $LVM_PARTS

    select_root_partition || return 1

    if [[ $SYS == "UEFI" ]]; then
        select_efi_partition || { BOOT_PART=""; return 1; }
    elif (( COUNT > 0 )); then
        select_boot_partition || { BOOT_PART=""; return 1; }
    fi

    setup_boot || return 1
    select_swap || return 1
    select_extra_partitions || return 1
    return 0
}

select_swap()
{
    tput civis
    SWAP_PART="$(menubox "Swap Setup" "\nSelect whether to use a swap partition, swapfile, or none." \
        "none" "Don't allocate any swap space" \
        "swapfile" "Allocate $SYS_MEM of swap at /swapfile" \
        $PARTS)"

    if [[ $SWAP_PART == "" || $SWAP_PART == "none" ]]; then
        SWAP_PART=""; return 0
    elif [[ $SWAP_PART == "swapfile" ]]; then
        tput cnorm
        local i=0
        while ! [[ ${SWAP_SIZE:0:1} =~ [1-9] && ${SWAP_SIZE: -1} =~ (M|G) ]]; do
            (( i > 0 )) && msgbox "Swap Setup Error" "\n$_SelSwpErr $SWAP_SIZE\n"
            if ! SWAP_SIZE="$(getinput "Swap Setup" "$_SelSwpSize" "$SYS_MEM")"; then
                SWAP_PART=""; SWAP_SIZE=""; break; return 0
            fi
            (( i++ ))
        done
        enable_swap "$MNT/$SWAP_PART"
        SWAP_PART="/$SWAP_PART"
    else
        enable_swap $SWAP_PART
        decr_pcount $SWAP_PART
        SWAP_SIZE="$(lsblk -lno SIZE $SWAP_PART)"
    fi
    return 0
}

select_mntopts()
{
    local part="$1" fs="$2" err=0
    local title="${fs^} Mount Options"
    local opts="${FS_OPTS[$fs]}"

    if is_ssd "$part" >/dev/null 2>&1; then
        opts=$(sed 's/discard - off/discard - on/' <<< "$opts")
    fi

    tput civis
    while true; do
        MNT_OPTS="$(dialog --cr-wrap --stdout --backtitle "$BT" \
            --title " $title " --checklist "$_MntBody" 0 0 0 $opts)"

        if [[ $MNT_OPTS ]]; then
            MNT_OPTS="$(sed 's/ /,/g; $s/,$//' <<< "$MNT_OPTS" )"
            yesno "$title" "\nConfirm mount options: $MNT_OPTS\n" && break
        else
            err=1; break
        fi
    done

    return $err
}

select_mountpoint()
{
    local err=0
    tput cnorm
    while true; do
        EXMNT="$(getinput "Extra Mount $part" "$_ExtPartBody1" "/" nolimit)"
        err=$?
        (( err == 0 )) || break
        if [[ ${EXMNT:0:1} != "/" || ${#EXMNT} -le 1 || $EXMNT =~ \ |\' || $EXMNTS == *"$EXMNT"* ]]; then
            msgbox "$_ErrTitle" "$_ExtErrBody"
        else
            break
        fi
    done
    return $err
}

select_filesystem()
{
    local part="$1" fs="" cur_fs="" err=0
    cur_fs="$(lsblk -lno FSTYPE "$part" 2>/dev/null)"
    [[ $part == "$ROOT_PART" && $ROOT_PART == "$AUTO_ROOT_PART" && ! $LUKS && ! $LVM ]] && return 0

    while true; do
        tput civis
        if [[ $cur_fs && ( $part != "$ROOT_PART" || $FORMATTED == *"$part"* ) ]]; then
            fs="$(menubox "Filesystem" \
                "\nSelect which filesystem to use for: $part\n\nCurrent:  ${cur_fs:-none}\nDefault:  ext4" \
                "skip"     "do not format this partition" \
                "ext4"     "${FS_CMDS[ext4]}" \
                "ext3"     "${FS_CMDS[ext3]}" \
                "ext2"     "${FS_CMDS[ext2]}" \
                "vfat"     "${FS_CMDS[vfat]}" \
                "ntfs"     "${FS_CMDS[ntfs]}" \
                "f2fs"     "${FS_CMDS[f2fs]}" \
                "jfs"      "${FS_CMDS[jfs]}" \
                "xfs"      "${FS_CMDS[xfs]}"\
                "nilfs2"   "${FS_CMDS[nilfs2]}" \
                "reiserfs" "${FS_CMDS[reiserfs]}")"

            [[ $fs == "skip" ]] && break
        else
            fs="$(menubox "Filesystem" "\nSelect which filesystem to use for: $part\n\nDefault:  ext4" \
                "ext4"     "${FS_CMDS[ext4]}" \
                "ext3"     "${FS_CMDS[ext3]}" \
                "ext2"     "${FS_CMDS[ext2]}" \
                "ntfs"     "${FS_CMDS[ntfs]}" \
                "f2fs"     "${FS_CMDS[f2fs]}" \
                "jfs"      "${FS_CMDS[jfs]}" \
                "xfs"      "${FS_CMDS[xfs]}" \
                "nilfs2"   "${FS_CMDS[nilfs2]}" \
                "reiserfs" "${FS_CMDS[reiserfs]}")"

        fi
        [[ $fs ]] || { err=1; break; }
        yesno "Filesystem" "\nFormat $part as $fs?\n" && break
    done
    (( err == 0 )) || return $err
    [[ $fs == "skip" ]] || format_as "$part" "$fs"
}

select_efi_partition()
{
    tput civis
    if (( COUNT == 1 )); then
        BOOT_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
    elif [[ $AUTO_BOOT_PART ]]; then
        BOOT_PART="$AUTO_BOOT_PART"
        return 0 # were done here
    else
        BOOT_PART="$(menubox "EFI Partition" "$_SelUefiBody" $PARTS)"
    fi
    [[ $BOOT_PART ]] || return 1

    if grep -q 'fat' <<< "$(fsck -N "$BOOT_PART")"; then
        local msg="\nIMPORTANT: The EFI partition $BOOT_PART $_FormBootBody"
        if yesno "Format EFI Partition" "$msg" "Format $BOOT_PART" "Skip Formatting" "no"; then
            format_as "$BOOT_PART" "vfat"
            sleep 1
        fi
    else
        format_as "$BOOT_PART" "vfat"
        sleep 1
    fi

    return 0
}

select_boot_partition()
{
    tput civis
    if [[ $AUTO_BOOT_PART && ! $LVM ]]; then
        BOOT_PART="$AUTO_BOOT_PART"
        return 0 # were done here
    elif [[ $LUKS && ! $LVM ]]; then
        BOOT_PART="$(menubox "Boot Partition" "$_SelBiosLuksBody" $PARTS)"
        [[ $BOOT_PART ]] || return 1
    else
        BOOT_PART="$(menubox "Boot Partition" "$_SelBiosBody" "skip" "don't use a separate boot" $PARTS)"
        [[ $BOOT_PART == "" || $BOOT_PART == "skip" ]] && { BOOT_PART=""; return 0; }
    fi

    if grep -q 'ext[34]' <<< "$(fsck -N "$BOOT_PART")"; then
        local msg="\nIMPORTANT: The boot partition $BOOT_PART $_FormBootBody"
        if yesno "Format Boot Partition" "$msg" "Format $BOOT_PART" "Skip Formatting" "no"; then
            format_as "$BOOT_PART" "ext4"
            sleep 1
        fi
    else
        format_as "$BOOT_PART" "ext4"
        sleep 1
    fi
    return 0
}

select_root_partition()
{
    tput civis
    if (( COUNT == 1 )); then
        ROOT_PART="$(awk 'NR==1 {print $1}' <<< "$PARTS")"
    else
        ROOT_PART="$(menubox "Mount Root" "$_SelRootBody" $PARTS)"
        [[ $ROOT_PART ]] || return 1
    fi

    select_filesystem "$ROOT_PART" || { ROOT_PART=""; return 1; }
    mount_partition "$ROOT_PART" || { ROOT_PART=""; return 1; }
    return 0
}

select_extra_partitions()
{
    local part
    while (( COUNT > 0 )); do
        tput civis
        part="$(menubox "Mount Boot" "$_ExtPartBody" "done" "return to the main menu" $PARTS)"
        if [[ $part == "done" || $part == "" ]]; then
            break
        elif select_filesystem "$part" && select_mountpoint && mount_partition "$part" "$EXMNT"; then
            EXMNTS="$EXMNTS $part: $EXMNT"
            [[ $EXMNT == '/usr' && $HOOKS != *usr* ]] && HOOKS="usr $HOOKS"
        else
            break; return 1
        fi
    done
    return 0
}

###############################################################################
# installation

install_main()
{
    clear
    tput cnorm
    install_base
    printf "Generating /etc/fstab:  genfstab -U $MNT >$MNT/etc/fstab\n"
    genfstab -U $MNT >$MNT/etc/fstab 2>$ERR
    errshow 1 "genfstab -U $MNT >$MNT/etc/fstab"
    [[ -f $MNT/swapfile ]] && sed -i "s~${MNT}~~" $MNT/etc/fstab
    install_mirrorlist
    install_packages
    install_mkinitcpio
    install_boot
    printf "Setting hardware clock with:  hwclock --systohc --utc\n"
    chrun "hwclock --systohc --utc" || chrun "hwclock --systohc --utc --directisa"
    install_user
    install_login
    printf "Setting ownership of /home/$NEWUSER\n"
    chrun "chown -Rf $NEWUSER:users /home/$NEWUSER"
    sleep 1

    while true; do
        tput civis
        choice=$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
            --title " Finalization " --menu "$_EditBody" 0 0 0 \
            "finished"   "exit the installer and reboot" \
            "keyboard"   "${EDIT_FILES[keyboard]}" \
            "console"    "${EDIT_FILES[console]}" \
            "locale"     "${EDIT_FILES[locale]}" \
            "hostname"   "${EDIT_FILES[hostname]}" \
            "sudoers"    "${EDIT_FILES[sudoers]}" \
            "mkinitcpio" "${EDIT_FILES[mkinitcpio]}" \
            "fstab"      "${EDIT_FILES[fstab]}" \
            "crypttab"   "${EDIT_FILES[crypttab]}" \
            "bootloader" "${EDIT_FILES[bootloader]}" \
            "pacman"     "${EDIT_FILES[pacman]}" \
            "login"      "${EDIT_FILES[login]}")

        if [[ $choice == "" || $choice == "finished" ]]; then
            [[ $DEBUG == true && -r $DBG ]] && vim $DBG
            # when die() is passed 127 it will call: systemctl -i reboot
            die 127
        else
            local exists=""
            for f in $(printf "%s" "${EDIT_FILES[$choice]}"); do
                [[ -e ${MNT}$f ]] && exists+=" ${MNT}$f"
            done
            if [[ $exists ]]; then
                vim -O $exists
            else
                msgbox "File Error" "\nFile(s) do not exist.\n"
            fi
        fi
    done
}

install_base()
{
    if [[ -e /run/archiso/sfs/airootfs/etc/skel ]]; then
        rsync -ahv /run/archiso/sfs/airootfs/ $MNT/ 2>$ERR
        errshow 1 "rsync -ahv /run/archiso/sfs/airootfs/ $MNT/"
    else
        install_mirrorlist
        pacstrap $MNT $KERNEL $UCODE base base-devel linux-firmware nano networkmanager grub wpa_supplicant wireless-regdb dialog reflector haveged  2>$ERR
        errshow 1 "pacstrap $MNT base $KERNEL $UCODE $packages"
    fi

    printf "Removing archiso remains\n"
    rm -rf $MNT/etc/mkinitcpio-archiso.conf
    find $MNT/usr/lib/initcpio -name 'archiso*' -type f -exec rm -rf '{}' \;
    sed -i 's/volatile/auto/g' $MNT/etc/systemd/journald.conf

    if [[ $VM ]]; then
        printf "Removing xorg configs in /etc/X11/xorg.conf.d/ to avoid conflict in VMs\n"
        rm -rfv $MNT/etc/X11/xorg.conf.d/*?.conf
        sleep 1
    elif [[ $(lspci | grep ' VGA ' | grep 'Intel') != "" ]]; then
        printf "Creating intel GPU 'TearFree' config in /etc/X11/xorg.conf.d/20-intel.conf\n"
        cat > $MNT/etc/X11/xorg.conf.d/20-intel.conf <<EOF
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "TearFree" "true"
EndSection
EOF
    fi

    if [[ -e /run/archiso/sfs/airootfs ]]; then
        printf "Copying vmlinuz and ucode to /boot\n"
        [[ $KERNEL == 'linux' ]] && cp -vf $RUN/x86_64/vmlinuz $MNT/boot/vmlinuz-linux
        [[ $UCODE ]] && cp -vf $RUN/${UCODE/-/_}.img $MNT/boot/$UCODE.img
    fi

    printf "Copying network settings to /etc\n"
    cp -fv /etc/resolv.conf $MNT/etc/
    if [[ -e /etc/NetworkManager/system-connections ]]; then
        cp -rvf /etc/NetworkManager/system-connections $MNT/etc/NetworkManager/
    fi

    printf "Setting locale to $LOCALE\n"
    cat > $MNT/etc/locale.conf << EOF
LANG=$LOCALE
EOF
    cat > $MNT/etc/default/locale << EOF
LANG=$LOCALE
EOF
    sed -i "s/#en_US.UTF-8/en_US.UTF-8/g; s/#${LOCALE}/${LOCALE}/g" $MNT/etc/locale.gen
    chrun "locale-gen"
    printf "Setting timezone: $ZONE/$SUBZONE\n"
    chrun "ln -svf /usr/share/zoneinfo/$ZONE/$SUBZONE /etc/localtime"

    if [[ $BROADCOM_WL == true ]]; then
        printf "Blacklisting modules for broadcom wireless: bmca\n"
        echo 'blacklist bcma' >> $MNT/etc/modprobe.d/blacklist.conf
        rm -f $MNT/etc/modprobe/
    fi

    printf "Creating keyboard configurations for keymap: $KEYMAP\n"
    cat > $MNT/etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
# Use localectl(1) to instruct systemd-localed to update it.
Section "InputClass"
    Identifier      "system-keyboard"
    MatchIsKeyboard "on"
    Option          "XkbLayout" "$KEYMAP"
EndSection
EOF
    cat > $MNT/etc/default/keyboard <<EOF
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) manual page.
XKBMODEL=""
XKBLAYOUT="$KEYMAP"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
    cat > $MNT/etc/vconsole.conf <<EOF
KEYMAP=$CMAP
FONT=$FONT
EOF
    printf "Setting system hostname: $HOSTNAME\n"
    cat > $MNT/etc/hostname << EOF
$HOSTNAME
EOF
    cat > $MNT/etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

}

install_user()
{
    printf "Setting root password\n"
    chrun "chpasswd <<< 'root:$ROOT_PASS'" 2>$ERR
    errshow 1 "set root password"
    if [[ $MYSHELL != *zsh ]]; then
        chrun "usermod -s $MYSHELL root" 2>$ERR
        errshow 1 "usermod -s $MYSHELL root"
        if [[ $MYSHELL == "/usr/bin/mksh" ]]; then
            cp -fv $MNT/etc/skel/.mkshrc /root/.mkshrc
        fi
    fi

    local groups='audio,autologin,floppy,log,network,rfkill,scanner,storage,optical,power,wheel'

    printf "Creating user $NEWUSER with:  useradd -m -u 1000 -g users -G $groups -s $MYSHELL $NEWUSER\n"
    chrun "groupadd -r autologin" 2>$ERR
    errshow 1 "groupadd -r autologin"
    chrun "useradd -m -u 1000 -g users -G $groups -s $MYSHELL $NEWUSER" 2>$ERR
    errshow 1 "useradd -m -u 1000 -g users -G $groups -s $MYSHELL $NEWUSER"
    chrun "chpasswd <<< '$NEWUSER:$USER_PASS'" 2>$ERR
    errshow 1 "set $NEWUSER password"

    if [[ $USER_PKGS == *neovim* ]]; then
        mkdir -p $MNT/home/$NEWUSER/.config/nvim
        cp -fv $MNT/home/$NEWUSER/.vimrc $MNT/home/$NEWUSER/.config/nvim/init.vim
        cp -rfv $MNT/home/$NEWUSER/.vim/colors $MNT/home/$NEWUSER/.config/nvim/colors
    fi

    if [[ $MYSHELL == '/usr/bin/mksh' ]]; then
        cat >> $MNT/home/$NEWUSER/.mkshrc << EOF
# colors in less (manpager)
export LESS_TERMCAP_mb=$'\e[01;31m'
export LESS_TERMCAP_md=$'\e[01;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;44;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[01;32m'

export EDITOR=$([[ $USER_PKGS == *neovim* ]] && printf "n")vim

# source shell configs
for f in "\$HOME/.mksh/"*?.sh; do
    . "\$f"
done

al-info
EOF
    fi

    [[ $INSTALL_WMS == *dwm* ]] && install_suckless
    [[ $LOGIN_WM =~ (startkde|gnome-session) ]] && sed -i '/super/d' $HOME/.xprofile /root/.xprofile

    return 0
}

install_login()
{
    printf "Setting up $LOGIN_TYPE\n"
    SERVICE="$MNT/etc/systemd/system/getty@tty1.service.d"

    # remove welcome message
    sed -i '/printf/d' $MNT/root/.zshrc

    # remove unneeded shell files from installation
    case $MYSHELL in
        "/bin/bash")
            rm -rf $MNT/home/$NEWUSER/.{zsh,mksh}* $MNT/root/.{zsh,mksh}* ;;
        "/usr/bin/mksh")
            rm -rf $MNT/home/$NEWUSER/.{zsh,bash}* $MNT/home/$NEWUSER/.inputrc $MNT/root/.{zsh,bash}* $MNT/root/.inputrc ;;
        "/usr/bin/zsh")
            rm -rf $MNT/home/$NEWUSER/.{bash,mksh}* $MNT/home/$NEWUSER/.inputrc $MNT/root/.{bash,mksh}* $MNT/root/.inputrc ;;
    esac

    install_${LOGIN_TYPE:-xinit}
}

install_xinit()
{
    if [[ -e $MNT/home/$NEWUSER/.xinitrc ]] && grep -q 'exec' $MNT/home/$NEWUSER/.xinitrc; then
        sed -i "/exec/ c exec ${LOGIN_WM}" $MNT/home/$NEWUSER/.xinitrc
    else
        printf "exec %s\n" "$LOGIN_WM" >> $MNT/home/$NEWUSER/.xinitrc
    fi

    [[ ${EDIT_FILES[login]} == *"$LOGINRC"* ]] || EDIT_FILES[login]+=" /home/$NEWUSER/$LOGINRC"

    if [[ $AUTOLOGIN == true ]]; then
        sed -i "s/root/${NEWUSER}/g" $SERVICE/autologin.conf
        cat > $MNT/home/$NEWUSER/$LOGINRC << EOF
# ~/$LOGINRC
# sourced by $(basename $MYSHELL) when used as a login shell

# automatically run startx when logging in on tty1
[[ ! \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx -- vt1

EOF
    else
        rm -rf $SERVICE
        rm -rf $MNT/home/$NEWUSER/.{profile,zprofile,bash_profile}
    fi
}

install_lightdm()
{
    rm -rf $SERVICE
    rm -rf $MNT/home/$NEWUSER/.{xinitrc,profile,zprofile,bash_profile}
    chrun 'systemctl set-default graphical.target && systemctl enable lightdm.service' 2>$ERR
    errshow 1 "systemctl set-default graphical.target && systemctl enable lightdm.service"
    cat > $MNT/etc/lightdm/lightdm-gtk-greeter.conf << EOF
# LightDM GTK+ Configuration

[greeter]
active-monitor=0
default-user-image=/usr/share/icons/ArchLabs-Dark/64x64/places/distributor-logo-archlabs.png
background=/usr/share/backgrounds/archlabs/archlabs.jpg
theme-name=Adwaita-dark
icon-theme-name=Adwaita
font-name=DejaVu Sans Mono 11
position=30%,end 50%,end
EOF
}

install_packages()
{
    local rmpkg="archlabs-installer"
    local inpkg="$BASE_PKGS $PACKAGES $USER_PKGS"

    [[ $MYSHELL == *mksh* ]] && inpkg+=" mksh"

    if [[ $KERNEL == 'linux-lts' ]]; then
        inpkg+=" linux-lts"; rmpkg+=" linux"
    elif [[ $KERNEL == 'linux-zen' ]]; then
        inpkg+=" linux-zen"; rmpkg+=" linux"
    elif [[ $KERNEL == 'linux-hardened' ]]; then
        inpkg+=" linux-hardened"; rmpkg+=" linux"
    fi

    [[ $BOOTLDR == 'grub' ]] || rmpkg+=" grub os-prober"
    [[ $BOOTLDR == 'refind-efi' ]] || rmpkg+=" refind-efi"

    if ! [[ $inpkg =~ (term|urxvt|tilix|alacritty|sakura|tilda|gnome|xfce|plasma|cinnamon) ]] && [[ $INSTALL_WMS != *dwm* ]]
    then
        inpkg+=" xterm"
    fi

    [[ $MYSHELL == '/usr/bin/zsh' ]] && inpkg+=" zsh-completions zsh-history-substring-search"
    [[ $INSTALL_WMS =~ (openbox|bspwm|i3-gaps|dwm) ]] && inpkg+=" $WM_BASE_PKGS"
    [[ $INSTALL_WMS =~ ^(plasma|gnome|cinnamon)$ ]] || inpkg+=" archlabs-ksuperkey"

    chrun "pacman -Syyu --noconfirm" 2>/dev/null
    chrun "pacman -Rns $rmpkg --noconfirm" 2>/dev/null
    chrun "pacman -S iputils --noconfirm" 2>/dev/null
    chrun "pacman -S $inpkg --needed --noconfirm" 2>/dev/null

    sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" $MNT/etc/sudoers
    return 0
}

install_suckless()
{
    # install and setup dwm
    printf "Installing and setting up dwm\n"
    mkdir -pv $MNT/home/$NEWUSER/suckless

    for i in dwm dmenu st; do
        if chrun "git clone https://bitbucket.org/natemaia/$i /home/$NEWUSER/suckless/$i"; then
            chrun "cd /home/$NEWUSER/suckless/$i; rm -f config.h; make clean install; make clean"
        else
            printf "failed to clone $i repo\n"
        fi
    done

    if [[ -d $MNT/home/$NEWUSER/suckless/dwm && -x $MNT/usr/bin/dwm ]]; then
        printf "To configure dwm edit /home/$NEWUSER/suckless/dwm/config.h\n"
        printf "You can then recompile it with 'sudo make clean install'\n"
        sleep 2
    fi
}

install_mirrorlist()
{
    printf "Sorting the mirrorlist\n"
    if hash reflector >/dev/null 2>&1; then
        $MIRROR_CMD --save $MNT/etc/pacman.d/mirrorlist --verbose ||
            reflector --score 100 -l 50 -f 10 --sort rate --verbose --save $MNT/etc/pacman.d/mirrorlist
    else
        { eval $MIRROR_CMD || curl -s 'https://www.archlinux.org/mirrorlist/all/'; } |
            sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -v -t -n 10 - > $MNT/etc/pacman.d/mirrorlist
    fi
}

install_mkinitcpio()
{
    local add=""
    [[ $LUKS && $LUKS_PASS && $SYS == 'UEFI' && $BOOTLDR == 'grub' ]] && luks_keyfile
    [[ $LUKS ]] && add="encrypt"
    [[ $LVM ]] && { [[ $add ]] && add+=" lvm2" || add+="lvm2"; }
    sed -i "s/block filesystems/block ${add} filesystems ${HOOKS}/g" $MNT/etc/mkinitcpio.conf
    chrun "mkinitcpio -p $KERNEL" 2>$ERR
    errshow 1 "mkinitcpio -p $KERNEL"
}

###############################################################################
# bootloader setup

install_boot()
{
    if [[ $ROOT_PART == */dev/mapper* ]]; then
        ROOT_PART_ID="$ROOT_PART"
    elif [[ $BOOTLDR == 'syslinux' ]]; then
        ROOT_PART_ID="UUID=$(blkid -s UUID -o value $ROOT_PART)"
    elif [[ $BOOTLDR == 'systemd-boot' || $BOOTLDR == 'refind-efi' ]]; then
        ROOT_PART_ID="PARTUUID=$(blkid -s PARTUUID -o value $ROOT_PART)"
    fi

    if [[ $SYS == 'UEFI' ]]; then
        find $MNT/boot/EFI/ -maxdepth 1 -mindepth 1 \
            -name '[aA][rR][cC][hH][lL]abs' -type d -exec rm -rf '{}' \; >/dev/null 2>&1
        find $MNT/boot/EFI/ -maxdepth 1 -mindepth 1 \
            -name '[Bb][oO][oO][tT]' -type d -exec rm -rf '{}' \; >/dev/null 2>&1
    fi

    if [[ $BOOTLDR != 'grub' ]]; then
        rm -f $MNT/etc/default/grub 2>/dev/null
        find $MNT/boot/ -name 'grub*' -exec rm -rf '{}' \; >/dev/null 2>&1
    fi

    if [[ $BOOTLDR != 'syslinux' ]]; then
        find $MNT/boot/ -name 'syslinux*' -exec rm -rf '{}' \; >/dev/null 2>&1
    fi

    printf "Installing and setting up $BOOTLDR\n"
    prerun_$BOOTLDR
    chrun "${BCMDS[$BOOTLDR]}" 2>$ERR
    errshow 1 "${BCMDS[$BOOTLDR]}"

    if [[ -d $MNT/hostrun ]]; then
        umount $MNT/hostrun/udev >/dev/null 2>&1
        umount $MNT/hostrun/lvm >/dev/null 2>&1
        rm -rf $MNT/hostrun >/dev/null 2>&1
    fi

    if [[ $SYS == 'UEFI' ]]; then
        # some UEFI firmware require a generic esp/BOOT/BOOTX64.EFI
        # see:  https://wiki.archlinux.org/index.php/GRUB#UEFI
        # also: https://wiki.archlinux.org/index.php/syslinux#UEFI_Systems
        mkdir -pv $MNT/boot/EFI/BOOT
        if [[ $BOOTLDR == 'grub' ]]; then
            cp -fv $MNT/boot/EFI/$DIST/grubx64.efi $MNT/boot/EFI/BOOT/BOOTX64.EFI
        elif [[ $BOOTLDR == 'syslinux' ]]; then
            cp -rf $MNT/boot/EFI/syslinux/* $MNT/boot/EFI/BOOT/
            cp -f $MNT/boot/EFI/syslinux/syslinux.efi $MNT/boot/EFI/BOOT/BOOTX64.EFI
        elif [[ $BOOTLDR == 'refind-efi' ]]; then
            sed -i '/#extra_kernel_version_strings/ c extra_kernel_version_strings linux-hardened,linux-zen,linux-lts,linux' $MNT/boot/EFI/refind/refind.conf
            cp -fv $MNT/boot/EFI/refind/refind_x64.efi $MNT/boot/EFI/BOOT/BOOTX64.EFI
        fi
    fi

    return 0
}

setup_boot()
{
    tput civis
    if [[ $SYS == 'BIOS' ]]; then
        BOOTLDR="$(menubox "Bootloader" "\nSelect which bootloader to use." \
            "grub" "The Grand Unified Bootloader, standard among many Linux distributions" \
            "syslinux" "A collection of boot loaders for booting drives, CDs, or over the network")"

    else
        BOOTLDR="$(menubox "Bootloader" "\nSelect which bootloader to use." \
            "systemd-boot" "A simple UEFI boot manager which executes configured EFI images" \
            "grub" "The Grand Unified Bootloader, standard among many Linux distributions" \
            "refind-efi" "A UEFI boot manager that aims to be platform neutral and simplify multi-boot" \
            "syslinux" "A collection of boot loaders for booting drives, CDs, or over the network (no chainloading support)")"

    fi

    [[ $BOOTLDR ]] || return 1
    if [[ $BOOT_PART ]]; then
        mount_partition "$BOOT_PART" "/boot" && SEP_BOOT=true || return 1
        setup_boot_device
    fi
    setup_${BOOTLDR} || return 1
}

setup_grub()
{
    EDIT_FILES[bootloader]="/etc/default/grub"

    if [[ $SYS == 'BIOS' ]]; then
        [[ $BOOT_DEV ]] || { select_device 1 || return 1; }
        BCMDS[grub]="grub-install --recheck --force --target=i386-pc $BOOT_DEV"
    else
        if [[ $ROOT_PART == */dev/mapper/* && ! $LVM && ! $LUKS_PASS ]]; then
            luks_pass "$_LuksOpen" 1 || return 1
        fi
        BCMDS[grub]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true &&
              grub-install --recheck --force --target=x86_64-efi --efi-directory=/boot --bootloader-id=$DIST"

        grep -q /sys/firmware/efi/efivars <<< "$(mount)" || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
    fi

    BCMDS[grub]="mkdir -p /run/udev /run/lvm &&
              mount --bind /hostrun/udev /run/udev &&
              mount --bind /hostrun/lvm /run/lvm &&
              ${BCMDS[grub]} &&
              grub-mkconfig -o /boot/grub/grub.cfg &&
              sleep 1 && umount /run/udev /run/lvm"

    return 0
}

setup_syslinux()
{
    if [[ $SYS == 'BIOS' ]]; then
        EDIT_FILES[bootloader]="/boot/syslinux/syslinux.cfg"
    else
        EDIT_FILES[bootloader]="/boot/EFI/syslinux/syslinux.cfg"
        BCMDS[syslinux]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true &&
              efibootmgr -c -d $BOOT_DEV -p $BOOT_PART_NUM -l /EFI/syslinux/syslinux.efi -L $DIST -v"
    fi
}

setup_refind-efi()
{
    EDIT_FILES[bootloader]="/boot/refind_linux.conf"
    BCMDS[refind-efi]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true && refind-install"
}

setup_systemd-boot()
{
    EDIT_FILES[bootloader]="/boot/loader/entries/$DIST.conf"
    BCMDS[systemd-boot]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true && bootctl --path=/boot install"
}

prerun_grub()
{
    sed -i "s/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"${DIST}\"/g;
    s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/g" $MNT/etc/default/grub
    if [[ $LUKS_DEV ]]; then
        sed -i "s~#GRUB_ENABLE_CRYPTODISK~GRUB_ENABLE_CRYPTODISK~g;
        s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"${LUKS_DEV}\"~g" $MNT/etc/default/grub 2>$ERR
        errshow 1 "sed -i 's~#GRUB_ENABLE_CRYPTODISK~GRUB_ENABLE_CRYPTODISK~g;
        s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"${LUKS_DEV}\"~g' $MNT/etc/default/grub"
    fi
    if [[ $SYS == 'BIOS' && $LVM && $SEP_BOOT == false ]]; then
        sed -i "s/GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"lvm\"/g" $MNT/etc/default/grub 2>$ERR
        errshow 1 "sed -i 's/GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"lvm\"/g' $MNT/etc/default/grub"
    fi

    # setup for os-prober module
    mkdir -p /run/lvm
    mkdir -p /run/udev
    mkdir -p $MNT/hostrun/lvm
    mkdir -p $MNT/hostrun/udev
    mount --bind /run/lvm $MNT/hostrun/lvm
    mount --bind /run/udev $MNT/hostrun/udev

    return 0
}

prerun_syslinux()
{
    local c="$MNT/boot/syslinux" s="/usr/lib/syslinux/bios" d=".."
    if [[ $SYS == 'UEFI' ]]; then
        c="$MNT/boot/EFI/syslinux"; s="/usr/lib/syslinux/efi64/"; d=""
    fi

    mkdir -pv $c && cp -rfv $s/* $c/ && cp -f $RUN/syslinux/splash.png $c/
    cat > $c/syslinux.cfg << EOF
UI vesamenu.c32
MENU TITLE $DIST Boot Menu
MENU BACKGROUND splash.png
TIMEOUT 50
DEFAULT $DIST

# see: https://www.syslinux.org/wiki/index.php/Comboot/menu.c32
MENU WIDTH 78
MENU MARGIN 4
MENU ROWS 4
MENU VSHIFT 10
MENU TIMEOUTROW 13
MENU TABMSGROW 14
MENU CMDLINEROW 14
MENU HELPMSGROW 16
MENU HELPMSGENDROW 29
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL $DIST
MENU LABEL $DIST Linux
LINUX $d/vmlinuz-$KERNEL
APPEND root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
INITRD $([[ $UCODE ]] && printf "%s" "$d/$UCODE.img,")$d/initramfs-$KERNEL.img

LABEL ${DIST}fallback
MENU LABEL $DIST Linux Fallback
LINUX $d/vmlinuz-$KERNEL
APPEND root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
INITRD $([[ $UCODE ]] && printf "%s" "$d/$UCODE.img,")$d/initramfs-$KERNEL-fallback.img
$([[ $SYS == 'BIOS' ]] && printf "\n%s" "# examples of chainloading other bootloaders

#LABEL grub2
#MENU LABEL Grub2
#COM32 chain.c32
#APPEND file=$d/grub/boot.img

#LABEL windows
#MENU LABEL Windows
#COM32 chain.c32
#APPEND hd0 3")
EOF
    return 0
}

prerun_refind-efi()
{
    cat > $MNT/boot/refind_linux.conf << EOF
"$DIST Linux"          "root=$ROOT_PART_ID $([[ $LUKS_DEV ]] &&
                        printf "%s " "$LUKS_DEV")rw add_efi_memmap $([[ $UCODE ]] &&
                        printf "initrd=%s " "/$UCODE.img")initrd=/initramfs-$KERNEL.img"
"$DIST Linux Fallback" "root=$ROOT_PART_ID $([[ $LUKS_DEV ]] &&
                        printf "%s " "$LUKS_DEV")rw add_efi_memmap $([[ $UCODE ]] &&
                        printf "initrd=%s " "/$UCODE.img")initrd=/initramfs-$KERNEL-fallback.img"
EOF
    mkdir -p $MNT/etc/pacman.d/hooks
    cat > $MNT/etc/pacman.d/hooks/refind.hook << EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = refind-efi

[Action]
Description = Updating rEFInd on ESP
When = PostTransaction
Exec = /usr/bin/refind-install
EOF
}

prerun_systemd-boot()
{
    mkdir -p $MNT/boot/loader/entries
    cat > $MNT/boot/loader/loader.conf << EOF
default  $DIST
timeout  5
editor   no
EOF
    cat > $MNT/boot/loader/entries/$DIST.conf << EOF
title   $DIST Linux
linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/$UCODE.img")
initrd  /initramfs-$KERNEL.img
options root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
EOF
    cat > $MNT/boot/loader/entries/$DIST-fallback.conf << EOF
title   $DIST Linux Fallback
linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/$UCODE.img")
initrd  /initramfs-$KERNEL-fallback.img
options root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
EOF
    mkdir -p $MNT/etc/pacman.d/hooks
    cat > $MNT/etc/pacman.d/hooks/systemd-boot.hook << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF
    systemd-machine-id-setup --root="$MNT"
    return 0
}

###############################################################################
# lvm functions

lvm_menu()
{
    lvm_detect
    tput civis

    local choice
    choice="$(dialog --cr-wrap --stdout --backtitle "$BT" \
        --title " Logical Volume Management " --menu "$_LvmMenu" 0 0 0 \
        "$_LvmNew"    "vgcreate -f, lvcreate -L -n" \
        "$_LvmDel"    "vgremove -f" \
        "$_LvmDelAll" "lvrmeove, vgremove, pvremove -f" \
        "back"        "return to the main menu")"

    case $choice in
        "$_LvmNew") lvm_create || return 1 ;;
        "$_LvmDelVG")
            if lvm_show_vg && yesno "$_LvmDelVG" "$_LvmDelQ"; then
                vgremove -f "$DEL_VG" >/dev/null 2>&1
            fi
            lvm_menu
            ;;
        "$_LvMDelAll") lvm_del_all ;;
    esac

    return 0
}

lvm_detect()
{
    PHYSICAL_VOLUMES="$(pvs -o pv_name --noheading 2>/dev/null)"
    VOLUME_GROUP="$(vgs -o vg_name --noheading 2>/dev/null)"
    VOLUMES="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"

    if [[ $VOLUMES && $VOLUME_GROUP && $PHYSICAL_VOLUMES ]]; then
        infobox "Logical Volume Management" "$_LvmDetBody" 1
        modprobe dm-mod >/dev/null 2>$ERR
        errshow 'modprobe dm-mod'
        vgscan >/dev/null 2>&1
        vgchange -ay >/dev/null 2>&1
    fi
}

lvm_show_vg()
{
    DEL_VG=""
    VOL_GROUP_LIST=""
    for i in $(lvs --noheadings | awk '{print $2}' | uniq); do
        VOL_GROUP_LIST="$VOL_GROUP_LIST $i $(vgdisplay "$i" | awk '/VG Size/ {print $3$4}')"
    done
    [[ $VOL_GROUP_LIST == "" ]] && { msgbox "$_ErrTitle" "$_LvmVGErr"; return 1; }
    tput civis
    DEL_VG="$(menubox "Logical Volume Management" "$_LvmSelVGBody" $VOL_GROUP_LIST)"
    [[ $DEL_VG ]]
}

get_lv_size()
{
    tput cnorm
    local ttl=" $_LvmNew (LV:$VOL_COUNT) "
    local msg="${VOLUME_GROUP}: ${GROUP_SIZE}$GROUP_SIZE_TYPE (${VGROUP_MB}MB $_LvmLvSizeBody1).$_LvmLvSizeBody2"
    VOLUME_SIZE="$(getinput "$ttl" "$msg" "")"
    [[ $VOLUME_SIZE ]] || return 1
    ERR_SIZE=0
    (( ${#VOLUME_SIZE} == 0 || ${VOLUME_SIZE:0:1} == 0 )) && ERR_SIZE=1

    if (( ERR_SIZE == 0 )); then
        local lv="$((${#VOLUME_SIZE} - 1))"
        for (( i=0; i<lv; i++ )); do
            [[ ${VOLUME_SIZE:$i:1} != [0-9] ]] && { ERR_SIZE=1; break; }
        done
        if (( ERR_SIZE == 0 )); then
            case ${VOLUME_SIZE:$lv:1} in
                [mMgG]) ERR_SIZE=0 ;;
                *) ERR_SIZE=1
            esac
            if (( ERR_SIZE == 0 )); then
                local s=${VOLUME_SIZE:0:$lv}
                local m=$((s * 1000))
                case ${VOLUME_SIZE:$lv:1} in
                    [Gg]) (( m >= VGROUP_MB )) && ERR_SIZE=1 || VGROUP_MB=$((VGROUP_MB - m)) ;;
                    [Mm]) (( ${VOLUME_SIZE:0:$lv} >= VGROUP_MB )) && ERR_SIZE=1 || VGROUP_MB=$((VGROUP_MB - s)) ;;
                    *) ERR_SIZE=1
                esac
            fi
        fi
    fi

    if (( ERR_SIZE == 1 )); then
        msgbox "LVM Size Error" "$_LvmLvSizeErrBody"
        get_lv_size || return 1
    fi

    return 0
}

lvm_volume_name()
{
    local msg="$1" default="mainvolume" name="" err=0
    (( VOL_COUNT > 1 )) && default="extravolume$VOL_COUNT"

    while true; do
        tput cnorm
        name="$(getinput "$_LvmNew (LV:$VOL_COUNT)" "\n$msg" "$default" nolimit)"
        [[ $name ]] || { err=1; break; }
        if [[ ${name:0:1} == "/" || ${#name} -eq 0 || $name =~ \ |\' ]] || grep -q "$name" <<< "$(lsblk)"; then
            msgbox "$_ErrTitle" "$_LvmLvNameErrBody"
        else
            VOLUME_NAME="$name"
            break
        fi
    done

    return $err
}

lvm_group_name()
{
    local group="" err=0

    while true; do
        tput cnorm
        group="$(getinput "$_LvmNew" "$_LvmNameVgBody" "VolGroup" nolimit)"
        [[ $group ]] || { err=1; break; }
        if [[ ${group:0:1} == "/" || ${#group} -eq 0 || $group =~ \ |\' ]] || grep -q "$group" <<< "$(lsblk)"; then
            msgbox "$_ErrTitle" "$_LvmNameVgErr"
        else
            VOLUME_GROUP="$group"
            break
        fi
    done

    return $err
}

lvm_extra_lvs()
{
    local err=0

    while (( VOL_COUNT > 1 )); do
        lvm_volume_name "$_LvmLvNameBody1" && get_lv_size || { err=1; break; }
        lvcreate -L "$VOLUME_SIZE" "$VOLUME_GROUP" -n "$VOLUME_NAME" >/dev/null 2>$ERR
        errshow "lvcreate -L $VOLUME_SIZE $VOLUME_GROUP -n $VOLUME_NAME" || { err=1; break; }
        msgbox "$_LvmNew (LV:$VOL_COUNT)" "\nDone, logical volume (LV) $VOLUME_NAME ($VOLUME_SIZE) has been created.\n"
        (( VOL_COUNT-- ))
    done

    return $err
}

lvm_partitions()
{
    find_partitions 'part|crypt' || return 1
    PARTS="$(awk 'NF > 0 {print $0 " off"}' <<< "$PARTS")"

    tput civis
    LVM_PARTS=($(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
        --title " $_LvmNew " --checklist "$_LvmPvSelBody" 0 0 0 $PARTS))

    (( ${#LVM_PARTS[@]} >= 1 ))
}

lvm_mkgroup()
{
    lvm_group_name || return 1

    local msg="$_LvmPvConfBody1 $VOLUME_GROUP\n\n$_LvmPvConfBody2"
    while ! yesno "$_LvmNew" "$msg ${LVM_PARTS[*]}\n"; do
        lvm_partitions || { break; return 1; }
        lvm_group_name || { break; return 1; }
    done

    vgcreate -f "$VOLUME_GROUP" "${LVM_PARTS[@]}" >/dev/null 2>$ERR
    errshow "vgcreate -f $VOLUME_GROUP ${LVM_PARTS[*]}" || return 1

    GROUP_SIZE=$(vgdisplay "$VOLUME_GROUP" | awk '/VG Size/ {
        gsub(/[^0-9.]/, "")
        print int($0)
    }')

    GROUP_SIZE_TYPE="$(vgdisplay "$VOLUME_GROUP" | awk '/VG Size/ {
        print substr($NF, 0, 1)
    }')"

    if [[ $GROUP_SIZE_TYPE == 'G' ]]; then
        VGROUP_MB=$((GROUP_SIZE * 1000))
    else
        VGROUP_MB=$GROUP_SIZE
    fi
    msgbox "$_LvmNew" "\nVolume group: $VOLUME_GROUP ($GROUP_SIZE $GROUP_SIZE_TYPE) has been created\n"
}

lvm_create()
{
    VOLUME_GROUP=""; LVM_PARTS=(); VGROUP_MB=0
    umount_dir $MNT
    lvm_partitions || return 1
    lvm_mkgroup || return 1
    VOL_COUNT=$(menubox "$_LvmNew" "$_LvmLvNumBody1 $VOLUME_GROUP\n$_LvmLvNumBody2" 0 0 0 \
        "1" "-" "2" "-" "3" "-" "4" "-" "5" "-" "6" "-" "7" "-" "8" "-" "9" "-")

    [[ $VOL_COUNT ]] || return 1

    lvm_extra_lvs || return 1
    lvm_volume_name "$_LvmLvNameBody1 $_LvmLvNameBody2 (${VGROUP_MB}MB)" || return 1
    lvcreate -l +100%FREE "$VOLUME_GROUP" -n "$VOLUME_NAME" >/dev/null 2>$ERR
    errshow "lvcreate -l +100%FREE $VOLUME_GROUP -n $VOLUME_NAME" || return 1
    LVM='logical volume'; tput civis; sleep 0.5
    local msg="\nDone, volume: $VOLUME_GROUP-$VOLUME_NAME (${VOLUME_SIZE:-${VGROUP_MB}MB}) has been created.\n"
    msgbox "$_LvmNew (LV:$VOL_COUNT)" "$msg\n$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE "${LVM_PARTS[@]}")\n"
}

lvm_del_all()
{
    PHYSICAL_VOLUMES="$(pvs -o pv_name --noheading 2>/dev/null)"
    VOLUME_GROUP="$(vgs -o vg_name --noheading 2>/dev/null)"
    VOLUMES="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"

    if yesno "$_LvmDelAll" "$_LvmDelQ"; then
        for i in $VOLUMES; do
            lvremove -f "/dev/mapper/$i" >/dev/null 2>&1
        done
        for i in $VOLUME_GROUP; do
            vgremove -f "$i" >/dev/null 2>&1
        done
        for i in $PHYSICAL_VOLUMES; do
            pvremove -f "$i" >/dev/null 2>&1
        done
        LVM=''
    fi
}

###############################################################################
# luks functions

luks_menu()
{
    tput civis
    local choice
    choice="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " LUKS Encryption " \
        --menu "${_LuksMenuBody}${_LuksMenuBody2}${_LuksMenuBody3}" 0 0 0 \
        "$_LuksEncrypt"    "cryptsetup -q luksFormat" \
        "$_LuksOpen"       "cryptsetup open --type luks" \
        "$_LuksEncryptAdv" "cryptsetup -q -s -c luksFormat" \
        "back"             "Return to the main menu")"

    case $choice in
        "$_LuksEncrypt")    luks_basic || return 1 ;;
        "$_LuksOpen")       luks_open || return 1 ;;
        "$_LuksEncryptAdv") luks_advanced || return 1 ;;
    esac

    return 0
}

luks_open()
{
    modprobe -a dm-mod dm_crypt
    umount_dir $MNT
    find_partitions 'part|crypt|lvm' || return 1
    tput civis

    if (( COUNT == 1 )); then
        LUKS_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
    else
        LUKS_PART="$(menubox "$_LuksOpen" "$_LuksMenuBody" $PARTS)"
    fi
    [[ $LUKS_PART ]] || return 1

    luks_pass "$_LuksOpen" || return 1
    infobox "$_LuksOpen" "$_LuksOpenWaitBody $LUKS_NAME $_LuksWaitBody2 $LUKS_PART\n" 0
    cryptsetup open --type luks $LUKS_PART "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
    errshow "cryptsetup open --type luks $LUKS_PART $LUKS_NAME" || return 1
    LUKS='encrypted'; luks_show
    return 0
}

luks_pass()
{
    local t="$1" op="$2" v="" p="" p2="" err=0

    while true; do
        tput cnorm
        if [[ $op ]]; then
            v="$(dialog --stdout --no-cancel --separator ';:~:;' \
                --ok-label "Submit" --backtitle "$BT" --title " $title " --insecure --mixedform \
                "\nEnter the password to decrypt $ROOT_PART.\n\nThis is needed to create a keyfile." 0 0 0 \
                "Password:"  1 1 "" 1 11 $COLUMNS 0 1 \
                "Password2:" 2 1 "" 2 12 $COLUMNS 0 1)"

        else
            v="$(dialog --stdout --no-cancel --separator ';:~:;' \
                --ok-label "Submit" --backtitle "$BT" --title " $title " \
                --insecure --mixedform "$_LuksOpenBody" 0 0 0 \
                "Name:"      1 1 "${LUKS_NAME:-cryptroot}" 1 7 $COLUMNS 0 0 \
                "Password:"  2 1 ""                        2 11 $COLUMNS 0 1 \
                "Password2:" 3 1 ""                        3 12 $COLUMNS 0 1)"

        fi

        err=$?
        (( err == 0 )) || break

        if [[ $onlypass ]]; then
            p="$(awk -F';:~:;' '{print $1}' <<< "$v")"
            p2="$(awk -F';:~:;' '{print $2}' <<< "$v")"
        else
            n="$(awk -F';:~:;' '{print $1}' <<< "$v")"
            p="$(awk -F';:~:;' '{print $2}' <<< "$v")"
            p2="$(awk -F';:~:;' '{print $3}' <<< "$v")"
        fi

        if [[ ! $op && $n == "" ]]; then
            infobox "Name Empty" "\nEncrypted device name cannot be empty.\n\nPlease try again.\n"
        elif [[ $p == "" || "$p" != "$p2" ]]; then
            [[ $op ]] || LUKS_NAME="$n"
            infobox "Password Mismatch" "\nThe passwords entered do not match.\n\nPlease try again.\n"
        else
            [[ $op ]] || LUKS_NAME="$n"
            LUKS_PASS="$p"
            break
        fi
    done

    return $err
}

luks_setup()
{
    modprobe -a dm-mod dm_crypt
    umount_dir $MNT
    find_partitions 'part|lvm' || return 1
    tput civis

    if (( COUNT == 1 )); then
        LUKS_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
    else
        LUKS_PART="$(menubox "$_LuksEncrypt" "$_LuksEncryptBody" $PARTS)"
    fi

    [[ $LUKS_PART ]] || return 1
    luks_pass "$_LuksEncrypt"
}

luks_basic()
{
    luks_setup || return 1
    infobox "$_LuksEncrypt" "$_LuksCreateWaitBody $LUKS_NAME $_LuksWaitBody2 $LUKS_PART\n" 0
    cryptsetup -q luksFormat $LUKS_PART <<< "$LUKS_PASS" 2>$ERR
    errshow "cryptsetup -q luksFormat $LUKS_PART" || return 1
    cryptsetup open $LUKS_PART "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
    errshow "cryptsetup open $LUKS_PART $LUKS_NAME" || return 1
    LUKS='encrypted'; luks_show
    return 0
}

luks_advanced()
{
    if luks_setup; then
        tput cnorm
        local cipher
        cipher="$(getinput "LUKS Encryption" "$_LuksCipherKey" "-s 512 -c aes-xts-plain64" nolimit)"
        [[ $cipher ]] || return 1
        infobox "$_LuksEncryptAdv" "$_LuksCreateWaitBody $LUKS_NAME $_LuksWaitBody2 $LUKS_PART\n" 0
        cryptsetup -q $cipher luksFormat $LUKS_PART <<< "$LUKS_PASS" 2>$ERR
        errshow "cryptsetup -q $cipher luksFormat $LUKS_PART" || return 1
        cryptsetup open $LUKS_PART "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
        errshow "cryptsetup open $LUKS_PART $LUKS_NAME" || return 1
        luks_show
        return 0
    fi
    return 1
}

luks_show()
{
    tput civis
    sleep 0.5
    msgbox "$_LuksEncrypt" "${_LuksEncryptSucc}\n\n$(lsblk $LUKS_PART -o NAME,MODEL,SIZE,TYPE,FSTYPE)\n\n"
}

luks_keyfile()
{
    if [[ ! -e $MNT/crypto_keyfile.bin && $LUKS_PASS && $LUKS_UUID ]]; then
        printf "Creating LUKS keyfile /crypto_keyfile.bin\n"
        local n
        n="$(lsblk -lno NAME,UUID,TYPE | awk "/$LUKS_UUID/"' && /part|crypt|lvm/ {print $1}')"
        local mkkey="dd bs=512 count=8 if=/dev/urandom of=/crypto_keyfile.bin"
        mkkey="$mkkey && chmod 000 /crypto_keyfile.bin"
        mkkey="$mkkey && cryptsetup luksAddKey /dev/$n /crypto_keyfile.bin <<< '$LUKS_PASS'"
        chrun "$mkkey"
        sed -i 's/FILES=()/FILES=(\/crypto_keyfile.bin)/g' $MNT/etc/mkinitcpio.conf 2>$ERR
    fi

    return 0
}

###############################################################################
# helper functions

ofn()
{
    [[ $USER_PKGS == *"$1"* ]] && printf "on" || printf "off"
}

chrun()
{
    arch-chroot $MNT /bin/bash -c "$1"
}

json()
{
    curl -s "http://api.ipstack.com/$2" | python3 -c "import sys, json; print(json.load(sys.stdin)['$1'])"
}

is_ssd()
{
    local i dev=$1

    # check for LVM and or LUKS for their origin devices
    if [[ $LUKS && ! $LVM && $dev =~ $LUKS_NAME ]]; then
        dev="${LUKS_PART}"
    elif [[ $LVM && ! $LUKS && ${#LVM_PARTS[@]} -eq 1 && ${LVM_PARTS[*]} =~ $dev ]]; then
        dev="${LVM_PARTS[*]}"
    fi

    dev=${dev#/dev/}
    [[ $dev =~ nvme ]] && dev=${dev%p[0-9]*} || dev=${dev%[0-9]*}
    i=$(cat /sys/block/$dev/queue/rotational 2>/dev/null)
    (( ${i:-1} == 0 ))
}

die()
{
    (( $# >= 1 )) && exitcode=$1 || exitcode=0
    trap - INT
    tput cnorm

    if [[ -d $MNT ]] && command cd /; then
        umount_dir $MNT
        if (( exitcode == 127 )); then
            umount -l /run/archiso/bootmnt; sleep 0.5; systemctl -i reboot
        fi
    fi

    if [[ $TERM == 'linux' ]]; then
        # restore custom linux console 0-15 colors when not rebooting
        colors=("\e]P0191919" "\e]P1D15355" "\e]P2609960" "\e]P3FFCC66"
        "\e]P4255A9B" "\e]P5AF86C8" "\e]P62EC8D3" "\e]P7949494" "\e]P8191919" "\e]P9D15355"
        "\e]PA609960" "\e]PBFF9157" "\e]PC4E88CF" "\e]PDAF86C8" "\e]PE2ec8d3" "\e]PFE1E1E1"
        )
        for col in "${colors[@]}"; do
            printf "$col"
        done
    fi

    exit $exitcode
}

sigint()
{
    printf "\n^C caught, cleaning up...\n"
    die 1
}

print4()
{
    local str="$*"
    if [[ $COLUMNS -ge 110 && ${#str} -gt $((COLUMNS - 30)) ]]; then
        str="$(awk '{
            i=2; p1=p2=p3=p4=""; p1=$1; q=int(NF / 4)
            for (;i<=q;   i++) { p1=p1" "$i }
            for (;i<=q*2; i++) { p2=p2" "$i }
            for (;i<=q*3; i++) { p3=p3" "$i }
            for (;i<=NF;  i++) { p4=p4" "$i }
            printf "%s\n           %s\n           %s\n           %s", p1, p2, p3, p4
        }' <<< "$str")"
        printf "%s\n" "$str"
    elif [[ $str ]]; then
        printf "%s\n" "$str"
    fi
}

system_devices()
{
    IGNORE_DEV="$(lsblk -lno NAME,MOUNTPOINT |
        awk '/\/run\/archiso\/bootmnt/ {sub(/[1-9]/, ""); print $1}')"

    if [[ $IGNORE_DEV ]]; then
        SYS_DEVS="$(lsblk -lno NAME,SIZE,TYPE |
            awk '/disk/ && !'"/$IGNORE_DEV/"' {print "/dev/" $1 " " $2}')"
    else
        SYS_DEVS="$(lsblk -lno NAME,SIZE,TYPE |
            awk '/disk/ {print "/dev/" $1 " " $2}')"
    fi

    [[ $SYS_DEVS ]] || { infobox "$_ErrTitle" "\nNo available devices...\n\nExiting..\n"; die 1; }
    DEV_COUNT="$(wc -l <<< "$SYS_DEVS")"
}

system_identify()
{
    local efidir="/sys/firmware/efi"

    if [[ $VM ]]; then
        UCODE=""
    elif grep -q 'AuthenticAMD' /proc/cpuinfo; then
        UCODE="amd-ucode"
    elif grep -q 'GenuineIntel' /proc/cpuinfo; then
        UCODE="intel-ucode"
    fi

    if grep -qi 'apple' /sys/class/dmi/id/sys_vendor; then
        modprobe -r -q efivars
    else
        modprobe -q efivarfs
    fi

    if [[ -d $efidir ]]; then
        SYS="UEFI"
        grep -q $efidir/efivars <<< "$(mount)" || mount -t efivarfs efivarfs $efidir/efivars
    else
        SYS="BIOS"
    fi

    BT="$DIST Installer - $SYS - v$VER"
}

load_bcm()
{
    infobox "Broadcom Wireless Setup" "\nLoading broadcom wifi kernel modules please wait...\n" 0
    rmmod wl >/dev/null 2>&1
    rmmod bcma >/dev/null 2>&1
    rmmod b43 >/dev/null 2>&1
    rmmod ssb >/dev/null 2>&1
    modprobe wl >/dev/null 2>&1
    depmod -a >/dev/null 2>&1
    BROADCOM_WL=true
}

chk_connect()
{
    if [[ $CHECKED_NET == true ]]; then
        infobox "Network Connect" "\nVerifying network connection\n" 1
    else
        infobox "Network Connect" "\nChecking connection to https://www.archlinux.org\n" 1
        CHECKED_NET=true
    fi
    curl -sI --connect-timeout 5 'https://www.archlinux.org/' | sed '1q' | grep -q '200'
}

net_connect()
{
    if ! chk_connect; then
        if [[ $(systemctl is-active NetworkManager) == "active" ]] && hash nmtui >/dev/null 2>&1; then
            tput civis
            printf "\e]P1191919"
            printf "\e]P4191919"
            nmtui-connect
            printf "\e]P1D15355"
            printf "\e]P4255a9b"
            chk_connect || return 1
        else
            return 1
        fi
    fi
    return 0
}

system_checks()
{
    if [[ $(whoami) != "root" ]]; then
        infobox "Not Root" "\nThis installer must be run as root or using sudo.\n\nExiting..\n"
        die 1
    elif ! grep -qw 'lm' /proc/cpuinfo; then
        infobox "Not x86_64" "\nThis installer only supports x86_64 architectures.\n\nExiting..\n"
        die 1
    fi

    grep -q 'BCM4352' <<< "$(lspci -vnn -d 14e4:)" && load_bcm

    if ! net_connect; then
        infobox "Not Connected" "\nThis installer requires an active internet connection.\n\nExiting..\n"
        die 1
    fi
}

prechecks()
{
    if [[ $1 -ge 0 ]] && ! [[ $(lsblk -lno MOUNTPOINT) =~ $MNT ]]; then
        infobox "Not Mounted" "\nPartition(s) must be mounted first.\n"; SEL=4; return 1
    elif [[ $1 -ge 1 && ($NEWUSER == "" || $USER_PASS == "") ]]; then
        infobox "No User" "\nA user must be created first.\n"; SEL=5; return 1
    elif [[ $1 -ge 2 && $CONFIG_DONE != true ]]; then
        infobox "Not Configured" "\nSystem configuration must be done first.\n"; SEL=6; return 1
    fi

    return 0
}

errshow()
{
    last_exit_code=$?
    (( last_exit_code == 0 )) && return 0
    local err="$(sed 's/[^[:print:]]//g; s/\[[0-9\;:]*\?m//g; s/==> //g; s/] ERROR:/]\nERROR:/g' "$ERR")"

    if [[ $err ]]; then
        msgbox "$_ErrTitle" "\nThe command exited abnormally: $1\n\nWith the following message: $err"
    else
        msgbox "$_ErrTitle" "\nThe command exited abnormally: $1\n\nWith the no error message.\n"
    fi

    if [[ $1 == 1 ]]; then
        [[ -e $DBG && $TERM == 'linux' ]] && less $DBG
        die 1
    fi

    return 1
}

debug()
{
    set -x
    exec 3>| $DBG
    BASH_XTRACEFD=3
    DEBUG=true
}

umount_dir()
{
    swapoff -a
    [[ -d $1 ]] && umount -R $1 >/dev/null 2>&1
    return 0
}

msgbox()
{
    tput civis
    dialog --cr-wrap --backtitle "$BT" --title " $1 " --msgbox "$2\n" 0 0
}

menubox()
{
    local title="$1"
    local body="$2"
    shift 2
    local response
    if ! response="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " $title " --menu "$body" 0 0 0 "$@")"; then
        return 1
    fi
    printf "%s" "$response"
}

checkbox()
{
    local title="$1"
    local body="$2"
    shift 2
    local response
    if ! response="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " $title " --checklist "$body" 0 0 0 "$@")"; then
        return 1
    fi
    printf "%s" "$response"
}

getinput()
{
    local answer
    if [[ $# -eq 4 && $4 == 'nolimit' ]]; then
        answer="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " $1 " --inputbox "$2" 0 0 "$3")"
    else
        answer="$(dialog --cr-wrap --max-input 63 --stdout --backtitle "$BT" --title " $1 " --inputbox "$2" 0 0 "$3")"
    fi

    local e=$?
    [[ $e -ne 0 || $answer == "" ]] && return 1
    printf "%s" "$answer"
}

infobox()
{
    local sec="$3"
    tput civis
    dialog --cr-wrap --backtitle "$BT" --title " $1 " --infobox "$2\n" 0 0
    sleep ${sec:-2}
}

yesno()
{
    tput civis
    if [[ $# -eq 5 && $5 == "no" ]]; then
        dialog --cr-wrap --backtitle "$BT" --defaultno --title " $1 " --yes-label "$3" --no-label "$4" --yesno "$2\n" 0 0
    elif [[ $# -eq 4 ]]; then
        dialog --cr-wrap --backtitle "$BT" --title " $1 " --yes-label "$3" --no-label "$4" --yesno "$2\n" 0 0
    else
        dialog --cr-wrap --backtitle "$BT" --title " $1 " --yesno "$2\n" 0 0
    fi
}

###############################################################################
# entry point

trap sigint INT

for arg in "$@"; do
    [[ $arg =~ (--debug|-d) ]] && debug
done

system_checks
system_identify
system_devices
msgbox "$_WelTitle $DIST Installer" "$_WelBody"
select_keymap || { clear; die 0; }

while true; do
    main
done
