#!/usr/bin/bash

# vim:fdm=marker:fmr={,}
# shellcheck disable=2154

# This program is free software, provided under the GNU GPL
# Written by Nathaniel Maia for use in Archlabs
# Some ideas and code has been taken from other installers
# AIF, Cnichi, Calamares, The Arch Wiki.. Credit where credit is due

VER="1.8.1"                              # Installer version
DIST="ArchLabs"                          # Installer distributor
MNT="/mnt"                               # Installer mountpoint
ERR="/tmp/errlog"                        # error log used internally
DBG="/tmp/debuglog"                      # debug log when passed -d
RUN="/run/archiso/bootmnt/arch/boot"     # path for live /boot
LNG="/usr/share/archlabs/installer/lang" # translation file path
BT="$DIST Installer - v$VER"             # backtitle used for dialogs
VM="$(dmesg | grep -i "hypervisor")"     # is the system a vm

ROOT_PART=""      # root partition
BOOT_PART=""      # boot partition
BOOT_DEVICE=""    # device used for BIOS grub install
AUTO_BOOT_PART="" # filled with the boot partition from autopartiton()
BOOTLDR=""        # bootloader selected
EXTRA_MNT=""      # holder for additional partitions while mounting
EXTRA_MNTS=""     # when an extra partition is mounted append it's info
SWAP_PART=""      # swap partition or file path
SWAP_SIZE=""      # when using a swapfile use this size
NEWUSER=""        # username for the primary user
USER_PASS=""      # password for the primary user
ROOT_PASS=""      # root password
LOGIN_WM=""       # default login session
LOGIN_TYPE=""     # login manager can be lightdm or xinit
INSTALL_WMS=""    # space separated list of chosen wm/de
KERNEL=""         # kernel can be linux or linux-lts
WM_PACKAGES=""    # full list of packages added during wm/de choice
PACKAGES=""       # list of all packages to install including WM_PACKAGES
MYSHELL=""        # login shell for root and the primary user
UCODE=""          # cpu manufacturer microcode filename (if any)
HOOKS="shutdown"  # list of additional HOOKS to add in /etc/mkinitcpio.conf

LUKS=""           # empty when not using luks encryption
LUKS_DEV=""       # device used for encryption
LUKS_PART=""      # partition used for encryption
LUKS_PASS=""      # encryption password
LUKS_UUID=""      # encrypted partition UUID
LUKS_NAME=""      # name used for encryption

LVM=""            # empty when not using lvm
GROUP_PARTS=""    # partitions used for volume group
VOL_GROUP_MB=0    # available space in volume group

WARN=false        # issued mounting/partitioning warning
CONFIG_DONE=false # basic configuration is finished
SEP_BOOT=false    # separate boot partition for BIOS
AUTOLOGIN=false   # enable autologin for xinit
BROADCOM_WL=false # fixes for broadcom cards eg. BCM4352

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
}')"

# various associative arrays
# {

# command used to install each bootloader
declare -A BCMDS=(
[syslinux]="syslinux-install_update -iam"
[grub]="grub-install --recheck --force"
[systemd-boot]="bootctl --path=/boot install"
)

# boot partition mount points for each bootloader
declare -A BMNTS=(
[BIOS-grub]="/boot"
[UEFI-grub]="/boot/efi"
[BIOS-syslinux]="/boot"
[UEFI-systemd-boot]="/boot"
)

# bootloader options with respective boot partition mountpoint
declare -A BOOTLDRS=(
[BIOS]="grub ${BMNTS[BIOS-grub]} syslinux ${BMNTS[BIOS-syslinux]}"
[UEFI]="systemd-boot ${BMNTS[UEFI-systemd-boot]} grub ${BMNTS[UEFI-grub]}"
)

# match the wm name with the actual session name used for xinit
declare -A WM_SESSIONS=(
[dwm]='dwm'
[i3-gaps]='i3'
[bspwm]='bspwm'
[xfce4]='startxfce4'
[plasma]='startkde'
[gnome]='gnome-session'
[openbox]='openbox-session'
[cinnamon]='cinnamon-session'
)

# additional packages installed for each wm/de
declare -A WM_EXT=(
[gnome]="gnome-extra"
[plasma]="kde-applications"
[bspwm]="sxhkd archlabs-skel-bspwm rofi archlabs-polybar"
[xfce4]="xfce4-goodies xfce4-pulseaudio-plugin archlabs-skel-xfce4"
[i3-gaps]="i3status perl-anyevent-i3 archlabs-skel-i3-gaps rofi archlabs-polybar"
[openbox]="obconf archlabs-skel-openbox jgmenu archlabs-polybar tint2 conky rofi"
)

# files the user can edit during the final stage of install
declare -A EDIT_FILES=(
[2]="/etc/X11/xorg.conf.d/00-keyboard.conf /etc/default/keyboard /etc/vconsole.conf"
[3]="/etc/locale.conf /etc/default/locale"
[4]="/etc/hostname /etc/hosts"
[5]="/etc/sudoers"
[6]="/etc/mkinitcpio.conf"
[7]="/etc/fstab"
[8]="/etc/crypttab"
[9]="/boot/loader/entries/$DIST.conf"
[10]="/etc/pacman.conf"
[11]="" # login files.. Populated later once login method is chosen
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
[kdenlive]="qt5ct qt5-styleplugins"
[qbittorrent]="qt5ct qt5-styleplugins"
[qutebrowser]="qt5ct qt5-styleplugins"
[kdenlive]="kdebase-runtime dvdauthor frei0r-plugins breeze breeze-gtk"
)

# mkfs command to format a partition as a given file system
declare -A FS_CMDS=(
[ext2]="mkfs.ext2 -q" [ext3]="mkfs.ext3 -q" [ext4]="mkfs.ext4 -q"
[f2fs]="mkfs.f2fs" [jfs]="mkfs.jfs -q" [xfs]="mkfs.xfs -f" [nilfs2]="mkfs.nilfs2 -q"
[ntfs]="mkfs.ntfs -q" [reiserfs]="mkfs.reiserfs -q" [vfat]="mkfs.vfat -F32"
)

# mount options for a given file system
declare -A FS_OPTS=([vfat]="" [ntfs]="" [ext2]="" [ext3]=""
[ext4]="discard - off dealloc - off nofail - off noacl - off relatime - off noatime - off nobarrier - off nodelalloc - off"
[jfs]="discard - off errors=continue - off errors=panic - off nointegrity - off"
[reiserfs]="acl - off nolog - off notail - off replayonly - off user_xattr - off"
[xfs]="discard - off filestreams - off ikeep - off largeio - off noalign - off nobarrier - off norecovery - off noquota - off wsync - off"
[nilfs2]="discard - off nobarrier - off errors=continue - off errors=panic - off order=relaxed - off order=strict - off norecovery - off"
[f2fs]="data_flush - off disable_roll_forward - off disable_ext_identify - off discard - off fastboot - off flush_merge - off inline_xattr - off inline_data - off inline_dentry - off no_heap - off noacl - off nobarrier - off noextent_cache - off noinline_data - off norecovery - off"
)
# }

###############################################################################
# utility functions

chrun()
{
    # run a shell command in the chroot dir $MNT
    arch-chroot $MNT /bin/bash -c "$1"
}

json()
{
    # get a value from http://api.ipstack.com in json format using my API key
    # this includes: ip, geolocation, country name
    curl -s "http://api.ipstack.com/$2" |
        python3 -c "import sys, json; print(json.load(sys.stdin)['$1'])"
}

src()
{
    # source file ($1), if it fails we die with an error message
    if ! . "$1" 2>/dev/null; then
        printf "\nFailed to source file %s\n" "$1"
        die 1
    fi
    return 0
}

ssd()
{
    # returns 0 (true) when the device passed ($1) is NOT a rotational device
    local dev=$1
    dev=${dev#/dev/}

    if [[ $dev =~ nvme ]]; then
        dev=${dev%p[0-9]*}
    else
        dev=${dev%[0-9]*}
    fi

    local i
    i=$(cat /sys/block/$dev/queue/rotational 2>/dev/null)
    [[ $i && $i -eq 0 ]] || return 1
}

die()
{
    if (( $# >= 1 )); then
        local exitcode=$1
    else
        local exitcode=0
    fi

    # reset SIGINT
    trap - INT

    tput cnorm
    if [[ -d $MNT ]] && command cd /; then
        umount_dir $MNT
        if (( exitcode == 127 )); then
            umount -l /run/archiso/bootmnt
            systemctl -i reboot
        fi
    fi

    rm -fv /tmp/.ai_*

    exit $exitcode
}

sigint()
{
    # used to trap SIGINT and cleanly exit the program
    printf "\nCTRL-C caught\nCleaning up...\n"
    die 1
}

print4()
{
    # takes an arbitrary number of input fields and prints them out in fourths on separate lines
    local str="$*"
    if [[ ${#str} -gt $(( ${COLUMNS:-$(tput cols)} / 2 )) ]]; then
        q=$(awk '{print int(NF / 4)}' <<< "$str")
        str="$(awk '{
            pkgs1=pkgs2=pkgs3=pkgs4=""
            for (i=1;i<'"$q"';i++) {
                if (i == 1) {
                    pkgs1=$i
                } else {
                    pkgs1=pkgs1" "$i
                }
            }
            for (i='"$q"';i<'"$((q * 2))"';i++) {
                pkgs2=pkgs2" "$i
            }
            for (i='"$((q * 2))"';i<'"$((q * 3))"';i++) {
                pkgs3=pkgs3" "$i
            }
            for (i='"$((q * 3))"';i<NF;i++) {
                pkgs4=pkgs4" "$i
            }
            printf "%s\n           %s\n           %s\n           %s", pkgs1, pkgs2, pkgs3, pkgs4
        }' <<< "$str")"
    fi
    printf "%s\n" "$str"
}

oneshot()
{
    [[ -e /tmp/.ai_$1 || ! $(type $1) ]] && return 0
    $1 || return 1
    touch "/tmp/.ai_$1"
    return 0
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

    DEV_COUNT="$(wc -l <<< "$SYS_DEVS")"
}

system_identify()
{
    local efidir="/sys/firmware/efi"

    # for virtual machine remove the ucode
    if ! [[ $VM ]] && grep -q 'GenuineIntel' /proc/cpuinfo; then
        UCODE="intel-ucode"
    elif ! [[ $VM ]] && grep -q 'AuthenticAMD' /proc/cpuinfo; then
        UCODE="amd-ucode"
    else
        UCODE=""
    fi

    if grep -qi 'apple' /sys/class/dmi/id/sys_vendor; then
        modprobe -r -q efivars
    else
        modprobe -q efivarfs
    fi

    if [[ -d $efidir ]]; then
        SYS="UEFI"
        grep -q $efidir/efivars <<< "$(mount)" ||
            mount -t efivarfs efivarfs $efidir/efivars
    else
        SYS="BIOS"
    fi

    BT="$DIST Installer - $SYS (x86_64) - Version $VER"
}

load_bcwl()
{
    infobox "Broadcom Wireless Setup" "\nLoading wifi kernel modules please wait...\n" 1
    rmmod wl >/dev/null 2>&1
    rmmod bcma >/dev/null 2>&1
    rmmod b43 >/dev/null 2>&1
    rmmod ssb >/dev/null 2>&1
    modprobe wl >/dev/null 2>&1
    depmod -a >/dev/null 2>&1
    BROADCOM_WL=true
}

system_checks()
{
    if [[ $(whoami) != "root" ]]; then
        infobox "$_ErrTitle" "$_NotRoot\n$_Exit"
        die 1
    elif ! grep -qw 'lm' /proc/cpuinfo; then
        infobox "$_ErrTitle" "$_Not64Bit\n$_Exit"
        die 1
    fi

    grep -q 'BCM4352' <<< "$(lspci -vnn -d 14e4:)" && load_bcwl

    if ! curl -s --head 'https://www.archlinux.org/mirrorlist/all/' | sed '1q' | grep -qw '200'; then
        if [[ $(systemctl is-active NetworkManager) == "active" ]] && hash nmtui >/dev/null 2>&1; then
            tput civis
            nmtui-connect
            if ! curl -s --head 'https://www.archlinux.org/mirrorlist/all/' | sed '1q' | grep -qw '200'; then
                infobox "$_ErrTitle" "$_NoNetwork" 3
                die 1
            fi
        fi
    fi

    return 0
}

preinstall_checks()
{
    if ! [[ $(lsblk -o MOUNTPOINT) =~ $MNT ]]; then
        msgbox "$_ErrTitle" "$_ErrNoMount"
        SELECTED=4
        return 1
    elif [[ $# -eq 1 && $CONFIG_DONE != true ]]; then
        msgbox "$_ErrTitle" "$_ErrNoConfig"
        SELECTED=5
        return 1
    fi

    return 0
}

errshow()
{
    local last_exit_code=$?
    if (( last_exit_code == 0 )); then
        return 0
    fi

    local err
    err="$(sed 's/[^[:print:]]//g; s/\[[0-9\;:]*\?m//g; s/==> //g; s/] ERROR:/]\nERROR:/g' "$ERR")"

    if [[ $err != "" ]]; then
        msgbox "$_ErrTitle" "\nERROR: $err"
    else
        msgbox "$_ErrTitle" "\nThe command exited abnormally: $1\n\nWith the no error message.\n"
    fi
}

echeck()
{
    local last_exit_code=$?
    if (( last_exit_code == 0 )); then
        return 0
    fi

    local err
    err="$(sed 's/[^[:print:]]//g; s/\[[0-9\;:]*\?m//g; s/==> //g; s/] ERROR:/]\nERROR:/g' "$ERR")"

    if [[ $err != "" ]]; then
        msgbox "$_ErrTitle" "\nERROR: $err"
    else
        msgbox "$_ErrTitle" "\nThe command exited abnormally: $1\n\nWith the no error message.\n"
    fi

    if [[ -e $DBG && $TERM == 'linux' ]]; then
        more $DBG
    fi

    die 1
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
    if [[ -d $1 ]]; then
        umount -R $1 >/dev/null 2>&1
    fi
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
    local h=$3
    local w=$4
    local n=$5
    shift 5
    local response
    if ! response="$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
        --title " $title " --menu "$body" $h $w $n "$@")"; then
        return 1
    fi
    printf "%s" "$response"
}

checkbox()
{
    local title="$1"
    local body="$2"
    local h=$3
    local w=$4
    local n=$5
    shift 5
    local response
    if ! response="$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
        --title " $title " --checklist "$body" $h $w $n "$@")"; then
        return 1
    fi
    printf "%s" "$response"
}

getinput()
{
    local answer
    if ! answer="$(dialog --cr-wrap --max-input 63 --stdout --backtitle "$BT" \
        --title " $1 " --inputbox "$2" 0 0 "$3")" || [[ $answer == '' ]]; then
        return 1
    fi
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
    # usage: yesno <title> <text> [<yes_label> <no_label> [<no>]]
    tput civis
    if [[ $# -eq 5 && $5 == "no" ]]; then
        dialog --cr-wrap --backtitle "$BT" --defaultno --title " $1 " \
            --yes-label "$3" --no-label "$4" --yesno "$2\n" 0 0
    elif [[ $# -eq 4 ]]; then
        dialog --cr-wrap --backtitle "$BT" --title " $1 " --yes-label "$3" \
            --no-label "$4" --yesno "$2\n" 0 0
    else
        dialog --cr-wrap --backtitle "$BT" --title " $1 " --yesno "$2\n" 0 0
    fi
}

###############################################################################
# package menus

select_browsers()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "firefox"     "A popular open-source graphical web browser from Mozilla" off \
        "chromium"    "an open-source graphical web browser based on the Blink rendering engine" off \
        "opera"       "Fast and secure, free of charge web browser from Opera Software" off \
        "epiphany"    "A GNOME web browser based on the WebKit rendering engine" off \
        "qutebrowser" "A keyboard-focused vim-like web browser based on Python and PyQt5" off)"
    printf "%s" "$pkgs"
}

select_editors()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "neovim"   "A fork of Vim aiming to improve user experience, plugins, and GUIs." off \
        "atom"     "An open-source text editor developed by GitHub that is licensed under the MIT License" off \
        "geany"    "A fast and lightweight IDE" off \
        "emacs"    "An extensible, customizable, self-documenting real-time display editor" off \
        "mousepad" "A simple text editor" off)"
    printf "%s" "$pkgs"
}

select_terminals()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "termite"        "A minimal VTE-based terminal emulator" off \
        "rxvt-unicode"   "A unicode enabled rxvt-clone terminal emulator" off \
        "xterm"          "The standard terminal emulator for the X window system" off \
        "alacritty"      "A cross-platform, GPU-accelerated terminal emulator" off \
        "terminator"     "Terminal emulator that supports tabs and grids" off \
        "sakura"         "A terminal emulator based on GTK and VTE" off \
        "tilix"          "A tiling terminal emulator for Linux using GTK+ 3" off \
        "tilda"          "A Gtk based drop down terminal for Linux and Unix" off \
        "xfce4-terminal" "A terminal emulator based in the Xfce Desktop Environment" off)"
    printf "%s" "$pkgs"
}

select_multimedia()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "vlc"        "A free and open source cross-platform multimedia player" off \
        "mpv"        "A media player based on mplayer" off \
        "mpd"        "A flexible, powerful, server-side application for playing music" off \
        "ncmpcpp"    "An mpd client and almost exact clone of ncmpc with some new features" off \
        "cmus"       "A small, fast and powerful console music player for Unix-like operating systems" off \
        "audacious"  "A free and advanced audio player based on GTK+" off \
        "nicotine+"  "A graphical client for Soulseek" off \
        "lollypop"   "A new music playing application" off \
        "rhythmbox"  "Music playback and management application" off \
        "deadbeef"   "A GTK+ audio player for GNU/Linux" off \
        "clementine" "A modern music player and library organizer" off)"
    printf "%s" "$pkgs"
}

select_mailchat()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "thunderbird" "Standalone mail and news reader from mozilla" off \
        "geary"       "A lightweight email client for the GNOME desktop" off \
        "evolution"   "Manage your email, contacts and schedule" off \
        "mutt"        "Small but very powerful text-based mail client" off \
        "hexchat"     "A popular and easy to use graphical IRC client" off \
        "pidgin"      "Multi-protocol instant messaging client" off \
        "weechat"     "Fast, light and extensible IRC client" off \
        "irssi"       "Modular text mode IRC client" off)"
    printf "%s" "$pkgs"
}

select_professional()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "libreoffice-fresh"    "Full featured office suite" off \
        "abiword"              "Fully-featured word processor" off \
        "calligra"             "A set of applications for productivity" off \
        "gimp"                 "GNU Image Manipulation Program" off \
        "inkscape"             "Professional vector graphics editor" off \
        "krita"                "Edit and paint images" off \
        "obs-studio"           "Free opensource streaming/recording software" off \
        "openshot"             "An open-source, non-linear video editor for Linux based on MLT framework" off \
        "kdenlive"             "A non-linear video editor for Linux using the MLT video framework" off \
        "audacity"             "A program that lets you manipulate digital audio waveforms" off \
        "guvcview"             "Capture video from camera devices" off \
        "simplescreenrecorder" "A feature-rich screen recorder" off)"
    printf "%s" "$pkgs"
}

select_managment()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "thunar"               "A modern file manager for the Xfce Desktop Environment" off \
        "pcmanfm"              "A fast and lightweight file manager based in Lxde" off \
        "gparted"              "A GUI frontend for creating and manipulating partition tables" off \
        "gnome-disk-utility"   "Disk Management Utility" off \
        "gnome-system-monitor" "View current processes and monitor system state" off \
        "qt5ct"                "GUI for managing Qt based application themes, icons, and fonts" off \
        "file-roller"          "Create and modify archives" off \
        "xarchiver"            "A GTK+ frontend to various command line archivers" off \
        "ttf-hack"             "A hand groomed and optically balanced typeface based on Bitstream Vera Mono" off \
        "ttf-anonymous-pro"    "A family of four fixed-width fonts designed especially with coding in mind" off \
        "ttf-font-awesome"     "Iconic font designed for Bootstrap" off \
        "ttf-fira-code"        "Monospaced font with programming ligatures" off \
        "noto-fonts"           "Google Noto fonts" off \
        "noto-fonts-cjk"       "Google Noto CJK fonts (Chinese, Japanese, Korean)" off)"
    printf "%s" "$pkgs"
}

select_extra()
{
    local pkgs=""
    pkgs="$(checkbox "$_Packages" "$_PackageBody" 0 0 0 \
        "steam"            "A popular game distribution platform by Valve" off \
        "deluge"           "A BitTorrent client written in python" off \
        "transmission-gtk" "Free BitTorrent client GTK+ GUI" off \
        "qbittorrent"      "An advanced BitTorrent client" off \
        "evince"           "A document viewer" off \
        "zathura"          "Minimalistic document viewer" off \
        "qpdfview"         "A tabbed PDF viewer" off \
        "mupdf"            "Lightweight PDF and XPS viewer" off \
        "gpicview"         "Lightweight image viewer" off \
        "gpick"            "Advanced color picker using GTK+ toolkit" off \
        "gcolor2"          "A simple GTK+2 color selector" off \
        "plank"            "An elegant, simple, and clean dock" off \
        "docky"            "Full fledged dock for opening applications and managing windows" off \
        "cairo-dock"       "Light eye-candy fully themable animated dock" off)"
    printf "%s" "$pkgs"
}

###############################################################################
# partition menus

format()
{
    infobox "$_FSTitle" "\nRunning: ${FS_CMDS[$2]} $1\n" 0
    ${FS_CMDS[$2]} $1 >/dev/null 2>$ERR
    errshow "${FS_CMDS[$2]} $1"
}

partition()
{
    local device
    if [[ $# -eq 0 ]]; then
        select_device 'root' || return 1
        device="$DEVICE"
    else
        device="$1"
    fi

    tput civis
    local choice
    if [[ $DISPLAY ]] && hash gparted >/dev/null 2>&1; then
        if ! choice="$(menubox "$_PartTitle" "$_PartBody" 0 0 0 \
            "$_PartShowTree" "-" \
            "$_PartAuto" "-" \
            "gparted -" \
            "cfdisk" "-" \
            "parted" "-" \
            "$_PartWipe" "-")"; then
            return 1
        fi
    else
        if ! choice="$(menubox "$_PartTitle" "$_PartBody" 0 0 0 \
            "$_PartShowTree" "-" \
            "$_PartAuto" "-" \
            "cfdisk" "-" \
            "parted" "-" \
            "$_PartWipe" "-")"; then
            return 1
        fi
    fi

    tput civis
    if [[ $choice != "$_PartWipe" && $choice != "$_PartAuto" && $choice != "$_PartShowTree" ]]; then
        clear; tput cnorm; $choice $device
    elif [[ $choice == "$_PartShowTree" ]]; then
        msgbox "$_PrepShowDev" "\n$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE,MOUNTPOINT "$device")\n"
        partition $device
    elif [[ $choice == "$_PartWipe" ]]; then
        yesno "$_PartWipe" "$_PartBody1 $device $_PartWipeBody2" && wipe -Ifrev $device
        partition $device
    else
        # if auto_partition fails we need to empty the partition variables
        auto_partition $device || return 1
    fi
}

decr_count()
{
    # remove a partition from the dialog list and decrement the number partitions left
    (( $# == 1 )) || return 1

    local p="$1"
    PARTS="$(sed "s~${p} [0-9]*[G-M]~~; s~${p} [0-9]*\.[0-9]*[G-M]~~" <<< "$PARTS")"
    (( COUNT > 0 )) && (( COUNT-- ))
    return 0
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

device_tree()
{
    tput civis
    local msg
    if [[ $IGNORE_DEV != "" ]]; then
        msg="$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE,MOUNTPOINT |
            awk "!/$IGNORE_DEV/"' && /disk|part|lvm|crypt|NAME/')"
    else
        msg="$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE,MOUNTPOINT |
            awk '/disk|part|lvm|crypt|NAME/')"
    fi
    msgbox "$_PrepShowDev" "$msg"
}

select_device()
{
    local dev
    local msg
    if [[ $1 == 'boot' ]]; then
        msg="$_DevSelTitle for bootloader\n"
    else
        umount_dir $MNT
    fi

    if [[ $DEV_COUNT -eq 1 && $SYS_DEVS ]]; then
        DEVICE="$(awk '{print $1}' <<< "$SYS_DEVS")"
        msg="\nOnly one device available$([[ $1 == 'boot' ]] && printf " for bootloader"):"
        infobox "$_DevSelTitle" "$msg $DEVICE\n" 1
    elif (( DEV_COUNT > 1 )); then
        tput civis
        if ! DEVICE="$(menubox "$_DevSelTitle " "${msg}$_DevSelBody" 0 0 0 $SYS_DEVS)"; then
            return 1
        fi
    elif [[ $DEV_COUNT -lt 1 && $1 != 'boot' ]]; then
        msgbox "$_ErrTitle" "\nNo available devices to use.\n$_Exit"; die 1
    fi

    # if the device selected was for bootloader, set the BOOT_DEVICE
    [[ $1 == 'boot' ]] && BOOT_DEVICE="$DEVICE"

    return 0
}

confirm_mount()
{
    local part="$1"
    local mount="$2"

    if [[ $mount == "$MNT" ]]; then
        local msg="Partition: $part\nMountpoint: / (root)"
    else
        local msg="Partition: $part\nMountpoint: ${mount#$MNT}"
    fi

    if [[ $(mount) == *"$mount"* ]]; then
        infobox "$_MntTitle" "$_MntSucc\n$msg\n" 1
        decr_count "$part"
    else
        infobox "$_MntTitle" "$_MntFail\n$msg\n" 1
        return 1
    fi

    return 0
}

check_cryptlvm()
{
    local dev=""
    local part="$1"
    local devs
    devs="$(lsblk -lno NAME,FSTYPE,TYPE)"

    # Identify if $part is "crypt" (LUKS on LVM, or LUKS alone)
    if [[ $(lsblk -lno TYPE "$part") =~ 'crypt' ]]; then
        LUKS=' encrypted'
        LUKS_NAME="${part#/dev/mapper/}"

        for dev in $(awk '/lvm/ && /crypto_LUKS/ {print "/dev/mapper/"$1}' <<< "$devs" | uniq); do
            if grep -q "$LUKS_NAME" <<< "$(lsblk -lno NAME "$dev")"; then
                LUKS_DEV="$LUKS_DEV cryptdevice=$dev:$LUKS_NAME"
                LVM=' logical volume'
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
        LVM=' logical volume'
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
                LUKS=' encrypted'
                break
            fi
        done
    fi
}

auto_partition()
{
    local device="$1"
    local size
    size=$(lsblk -lno SIZE $device | awk 'NR == 1 {
        if ($1 ~ "G") {
            sub(/G/, ""); print ($1 * 1000 - 512) / 1000"G"
        } else {
            sub(/M/, ""); print ($1 - 512)"M"
        }
    }')

    if [[ $SYS == 'BIOS' ]]; then
        local msg
        msg="$(sed 's|vfat/fat32|ext4|' <<< "$_PartBody2")"
        local table="msdos"
        local fs="ext4"
    else
        local msg="$_PartBody2"
        local table="gpt"
        local fs="fat32";
    fi

    # confirm or bail
    yesno "$_PrepParts" "$_PartBody1 $device $msg ($size)$_PartBody3" || return 0
    infobox "$_PrepParts" "\nRemoving partitions on $device and setting table to $table\n" 2
    swapoff -a  # in case the device was previously used for swap

    local dev_info
    dev_info="$(parted -s $device print)"

    # walk the partitions on the device in reverse order and delete them
    while read -r i; do
        parted -s $device rm $i >/dev/null 2>&1
    done <<< "$(awk '/^ [1-9][0-9]?/ {print $1}' <<< "$dev_info" | sort -r)"

    if [[ $(awk '/Table:/ {print $3}' <<< "$dev_info") != "$table" ]]; then
        parted -s $device mklabel $table >/dev/null 2>&1
    fi

    infobox "$_PrepParts" "\nCreating a 512M $fs boot partition.\n" 2
    if [[ $SYS == "BIOS" ]]; then
        parted -s $device mkpart primary $fs 1MiB 513MiB >/dev/null 2>&1
    else
        parted -s $device mkpart ESP $fs 1MiB 513MiB >/dev/null 2>&1
    fi

    sleep 0.1
    BOOT_DEVICE="$device"
    AUTO_BOOT_PART=$(lsblk -lno NAME,TYPE $device | awk 'NR == 2 {print "/dev/"$1}')

    if [[ $SYS == "BIOS" ]]; then
        mkfs.ext4 -q $AUTO_BOOT_PART >/dev/null 2>&1
    else
        mkfs.vfat -F32 $AUTO_BOOT_PART >/dev/null 2>&1
    fi

    infobox "$_PrepParts" "\nCreating a $size ext4 root partition.\n" 0
    parted -s $device mkpart primary ext4 513MiB 100% >/dev/null 2>&1
    sleep 0.1
    local rp
    rp="$(lsblk -lno NAME,TYPE $device | awk 'NR == 3 {print "/dev/"$1}')"
    mkfs.ext4 -q $rp >/dev/null 2>&1

    tput civis
    sleep 0.5
    msgbox "$_PrepParts" "\nAuto partitioning complete.\n\n$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE $device)"
}

mount_partition()
{
    local part="$1"
    local mountp="${MNT}$2"
    local fs
    fs="$(lsblk -lno FSTYPE $part)"
    mkdir -p "$mountp"

    if [[ $fs && ${FS_OPTS[$fs]} && $part != "$BOOT_PART" ]] && select_mount_opts "$part" "$fs"; then
        mount -o $MNT_OPTS $part "$mountp" 2>$ERR
        errshow "mount -o $MNT_OPTS $part $mountp"
    else
        mount $part "$mountp" 2>$ERR
        errshow "mount $part $mountp"
    fi

    confirm_mount $part "$mountp" || return 1
    check_cryptlvm "$part"

    return 0
}

mount_boot_part()
{
    if ! mount_partition "$BOOT_PART" "${BMNTS[$SYS-$BOOTLDR]}"; then
        return 1
    else
        SEP_BOOT=true
    fi
}

find_partitions()
{
    local str="$1"
    local err=''

    # string of partitions as /TYPE/PART SIZE
    if [[ $IGNORE_DEV != "" ]]; then
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
    COUNT=$(wc -l <<< "$PARTS")

    # ensure we have enough partitions for the system and action type
    case $str in
        'part|lvm|crypt') [[ $COUNT -eq 0 || ($SYS == 'UEFI' && $COUNT -lt 2) ]] && err="$_PartErrBody" ;;
        'part|crypt') (( COUNT == 0 )) && err="$_LvmPartErrBody" ;;
        'part|lvm') (( COUNT < 2 )) && err="$_LuksPartErrBody" ;;
    esac

    # if there aren't enough partitions show the error message
    if [[ $err ]]; then
        msgbox "$_ErrTitle" "$err"
        return 1
    fi

    return 0
}

setup_boot_device()
{
    infobox "$_PrepMount" "\nSetting device flags for: $BOOT_PART\n" 1

    if [[ $BOOT_PART = /dev/nvme* ]]; then
        BOOT_DEVICE="${BOOT_PART%p[1-9]}"
    else
        BOOT_DEVICE="${BOOT_PART%[1-9]}"
    fi

    BOOT_PART_NUM="${BOOT_PART: -1}"

    if [[ $SYS == 'UEFI' ]]; then
        parted -s $BOOT_DEVICE set $BOOT_PART_NUM esp on >/dev/null 2>&1
    else
        parted -s $BOOT_DEVICE set $BOOT_PART_NUM boot on >/dev/null 2>&1
    fi

    return 0
}

###############################################################################
# mounting menus

mnt_menu()
{
    # prepare partition list PARTS for dialog
    lvm_detect
    umount_dir $MNT
    find_partitions 'part|lvm|crypt' || return 1
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
    # Ask user to select partition or create swapfile
    tput civis
    if ! SWAP_PART="$(menubox "$_SelSwpSetup" "$_SelSwpBody" 0 0 0 \
        "$_SelSwpNone" "-" \
        "$_SelSwpFile" "$SYS_MEM" \
        $PARTS)" ||
        [[ $SWAP_PART == "$_SelSwpNone" ]]
    then
        SWAP_PART=""
        return 0
    fi

    if [[ $SWAP_PART == "$_SelSwpFile" ]]; then
        tput cnorm
        local i=0
        while ! [[ ${SWAP_SIZE:0:1} =~ [1-9] && ${SWAP_SIZE: -1} =~ (M|G) ]]; do
            (( i > 0 )) && msgbox "$_SelSwpSetup Error" "\n$_SelSwpErr $SWAP_SIZE\n"
            if ! SWAP_SIZE="$(getinput "$_SelSwpSetup" "$_SelSwpSize" "$SYS_MEM")"; then
                SWAP_PART=""
                SWAP_SIZE=""
                break
                return 0
            fi
            ((i++))
        done
        enable_swap "$MNT/swapfile"
        SWAP_PART="/swapfile"
    else
        enable_swap "$SWAP_PART"
        decr_count "$SWAP_PART"
        SWAP_SIZE="$(lsblk -lno SIZE $SWAP_PART)"
    fi
    return 0
}

select_mountpoint()
{
    tput cnorm
    if ! EXTRA_MNT="$(getinput "$_PrepMount $part" "$_ExtPartBody1 /home /var\n" "/")"; then
        return 1
    fi

    # bad mountpoint
    if [[ ${EXTRA_MNT:0:1} != "/" || ${#EXTRA_MNT} -le 1 || $EXTRA_MNT =~ \ |\' ]]; then
        msgbox "$_ErrTitle" "$_ExtErrBody"
        select_mountpoint || return 1
    fi
    return 0
}

select_mount_opts()
{
    local part="$1"
    local fs="$2"
    local title="${fs^} Mount Options"
    local opts="${FS_OPTS[$fs]}"

    # check for ssd
    ssd "$part" >/dev/null 2>&1 && opts=$(sed 's/discard - off/discard - on/' <<< "$opts")

    tput civis
    if ! MNT_OPTS="$(dialog --cr-wrap --stdout --backtitle "$BT" --title " $title " \
        --checklist "$_MntBody" 0 0 0 $opts)" || [[ $MNT_OPTS == "" ]]; then
        return 1
    fi

    MNT_OPTS="$(sed 's/ /,/g; $s/,$//' <<< "$MNT_OPTS" )"

    if ! yesno "$title" "$_MntConfBody $MNT_OPTS\n"; then
        select_mount_opts "$part" "$fs" || return 1
    fi

    return 0
}

select_filesystem()
{
    local part="$1"
    local fs cur_fs
    cur_fs="$(lsblk -lno FSTYPE $part 2>/dev/null)"
    local msg="\nSelect which filesystem you want to use for $part\n\nPartition Name:      "

    tput civis
    if [[ $cur_fs && $part != "$ROOT_PART" ]]; then
        fs="$(menubox "$_FSTitle: $part" \
            "${msg}${part}\nExisting Filesystem: ${cur_fs}$_FSBody" 0 0 0 \
            "$_Skip"   "-" \
            "ext4"     "${FS_CMDS[ext4]}" \
            "ext3"     "${FS_CMDS[ext3]}" \
            "ext2"     "${FS_CMDS[ext2]}" \
            "vfat"     "${FS_CMDS[vfat]}" \
            "ntfs"     "${FS_CMDS[ntfs]}" \
            "f2fs"     "${FS_CMDS[f2fs]}" \
            "jfs"      "${FS_CMDS[jfs]}" \
            "nilfs2"   "${FS_CMDS[nilfs2]}" \
            "reiserfs" "${FS_CMDS[reiserfs]}" \
            "xfs"      "${FS_CMDS[xfs]}")"
    else
        fs="$(menubox "$_FSTitle: $part" \
            "${msg}${part}$_FSBody" 0 0 0 \
            "ext4"     "${FS_CMDS[ext4]}" \
            "ext3"     "${FS_CMDS[ext3]}" \
            "ext2"     "${FS_CMDS[ext2]}" \
            "vfat"     "${FS_CMDS[vfat]}" \
            "ntfs"     "${FS_CMDS[ntfs]}" \
            "f2fs"     "${FS_CMDS[f2fs]}" \
            "jfs"      "${FS_CMDS[jfs]}" \
            "nilfs2"   "${FS_CMDS[nilfs2]}" \
            "reiserfs" "${FS_CMDS[reiserfs]}" \
            "xfs"      "${FS_CMDS[xfs]}")"
    fi

    if ! [[ $fs ]]; then
        return 1
    elif [[ $fs == "$_Skip" ]]; then
        return 0
    fi

    if yesno "$_FSTitle" "\nFormat $part as $fs?\n" "Format" "Go Back"; then
        format $part $fs
    else
        select_filesystem $part || return 1
    fi

    return 0
}

select_efi_partition()
{
    tput civis
    if (( COUNT == 1 )); then
        BOOT_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
        infobox "$_PrepMount" "$_OnlyOne for EFI: $BOOT_PART\n" 1
    elif ! BOOT_PART="$(menubox "$_PrepMount" "$_SelUefiBody" 0 0 0 $PARTS)"; then
        return 1
    fi

    if grep -q 'fat' <<< "$(fsck -N "$BOOT_PART")"; then
        local msg="$_FormUefiBody $BOOT_PART $_FormUefiBody2"
        if [[ $AUTO_BOOT_PART != "$BOOT_PART" ]] && yesno "$_PrepMount" "$msg" "Format $BOOT_PART" "Do Not Format" "no"; then
            format "$BOOT_PART" "vfat"
            sleep 1
        fi
    else
        format "$BOOT_PART" "vfat"
        sleep 1
    fi
    return 0
}

select_boot_partition()
{
    tput civis
    if ! BOOT_PART="$(menubox "$_PrepMount" "$_SelBiosBody" 0 0 0 "$_Skip" "-" $PARTS)" || [[ $BOOT_PART == "$_Skip" ]]; then
        BOOT_PART=""
    else
        if grep -q 'ext[34]' <<< "$(fsck -N "$BOOT_PART")"; then
            local msg="$_FormBiosBody $BOOT_PART $_FormUefiBody2"
            if [[ $AUTO_BOOT_PART != "$BOOT_PART" ]] && yesno "$_PrepMount" "$msg" "Format $BOOT_PART" "Skip Formatting" "no"; then
                format "$BOOT_PART" "ext4"
                sleep 1
            fi
        else
            format "$BOOT_PART" "ext4"
            sleep 1
        fi
    fi
    return 0
}

select_root_partition()
{
    tput civis
    if [[ $COUNT -eq 1 ]]; then
        ROOT_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
        infobox "$_PrepMount" "$_OnlyOne for root (/): $ROOT_PART\n" 1
    elif ! ROOT_PART="$(menubox "$_PrepMount" "$_SelRootBody" 0 0 0 $PARTS)"; then
        return 1
    fi

    select_filesystem "$ROOT_PART" || { ROOT_PART=""; return 1; }
    mount_partition "$ROOT_PART" || { ROOT_PART=""; return 1; }
    return 0
}

select_extra_partitions()
{
    while (( COUNT > 0 )); do
        tput civis
        local part
        if ! part="$(menubox "$_PrepMount " "$_ExtPartBody" 0 0 0 "$_Done" "-" $PARTS)" || [[ $part == "$_Done" ]]; then
            break
        elif ! select_filesystem "$part"; then
            break
            return 1
        elif ! select_mountpoint; then
            break
            return 1
        elif ! mount_partition "$part" "$EXTRA_MNT"; then
            break
            return 1
        fi
        EXTRA_MNTS="$EXTRA_MNTS $part: $EXTRA_MNT"
        [[ $EXTRA_MNT == "/usr" && $HOOKS != *usr* ]] && HOOKS="usr $HOOKS"
    done

    return 0
}

###############################################################################
# lvm functions

lvm_menu()
{
    lvm_detect
    tput civis

    local choice
    choice="$(menubox "$_PrepLVM" "$_LvmMenu" 0 0 0 \
        "$_LvmCreateVG" "vgcreate -f, lvcreate -L -n" \
        "$_LvmDelVG"    "vgremove -f" \
        "$_LvMDelAll"   "lvrmeove, vgremove, pvremove -f" \
        "$_Back"        "-")"

    case $choice in
        "$_LvmCreateVG")
            lvm_create
            retval=$?
            [[ $retval != 1 ]] && return $retval
            ;;
        "$_LvmDelVG") lvm_del_vg ;;
        "$_LvMDelAll") lvm_del_all ;;
        *) return 0
    esac

    lvm_menu
}

lvm_detect()
{
    PHYSICAL_VOLUMES="$(pvs -o pv_name --noheading 2>/dev/null)"
    VOLUME_GROUP="$(vgs -o vg_name --noheading 2>/dev/null)"
    VOLUMES="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"

    if [[ $VOLUMES && $VOLUME_GROUP && $PHYSICAL_VOLUMES ]]; then
        infobox "$_PrepLVM" "$_LvmDetBody" 1
        modprobe dm-mod 2>$ERR
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

    if [[ $VOL_GROUP_LIST == "" ]]; then
        msgbox "$_ErrTitle" "$_LvmVGErr"
        return 1
    fi

    tput civis
    if ! DEL_VG="$(menubox "$_PrepLVM" "$_LvmSelVGBody" 18 70 10 $VOL_GROUP_LIST)"; then
        return 1
    fi
    return 0
}

get_lv_size()
{
    tput cnorm
    local ttl=" $_LvmCreateVG (LV:$VOL_COUNT) "
    local msg="${VOLUME_GROUP}: ${GROUP_SIZE}$GROUP_SIZE_TYPE (${VOL_GROUP_MB}MB $_LvmLvSizeBody1).$_LvmLvSizeBody2"
    if ! VOLUME_SIZE="$(getinput "$ttl" "$msg" "")"; then
        return 1
    fi

    ERR_SIZE=0
    # if the size is empty or 0
    (( ${#VOLUME_SIZE} == 0 || ${VOLUME_SIZE:0:1} == 0 )) && ERR_SIZE=1

    if (( ERR_SIZE == 0 )); then
        # number of characters in VOLUME_SIZE minus the last, which should be a letter
        local lv="$((${#VOLUME_SIZE} - 1))"

        # loop each character (except the last) in VOLUME_SIZE and ensure they are numbers
        for (( i=0; i<lv; i++ )); do
            [[ ${VOLUME_SIZE:$i:1} != [0-9] ]] && { ERR_SIZE=1; break; }
        done

        if (( ERR_SIZE == 0 )); then
            # ensure the last character is either m/M or g/G
            case ${VOLUME_SIZE:$lv:1} in
                [mMgG]) ERR_SIZE=0 ;;
                *) ERR_SIZE=1
            esac

            if (( ERR_SIZE == 0 )); then
                local s=${VOLUME_SIZE:0:$lv}
                local m=$((s * 1000))
                # check whether the value is greater than or equal to the LV remaining Size.
                # if not, convert into MB for VG space remaining.
                case ${VOLUME_SIZE:$lv:1} in
                    [Gg])
                        if (( m >= VOL_GROUP_MB )); then
                            ERR_SIZE=1
                        else
                            VOL_GROUP_MB=$((VOL_GROUP_MB - m))
                        fi
                        ;;
                    [Mm])
                        if (( ${VOLUME_SIZE:0:$lv} >= VOL_GROUP_MB )); then
                            ERR_SIZE=1
                        else
                            VOL_GROUP_MB=$((VOL_GROUP_MB - s))
                        fi
                        ;;
                    *)
                        ERR_SIZE=1
                esac
            fi
        fi
    fi

    if (( ERR_SIZE == 1 )); then
        msgbox "$_ErrTitle" "$_LvmLvSizeErrBody"
        get_lv_size || return 1
    fi

    return 0
}

lvm_volume_name()
{
    local msg="$1"

    local default="volmain"
    (( VOL_COUNT > 1 )) && default="volextra"

    tput cnorm
    local name
    if ! name="$(getinput "$_LvmCreateVG (LV:$VOL_COUNT)" "$msg" "$default")"; then
        return 1
    fi

    # bad volume name answer or name already in use
    if [[ ${name:0:1} == "/" || ${#name} -eq 0 || $name =~ \ |\' ]] || grep -q "$name" <<< "$(lsblk)"; then
        msgbox "$_ErrTitle" "$_LvmLvNameErrBody"
        lvm_volume_name "$msg" || return 1
    fi

    VOLUME_NAME="$name"
    return 0
}

lvm_group_name()
{
    tput cnorm
    local group
    if ! group="$(getinput "$_LvmCreateVG" "$_LvmNameVgBody" "VolGroup")"; then
        return 1
    fi

    # bad answer or group name already taken
    if [[ ${group:0:1} == "/" || ${#group} -eq 0 || $group =~ \ |\' ]] || grep -q "$group" <<< "$(lsblk)"; then
        msgbox "$_ErrTitle" "$_LvmNameVgErr"
        lvm_group_name || return 1
    fi

    VOLUME_GROUP="$group"
    return 0
}

lvm_extra_lvs()
{
    while (( VOL_COUNT > 1 )); do
        # get the name and size
        lvm_volume_name "$_LvmLvNameBody1" || { break; return 1; }
        get_lv_size || { break; return 1; }

        # create it
        lvcreate -L "$VOLUME_SIZE" "$VOLUME_GROUP" -n "$VOLUME_NAME" >/dev/null 2>$ERR
        errshow "lvcreate -L $VOLUME_SIZE $VOLUME_GROUP -n $VOLUME_NAME"
        msgbox "$_LvmCreateVG (LV:$VOL_COUNT)" "$_Done LV $VOLUME_NAME ($VOLUME_SIZE) $_LvmPvDoneBody2."

        ((VOL_COUNT--)) # decrement the number of volumes chosen after each loop
    done

    return 0
}

lvm_volume_count()
{
    if ! VOL_COUNT=$(dialog --cr-wrap --stdout --backtitle "$BT" --title " $_LvmCreateVG " \
        --radiolist "$_LvmLvNumBody1 $VOLUME_GROUP\n$_LvmLvNumBody2" 0 0 0 \
        "1" "-" off "2" "-" off "3" "-" off "4" "-" off "5" "-" off \
        "6" "-" off "7" "-" off "8" "-" off "9" "-" off); then
        return 1
    fi
    return 0
}

lvm_partitions()
{
    find_partitions 'part|crypt' || return 1
    PARTS="$(awk 'NF > 0 {print $0 " off"}' <<< "$PARTS")"

    # choose partitions
    tput civis
    if ! GROUP_PARTS="$(dialog --cr-wrap --stdout --backtitle "$BT" \
        --title " $_LvmCreateVG " --checklist "$_LvmPvSelBody" 0 0 0 $PARTS)"; then
        return 1
    fi

    return 0
}

lvm_create_group()
{
    # get volume group name
    lvm_group_name || return 1

    # loop while setup is not confirmed by the user
    while ! yesno "$_LvmCreateVG" "$_LvmPvConfBody1 $VOLUME_GROUP\n\n$_LvmPvConfBody2 $GROUP_PARTS\n"; do
        lvm_partitions || { break; return 1; }
        lvm_group_name || { break; return 1; }
    done

    # create it
    vgcreate -f "$VOLUME_GROUP" "$GROUP_PARTS" >/dev/null 2>$ERR
    errshow "vgcreate -f $VOLUME_GROUP $GROUP_PARTS"

    GROUP_SIZE=$(vgdisplay "$VOLUME_GROUP" | awk '/VG Size/ {
        gsub(/[^0-9.]/, "")
        print int($0)
    }')

    GROUP_SIZE_TYPE="$(vgdisplay "$VOLUME_GROUP" | awk '/VG Size/ {
        print substr($NF, 0, 1)
    }')"

    if [[ $GROUP_SIZE_TYPE == 'G' ]]; then
        VOL_GROUP_MB=$((GROUP_SIZE * 1000))
    else
        VOL_GROUP_MB=$GROUP_SIZE
    fi

    # finished volume group creation
    local msg="$_LvmPvDoneBody1 $VOLUME_GROUP ($GROUP_SIZE $GROUP_SIZE_TYPE)"
    msgbox "$_LvmCreateVG" "$msg $_LvmPvDoneBody2\n"
    return 0
}

lvm_create()
{
    VOLUME_GROUP=""
    GROUP_PARTS=""
    VOL_GROUP_MB=0
    umount_dir $MNT
    lvm_partitions || return 1
    lvm_create_group || return 1
    lvm_volume_count || return 1
    lvm_extra_lvs || return 1
    lvm_volume_name "$_LvmLvNameBody1 $_LvmLvNameBody2 (${VOL_GROUP_MB}MB)" || return 1
    lvcreate -l +100%FREE "$VOLUME_GROUP" -n "$VOLUME_NAME" >/dev/null 2>$ERR
    errshow "lvcreate -l +100%FREE $VOLUME_GROUP -n $VOLUME_NAME"
    LVM=' logical volume'
    tput civis
    sleep 0.5
    local msg="${_Done}$_LvmPvDoneBody1 $VOLUME_GROUP-$VOLUME_NAME (${VOLUME_SIZE:-${VOL_GROUP_MB}MB}) $_LvmPvDoneBody2."
    msgbox "$_LvmCreateVG (LV:$VOL_COUNT)" "$msg\n\n$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE $GROUP_PARTS)"

    return 0
}

lvm_del_vg()
{
    if lvm_show_vg && yesno "$_LvmDelVG" "$_LvmDelQ"; then
        vgremove -f "$DEL_VG" >/dev/null 2>&1
    fi
    return 0
}

lvm_del_all()
{
    PHYSICAL_VOLUMES="$(pvs -o pv_name --noheading 2>/dev/null)"
    VOLUME_GROUP="$(vgs -o vg_name --noheading 2>/dev/null)"
    VOLUMES="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"

    if yesno "$_LvMDelAll" "$_LvmDelQ"; then
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

    return 0
}

###############################################################################
# luks functions

luks_open()
{
    LUKS_PART=""
    modprobe -a dm-mod dm_crypt
    umount_dir $MNT
    find_partitions 'part|crypt|lvm' || return 1
    tput civis

    if (( COUNT == 1 )); then
        LUKS_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
        infobox "$_LuksOpen" "${_OnlyOne}: $LUKS_PART\n" 1
    elif ! LUKS_PART="$(menubox "$_LuksOpen" "$_LuksMenuBody" 0 0 0 $PARTS)"; then
        return 1
    elif ! luks_pass "$_LuksOpen" "${LUKS_NAME:-cryptroot}"; then
        return 1
    fi

    infobox "$_LuksOpen" "$_LuksOpenWaitBody $LUKS_NAME $_LuksWaitBody2 $LUKS_PART\n" 0
    cryptsetup open --type luks $LUKS_PART "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
    errshow "cryptsetup open --type luks $LUKS_PART $LUKS_NAME"

    LUKS=' encrypted'
    luks_show
    return 0
}

luks_pass()
{
    local title="$1"
    local name="$2"
    local pass pass2
    LUKS_PASS=""
    LUKS_NAME=""

    tput cnorm
    local values
    if [[ $name == "" ]]; then
        if ! values="$(dialog --stdout --separator '~' --ok-label "Submit" \
            --backtitle "$BT" --title " $title " --insecure --mixedform \
            "\nEnter the password to decrypt $ROOT_PART.
            \nThis is needed to create a keyfile." 14 75 3 \
            "$_Password"  1 1 ""      1 $((${#_Password} + 2))  71 0 1 \
            "$_Password2" 2 1 ""      2 $((${#_Password2} + 2)) 71 0 1)"; then
            return 1
        fi
        pass="$(awk -F'~' '{print $1}' <<< "$values")"
        pass2="$(awk -F'~' '{print $2}' <<< "$values")"
    else
        if ! values="$(dialog --stdout --separator '~' --ok-label "Submit" --backtitle "$BT" \
            --title " $title " --insecure --mixedform "$_LuksOpenBody" 16 75 4 \
            "$_Name"      1 1 "$name" 1 $((${#_Name} + 2))      71 0 0 \
            "$_Password"  2 1 ""      2 $((${#_Password} + 2))  71 0 1 \
            "$_Password2" 3 1 ""      3 $((${#_Password2} + 2)) 71 0 1)"; then
            return 1
        fi

        name="$(awk -F'~' '{print $1}' <<< "$values")"
        pass="$(awk -F'~' '{print $2}' <<< "$values")"
        pass2="$(awk -F'~' '{print $3}' <<< "$values")"

        LUKS_NAME="$name"
    fi

    if [[ $pass == "" || "$pass" != "$pass2" ]]; then
        msgbox "$_ErrTitle" "$_PassErr\n$_TryAgain"
        luks_pass "$title" "$name" || return 1
    fi

    LUKS_PASS="$pass"
    return 0
}

luks_setup()
{
    LUKS_PART=""
    modprobe -a dm-mod dm_crypt
    umount_dir $MNT
    find_partitions 'part|lvm' || return 1
    tput civis

    if (( COUNT == 1 )); then
        LUKS_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
        infobox "$_LuksEncrypt" "${_OnlyOne}: $LUKS_PART\n" 1
    elif ! LUKS_PART="$(menubox "$_LuksEncrypt" "$_LuksEncryptBody" 0 0 0 $PARTS)"; then
        return 1
    elif ! luks_pass "$_LuksEncrypt" "${LUKS_NAME:-cryptroot}"; then
        return 1
    fi

    return 0
}

luks_default()
{
    luks_setup || return 1
    infobox "$_LuksEncrypt" "$_LuksCreateWaitBody $LUKS_NAME $_LuksWaitBody2 $LUKS_PART\n" 0

    cryptsetup -q luksFormat $LUKS_PART <<< "$LUKS_PASS" 2>$ERR
    errshow "cryptsetup -q luksFormat $LUKS_PART"

    cryptsetup open $LUKS_PART "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
    errshow "cryptsetup open $LUKS_PART $LUKS_NAME"

    LUKS=' encrypted'
    luks_show
    return 0
}

luks_keycmd()
{
    if luks_setup; then
        tput cnorm
        local cipher
        if ! cipher="$(getinput "$_PrepLUKS" "$_LuksCipherKey" "-s 512 -c aes-xts-plain64")"; then
            return 1
        fi
        infobox "$_LuksEncryptAdv" "$_LuksCreateWaitBody $LUKS_NAME $_LuksWaitBody2 $LUKS_PART\n" 0

        cryptsetup -q $cipher luksFormat $LUKS_PART <<< "$LUKS_PASS" 2>$ERR
        errshow "cryptsetup -q $cipher luksFormat $LUKS_PART"

        cryptsetup open $LUKS_PART "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
        errshow "cryptsetup open $LUKS_PART $LUKS_NAME"

        luks_show
        return 0
    fi
    return 1
}

luks_show()
{
    tput civis
    sleep 0.5
    msgbox "$_LuksEncrypt" "${_LuksEncryptSucc}\n$(lsblk $LUKS_PART -o NAME,MODEL,TYPE,FSTYPE,SIZE)\n"
}

luks_menu()
{
    tput civis
    local choice
    choice="$(menubox "$_PrepLUKS" \
        "${_LuksMenuBody}${_LuksMenuBody2}${_LuksMenuBody3}" 0 0 0 \
        "$_LuksEncrypt"    "cryptsetup -q luksFormat" \
        "$_LuksOpen"       "cryptsetup open --type luks" \
        "$_LuksEncryptAdv" "cryptsetup -q -s -c luksFormat" \
        "$_Back"           "-")"

    case $choice in
        "$_LuksEncrypt") luks_default && return 0 ;;
        "$_LuksOpen") luks_open && return 0 ;;
        "$_LuksEncryptAdv") luks_keycmd && return 0 ;;
        *) return 0
    esac

    luks_menu
}

luks_keyfile()
{
    # Only used when choosing grub as bootloader.
    # Without a keyfile, during boot the user will be asked
    # to enter password for decryption twice, this is annoying

    if [[ ! -e $MNT/crypto_keyfile.bin && $LUKS_PASS && $LUKS_UUID ]]; then
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
# installation

install()
{
    # NOTE: function calls prefixed with 'oneshot' will only ever be run once
    # this allows running install() multiple times without redoing things

    clear
    tput cnorm

    # unpack the file system
    oneshot install_base

    # generate /etc/fstab and touch it up if we used a swapfile
    genfstab -U $MNT > $MNT/etc/fstab 2>$ERR
    echeck "genfstab -U $MNT > $MNT/etc/fstab"
    [[ -f $MNT/swapfile ]] && sed -i "s~${MNT}~~" $MNT/etc/fstab

    # update the mirrorlist..  MUST be done before updating or it may be slow
    oneshot mirrorlist_sort

    # MUST be before bootloader and running mkinitcpio
    oneshot package_operations

    # mkinitcpio and bootloader install should only be done after installing the packages
    # and updating the mirrorlist, otherwise the chosen kernel may not be fully set up
    run_mkinitcpio
    install_bootloader

    # hwclock setup, falls back to setting --directisa if the default fails
    chrun "hwclock --systohc --utc" || chrun "hwclock --systohc --utc --directisa"

    # create the user
    oneshot create_user

    # set up user login.. MUST be done after package operation and user creation
    oneshot login_manager

    # fix any messed up file permissions from editing during install
    chrun "chown -Rf $NEWUSER:users /home/$NEWUSER"

    printf "\nThe install section is now finished, press any key to continue.\n"
    read -rn1

    # drop off the user at the config editing menu
    edit_configs
}

install_base()
{
    if [[ -e /run/archiso/sfs/airootfs/etc/skel ]]; then
        printf "\n\nUnpacking base system --- Total: ~ 2.6G\n\n"
        rsync -ah --info=progress2 /run/archiso/sfs/airootfs/ $MNT/
    else
        oneshot mirrorlist_sort
        local vmpkgs
        if [[ $VM &&  $KERNEL == 'linux-lts' ]]; then
            vmpkgs="virtualbox-guest-utils virtualbox-guest-dkms linux-lts-headers"
        elif [[ $VM && $KERNEL == 'linux' ]]; then
            vmpkgs="virtualbox-guest-utils virtualbox-guest-modules-arch"
        fi
        local packages
        packages="$(grep -hv '^#' /usr/share/archlabs/installer/packages.txt)"
        pacstrap $MNT base $KERNEL $UCODE $packages $vmpkgs
    fi

    printf "\n"
    rm -rf $MNT/etc/mkinitcpio-archiso.conf
    find $MNT/usr/lib/initcpio -name 'archiso*' -type f -exec rm '{}' \;
    sed -i 's/volatile/auto/g' $MNT/etc/systemd/journald.conf
    sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" $MNT/etc/sudoers

    if [[ $VM ]]; then
        rm -rfv $MNT/etc/X11/xorg.conf.d/*?.conf
    elif [[ $(lspci | grep ' VGA ' | grep 'Intel') != "" ]]; then
        cat > $MNT/etc/X11/xorg.conf.d/20-intel.conf <<EOF
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "TearFree" "true"
EndSection
EOF
    fi

    if [[ -e /run/archiso/sfs/airootfs ]]; then
        [[ $KERNEL != 'linux-lts' ]] && cp -vf $RUN/x86_64/vmlinuz $MNT/boot/vmlinuz-linux
        [[ $UCODE && ! $VM ]] && cp -vf $RUN/${UCODE/-/_}.img $MNT/boot/${UCODE}.img
    fi

    printf "\n"
    cp -fv /etc/resolv.conf $MNT/etc/
    if [[ -e /etc/NetworkManager/system-connections ]]; then
        cp -rvf /etc/NetworkManager/system-connections $MNT/etc/NetworkManager/
    fi

    cat > $MNT/etc/locale.conf << EOF
LANG=$LOCALE
EOF
    cat > $MNT/etc/default/locale << EOF
LANG=$LOCALE
EOF
    sed -i "s/#en_US.UTF-8/en_US.UTF-8/g; s/#${LOCALE}/${LOCALE}/g" $MNT/etc/locale.gen
    chrun "echo && locale-gen" 2>/dev/null
    printf "\n"
    chrun "ln -svf /usr/share/zoneinfo/$ZONE/$SUBZONE /etc/localtime" 2>/dev/null

    if [[ $BROADCOM_WL == true ]]; then
        echo 'blacklist bcma' >> $MNT/etc/modprobe.d/blacklist.conf
        rm -f $MNT/etc/modprobe/
    fi

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

create_user()
{
    # set root password and shell if needed
    chrun "chpasswd <<< 'root:$ROOT_PASS'"

    if [[ $MYSHELL != *zsh ]]; then
        chrun "usermod -s $MYSHELL root"
        cp -fv $MNT/etc/skel/.mkshrc /root/.mkshrc
    fi

    local groups='audio,autologin,floppy,log,network,rfkill,scanner,storage,optical,power,wheel'

    # setup the autologin group
    chrun "groupadd -r autologin"

    # Create the user, set password, and make sure the ownership of ~/ is correct
    chrun "useradd -m -u 1000 -g users -G $groups -s $MYSHELL $NEWUSER" 2>$ERR
    chrun "chpasswd <<< '$NEWUSER:$USER_PASS'"

    # for neovim set up ~/.config/nvim
    if [[ $PACKAGES =~ neovim ]]; then
        mkdir -p $MNT/home/$NEWUSER/.config/nvim
        cp -fv $MNT/home/$NEWUSER/.vimrc $MNT/home/$NEWUSER/.config/nvim/init.vim
        cp -rfv $MNT/home/$NEWUSER/.vim/colors $MNT/home/$NEWUSER/.config/nvim/colors
    fi

    if [[ $INSTALL_WMS =~ dwm ]]; then
        suckless_install
    fi

    if [[ $INSTALL_WMS == 'plasma' || $LOGIN_WM == 'startkde' ]]; then
        # plasma has their own superkey daemon that conflicts with ksuperkey
        sed -i '/super/d' $HOME/.xprofile
        sed -i '/super/d' /root/.xprofile
    fi

    return 0
}

setup_xinit()
{
    if [[ -e $MNT/home/$NEWUSER/.xinitrc ]]; then
        sed -i "s/openbox-session/${LOGIN_WM}/g" $MNT/home/$NEWUSER/.xinitrc
    else
        printf "%s\n" "exec $LOGIN_WM" > $MNT/home/$NEWUSER/.xinitrc
    fi

    # automatic startx for login shells
    local loginrc
    case $MYSHELL in
        "/bin/bash")
            loginrc=".bash_profile"
            rm -rf $MNT/home/$NEWUSER/.{z,mksh}*
            ;;
        "/usr/bin/mksh")
            loginrc=".profile"
            rm -rf $MNT/home/$NEWUSER/.{z,bash}*
            cat >> $MNT/home/$NEWUSER/.mkshrc << EOF

# colors in less (manpager)
export LESS_TERMCAP_mb=$'\e[01;31m'
export LESS_TERMCAP_md=$'\e[01;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;44;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[01;32m'

export EDITOR=vim
export MANWIDTH=100

# source shell configs
for f in "\$HOME/.mksh/"*?.sh; do
    . "\$f"
done

al-info

EOF
            ;;
        *)
            loginrc=".zprofile"
            rm -rf $MNT/home/$NEWUSER/.{bash,mksh}*
    esac

    # add the shell login file to the edit list after install
    EDIT_FILES[11]+=" /home/$NEWUSER/$loginrc"

    if [[ $AUTOLOGIN == true ]]; then
        sed -i "s/root/${NEWUSER}/g" $SERVICE/autologin.conf
        cat > $MNT/home/$NEWUSER/$loginrc << EOF
# ~/$loginrc
# sourced by $(basename $MYSHELL) when used as a login shell

# automatically run startx when logging in on tty1
if [ -z "\$DISPLAY" ] && [ \$XDG_VTNR -eq 1 ]; then
    exec startx -- vt1 >/dev/null 2>&1
fi
EOF
    else
        rm -rf $SERVICE
        rm -rf $MNT/home/$NEWUSER/.{profile,zprofile,bash_profile}
    fi
}

setup_lightdm()
{
    rm -rf $SERVICE
    rm -rf $MNT/home/$NEWUSER/.{xinitrc,profile,zprofile,bash_profile}
    chrun 'systemctl set-default graphical.target && systemctl enable lightdm.service'
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

login_manager()
{
    SERVICE="$MNT/etc/systemd/system/getty@tty1.service.d"

    # remove welcome message
    sed -i '/printf/d' $MNT/root/.zshrc

    if [[ $LOGIN_TYPE == 'lightdm' ]]; then
        setup_lightdm
    else
        setup_xinit
    fi
}

run_mkinitcpio()
{
    local add=""
    # setup a keyfile for LUKS.. Only when choosing grub and system is UEFI
    if [[ $LUKS && $SYS == 'UEFI' && $BOOTLDR == 'grub' ]]; then
        luks_keyfile
    fi

    # new hooks needed in /etc/mkinitcpio.conf if we used LUKS and/or LVM
    [[ $LVM ]] && add="lvm2"
    [[ $LUKS ]] && add="encrypt$([[ $add ]] && printf " %s" "$add")"
    sed -i "s/block filesystems/block ${add} filesystems ${HOOKS}/g" $MNT/etc/mkinitcpio.conf

    chrun "mkinitcpio -p $KERNEL" 2>$ERR
    echeck "mkinitcpio -p $KERNEL"
}

mirrorlist_sort()
{
    printf "\n%s\n\n" "Sorting the mirrorlist"
    if hash reflector >/dev/null 2>&1; then
        $MIRROR_CMD --save $MNT/etc/pacman.d/mirrorlist --verbose ||
            reflector --score 100 -l 50 -f 10 --sort rate --verbose --save $MNT/etc/pacman.d/mirrorlist
    else
        { eval $MIRROR_CMD || curl -s 'https://www.archlinux.org/mirrorlist/all/'; } |
            sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 10 - > $MNT/etc/pacman.d/mirrorlist
    fi
}

package_operations()
{
    local inpkg="$PACKAGES"           # add the packages chosen during setup
    local rmpkg="archlabs-installer"  # always remove the installer

    if [[ $KERNEL == 'linux-lts' ]]; then
        rmpkg+=" linux"
        inpkg+=" linux-lts"
    fi

    if [[ $INSTALL_WMS == 'plasma' ]]; then
        rmpkg+=" archlabs-ksuperkey"
    fi

    # if the system is a VM then install the needed packages
    if [[ $VM ]]; then
        inpkg+=" virtualbox-guest-utils"
        if [[ $KERNEL == 'linux-lts' ]]; then
            inpkg+=" virtualbox-guest-dkms linux-lts-headers"
        else
            inpkg+=" virtualbox-guest-modules-arch"
        fi
    fi

    # for only gnome or cinnamon we don't need the xfce provided stuff
    [[ $INSTALL_WMS =~ (gnome|cinnamon) ]] &&
        rmpkg+=" $(pacman -Qssq 'xfce4*' 2>/dev/null)"

    # when not using grub bootloader remove it's package and configurations
    if [[ $BOOTLDR != 'grub' ]]; then
        rmpkg+=" grub"
        rm -f $MNT/etc/default/grub
        find $MNT/boot/ -name 'grub*' -exec rm -rf '{}' \; >/dev/null 2>&1
    fi

    # do the same when not using syslinux as the bootloader
    if [[ $BOOTLDR != 'syslinux' ]]; then
        find $MNT/boot/ -name 'syslinux*' -exec rm -rf '{}' \; >/dev/null 2>&1
    fi

    chrun "pacman -Syyu --noconfirm"
    chrun "pacman -S iputils --noconfirm" 2>/dev/null
    chrun "pacman -S base-devel git --needed --noconfirm" 2>/dev/null
    chrun "pacman -S $inpkg --needed --noconfirm"
    chrun "pacman -Rs $rmpkg --noconfirm"

    return 0
}

suckless_install()
{
    # install and setup dwm
    printf "\n%s\n\n" "Installing and setting up dwm."
    mkdir -pv $MNT/home/$NEWUSER/suckless

    for i in dwm dmenu st; do
        p="/home/$NEWUSER/suckless/$i"
        chrun "git clone https://bitbucket.org/natemaia/$i $p"
        e=$?
        if (( e == 0 )); then
            chrun "cd $p; rm -f config.h; make clean install; make clean"
        else
            printf "\n\nFailed to clone dwm repo\n\n"
        fi
    done

    if [[ -d /home/$NEWUSER/suckless/dwm ]]; then
        printf "\n\n%s" "To configure dwm edit /home/$NEWUSER/suckless/dwm/config.h"
        printf "\n%s\n\n" "You can then recompile it with 'sudo make clean install'"
    fi

    sleep 2
}

###############################################################################
# bootloader setup

setup_boot()
{
    tput civis
    if ! BOOTLDR="$(menubox "$_PrepMount" "$_MntBootBody" 0 0 0 ${BOOTLDRS[$SYS]})"; then
        return 1
    fi

    if [[ $BOOT_PART != "" ]]; then
        mount_boot_part || return 1
        setup_boot_device
    fi

    setup_${BOOTLDR} || return 1
}

setup_grub()
{
    EDIT_FILES[9]="/etc/default/grub"

    if [[ $SYS == 'BIOS' ]]; then
        if [[ $BOOT_DEVICE == "" ]]; then
            select_device 'boot' || return 1
        fi
        BCMDS[grub]+=" --target=i386-pc $BOOT_DEVICE && grub-mkconfig -o /boot/grub/grub.cfg"
    else
        if [[ $ROOT_PART == */dev/mapper/* && ! $LVM && ! $LUKS_PASS ]]; then
            luks_pass "$_LuksOpen" "" || return 1
        fi

        # the mount mess is needed for os-prober to work properly in the chroot
        BCMDS[grub]="mkdir -p /run/udev && mkdir -p /run/lvm &&
              mount --bind /hostrun/udev /run/udev &&
              mount --bind /hostrun/lvm /run/lvm &&
              ${BCMDS[grub]} --efi-directory=${BMNTS[UEFI-grub]} --bootloader-id=$DIST &&
              grub-mkconfig -o /boot/grub/grub.cfg &&
              umount /run/udev && umount /run/lvm"
    fi

    return 0
}

setup_syslinux()
{
    EDIT_FILES[9]="/boot/syslinux/syslinux.cfg"
}

setup_systemd-boot()
{
    EDIT_FILES[9]="/boot/loader/entries/$DIST.conf"
}

prerun_grub()
{
    local cfg="$MNT/etc/default/grub"
    sed -i "s/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"${DIST}\"/g;
            s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/g" $cfg

    if [[ $LUKS_DEV ]]; then
        sed -i "s~#GRUB_ENABLE_CRYPTODISK~GRUB_ENABLE_CRYPTODISK~g;
                s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"${LUKS_DEV}\"~g" $cfg
    fi

    if [[ $SYS == 'BIOS' && $LVM && $SEP_BOOT == false ]]; then
        sed -i "s/GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"lvm\"/g" $cfg
    fi

    # needed for os-prober module to work properly in the chroot
    mkdir -p /run/lvm
    mkdir -p /run/udev
    mkdir -p $MNT/hostrun/lvm
    mkdir -p $MNT/hostrun/udev
    mount --bind /run/lvm $MNT/hostrun/lvm
    mount --bind /run/udev $MNT/hostrun/udev

    return 0
}

prerun_systemd-boot()
{
    # no LVM then systemd-boot uses PARTUUID
    [[ $ROOT_PART =~ /dev/mapper ]] || ROOT_PART_ID="PART$ROOT_PART_ID"

    # create the boot entry configs
    mkdir -p ${MNT}${BMNTS[$SYS-systemd-boot]}/loader/entries
    cat > ${MNT}${BMNTS[$SYS-systemd-boot]}/loader/loader.conf << EOF
default  $DIST
timeout  5
editor   no
EOF
    cat > ${MNT}${BMNTS[$SYS-systemd-boot]}/loader/entries/${DIST}.conf << EOF
title   $DIST Linux
linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/${UCODE}.img")
initrd  /initramfs-$KERNEL.img
options root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
EOF
    # add pacman hook to update the bootloader when systemd receives an update
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
    # systemd-boot requires this before running bootctl
    systemd-machine-id-setup --root="$MNT" >/dev/null 2>&1
    return 0
}

prerun_syslinux()
{
    mkdir -pv $MNT${BMNTS[$SYS-syslinux]}/syslinux
    cp -rfv /usr/lib/syslinux/bios/* $MNT${BMNTS[$SYS-syslinux]}/syslinux/

    cat > $cfgdir/syslinux.cfg << EOF
UI menu.c32
PROMPT 0

MENU TITLE $DIST Syslinux Boot Menu
TIMEOUT 50
DEFAULT $DIST

LABEL $DIST
MENU LABEL $DIST Linux
LINUX ../vmlinuz-$KERNEL
APPEND root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
INITRD ../initramfs-$KERNEL.img$([[ $UCODE ]] && printf "\nINITRD %s" "../${UCODE}.img")

LABEL ${DIST}fallback
MENU LABEL $DIST Linux Fallback
LINUX ../vmlinuz-$KERNEL
APPEND root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
INITRD ../initramfs-$KERNEL-fallback.img$([[ $UCODE ]] && printf "\nINITRD %s" "../${UCODE}.img")
EOF
    return 0
}

install_bootloader()
{
    if ! [[ $ROOT_PART =~ /dev/mapper ]]; then
        ROOT_PART_ID="UUID=$(blkid -s PARTUUID -o value $ROOT_PART)"
    else
        # for LVM we just use the partition label
        ROOT_PART_ID="$ROOT_PART"
    fi

    # remove old UEFI boot entries
    if [[ $SYS == 'UEFI' ]]; then
        find ${MNT}${BMNTS[UEFI-$BOOTLDR]}/EFI/ \
            -maxdepth 1 -mindepth 1 -name '[aA][rR][cC][hH][lL]abs' \
            -type d -exec rm -rf '{}' \; >/dev/null 2>&1
    fi

    prerun_$BOOTLDR
    printf "\nInstalling and setting up $BOOTLDR in ${BMNTS[$SYS-$BOOTLDR]}\n\n"
    chrun "${BCMDS[$BOOTLDR]}" 2>$ERR
    echeck "${BCMDS[$BOOTLDR]}"

    if [[ -d $MNT/hostrun ]]; then
        umount $MNT/hostrun/udev >/dev/null 2>&1
        umount $MNT/hostrun/lvm >/dev/null 2>&1
        rm -rf $MNT/hostrun >/dev/null 2>&1
    fi

    # copy efi stub to generic catch all
    if [[ $SYS == 'UEFI' && $BOOTLDR == 'grub' ]]; then
        uefi_boot_fallback
    fi

    return 0
}

uefi_boot_fallback()
{
    # some UEFI firmware requires a dir in the ESP with a generic bootx64.efi
    # see:  https://wiki.archlinux.org/index.php/GRUB#UEFI

    local esp="${MNT}${BMNTS[$SYS-$BOOTLDR]}"

    local default
    default="$(find $esp/EFI/ -maxdepth 1 -mindepth 1 -name '[Bb][oO][oO][tT]' -type d)"

    if [[ $default ]]; then
        default="${default##/*}"
    else
        default="Boot"
    fi

    printf "\n"

    if [[ -d $esp/EFI/$default ]]; then
        rm -rfv $esp/EFI/$default/*
    else
        mkdir -pv $esp/EFI/$default
    fi

    cp -fv $esp/EFI/$DIST/grubx64.efi $esp/EFI/$default/bootx64.efi

    sleep 2
    return 0
}

shim_secure_boot()
{
    efibootmgr -c -w -L $DIST -d $BOOT_DEVICE -p $BOOT_PART_NUM -l ${MNT}${BMNTS[$SYS-$BOOTLDR]}/shim64.efi
}

###############################################################################
# dialog menus

show_cfg()
{
    local cmd mnt pkgs
    cmd="${BCMDS[$BOOTLDR]}"
    mnt="${BMNTS[$SYS-$BOOTLDR]}"
    msgbox "$_PrepTitle" "

---------- PARTITION CONFIGURATION ------------

  Root:  ${ROOT_PART:-None}
  Boot:  ${BOOT_PART:-${BOOT_DEVICE:-None}}

  Swap:  ${SWAP_PART:-None}
  Size:  ${SWAP_SIZE:-None}

  LVM:   ${LVM:-None}
  LUKS:  ${LUKS:-None}

  Extra Mounts: ${EXTRA_MNTS:-${EXTRA_MNT:-None}}
  Mkinit Hooks: ${HOOKS:-None}


---------- BOOTLOADER CONFIGURATION -----------

  Bootloader: ${BOOTLDR:-None}
  Mountpoint: ${mnt:-None}
  Command:    ${cmd:-None}


------------ SYSTEM CONFIGURATION -------------

  Locale:   ${LOCALE:-None}
  Keymap:   ${KEYMAP:-None}
  Hostname: ${HOSTNAME:-None}
  Timezone: ${ZONE:-None}/${SUBZONE:-None}


------------ USER CONFIGURATION --------------

  User:         ${NEWUSER:-None}
  Shell:        ${MYSHELL:-None}
  Session:      ${LOGIN_WM:-None}
  Autologin:    ${AUTOLOGIN:-None}
  Login Method: ${LOGIN_TYPE:-None}


------------ PACKAGES AND MIRRORS -------------

  Kernel:   ${KERNEL:-None}
  Sessions: ${INSTALL_WMS:-None}
  Mirrors:  ${MIRROR_CMD:-None}
  Packages: $(print4 "${PACKAGES:-None}")
"
}

cfg_menu()
{
    tput cnorm
    if ! HOSTNAME="$(getinput "$_ConfHost" "$_HostNameBody" "${DIST,,}")"; then
        return 1
    fi

    tput civis
    if ! LOCALE="$(menubox "$_ConfLocale" "$_LocaleBody" 25 70 20 $LOCALES)"; then
        return 1
    fi

    select_timezone || return 1
    user_creation || return 1

    tput civis
    if ! MYSHELL="$(menubox "$_ShellTitle" "$_ShellBody" 0 0 0 '/usr/bin/zsh' '-' '/bin/bash' '-' '/usr/bin/mksh' '-')"; then
        return 1
    fi

    if ! KERNEL="$(menubox "$_KernelTitle" "$_KernelBody" 0 0 0 'linux' '-' 'linux-lts' '-')"; then
        return 1
    fi

    select_mirrorcmd || return 1

    CONFIG_DONE=true
    return 0
}

select_language()
{
    tput civis
    local lang
    lang=$(menubox "Select Language" \
        "\nLanguage - sprache - taal - språk - lingua - idioma - nyelv - língua\n" 0 0 0 \
        "1"  "English            (en_**)" \
        "2"  "Español            (es_ES)" \
        "3"  "Português [Brasil] (pt_BR)" \
        "4"  "Português          (pt_PT)" \
        "5"  "Français           (fr_FR)" \
        "6"  "Russkiy            (ru_RU)" \
        "7"  "Italiano           (it_IT)" \
        "8"  "Nederlands         (nl_NL)" \
        "9"  "Magyar             (hu_HU)" \
        "10" "Chinese            (zh_CN)")

    src $LNG/english.trans
    FONT="ter-i16n"

    case $lang in
        1)  LOC="en_US.UTF-8" ;;
        2)  src $LNG/spanish.trans    && LOC="es_ES.UTF-8" ;;
        3)  src $LNG/p_brasil.trans   && LOC="pt_BR.UTF-8" ;;
        4)  src $LNG/portuguese.trans && LOC="pt_PT.UTF-8" ;;
        5)  src $LNG/french.trans     && LOC="fr_FR.UTF-8" ;;
        6)  src $LNG/russian.trans    && LOC="ru_RU.UTF-8" FONT="LatKaCyrHeb-16" ;;
        7)  src $LNG/italian.trans    && LOC="it_IT.UTF-8" ;;
        8)  src $LNG/dutch.trans      && LOC="nl_NL.UTF-8" ;;
        9)  src $LNG/hungarian.trans  && LOC="hu_HU.UTF-8" FONT="lat2-16" ;;
        10) src $LNG/chinese.trans    && LOC="zh_CN.UTF-8" ;;
        *)  die
    esac

    sed -i "s/#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
    if [[ $LOC != "en_US.UTF-8" ]]; then
        sed -i "s/#${LOC}/${LOC}/" /etc/locale.gen
        locale-gen >/dev/null 2>&1
    fi
    [[ $TERM == 'linux' ]] && setfont $FONT >/dev/null 2>&1
    export LANG="$LOC"
    return 0
}

user_creation()
{
    tput cnorm
    local values

    if ! values="$(dialog --stdout --no-cancel --separator '~' \
        --ok-label "Submit" --backtitle "$BT" --title " $_UserTitle " \
        --insecure --mixedform "$_UserBody" 27 75 10 \
        "$_Username"  1 1 "" 1 $((${#_Username} + 2))  71 0 0 \
        "$_Password"  2 1 "" 2 $((${#_Password} + 2))  71 0 1 \
        "$_Password2" 3 1 "" 3 $((${#_Password2} + 2)) 71 0 1 \
        "$_RootBody"  6 1 "" 6 $((${#_RootBody} + 1))  71 0 2 \
        "$_Password"  8 1 "" 8 $((${#_Password} + 2))  71 0 1 \
        "$_Password2" 9 1 "" 9 $((${#_Password2} + 2)) 71 0 1)"; then
        return 1
    fi

    local user pass pass2 rpass rpass2
    user="$(awk -F'~' '{print $1}' <<< "$values")"
    pass="$(awk -F'~' '{print $2}' <<< "$values")"
    pass2="$(awk -F'~' '{print $3}' <<< "$values")"
    rpass="$(awk -F'~' '{print $5}' <<< "$values")"
    rpass2="$(awk -F'~' '{print $6}' <<< "$values")"

    # both root passwords are empty, so use the user passwords instead
    [[ $rpass == "" && $rpass2 == "" ]] && { rpass="$pass"; rpass2="$pass2"; }

    # make sure a username was entered and that the passwords match
    if [[ ${#user} -eq 0 || $user =~ \ |\' || $user =~ [^a-z0-9] ||
        $pass == "" || "$pass" != "$pass2" || "$rpass" != "$rpass2" ]]
    then
        if [[ $pass == "" || "$pass" != "$pass2" || "$rpass" != "$rpass2" ]]; then
            # password was left empty or doesn't match
            if [[ $pass == "" ]]; then
                msgbox "$_ErrTitle" "\nUser password CANNOT be left empty.\n$_TryAgain"
            elif [[ "$rpass" != "$rpass2" ]]; then
                msgbox "$_ErrTitle" "$_RootPassErr\n$_TryAgain"
            else
                msgbox "$_ErrTitle" "$_UserPassErr\n$_TryAgain"
            fi
        else # bad username
            msgbox "$_UserErrTitle" "$_UserErrBody"
            user=""
        fi
        # recursively loop back unless the user cancels
        user || return 1
    else
        NEWUSER="$user"
        USER_PASS="$pass"
        ROOT_PASS="$rpass"
    fi
    return 0
}

select_keymap()
{
    tput civis
    if ! KEYMAP="$(menubox "$_PrepLayout" "$_XMapBody" 20 70 12 \
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
        'id' 'Indonesian' 'bt'    'Dzongkha'    'lv' 'Latvian'    'md' 'Moldavian'  'mao' 'Maori' \
        'by' 'Belarusian' 'az'    'Azerbaijani' 'mk' 'Macedonian' 'kh' 'Khmer'    'epo' 'Esperanto' \
        'me' 'Montenegrin')"; then
        return 1
    fi

    # when a matching console map is not available open a selection dialog
    if [[ $CMAPS == *"$KEYMAP"* ]]; then
        CMAP="$KEYMAP"
    else
        if ! CMAP="$(menubox "$_CMapTitle" "$_CMapBody" 20 70 12 $CMAPS)"; then
            return 1
        fi
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
    # create associative array for SUBZONES[zone]
    local f="/usr/share/zoneinfo/zone.tab"
    declare -A SUBZONES
    for i in America Australia Asia Atlantic Africa Europe Indian Pacific Arctic Antarctica; do
        SUBZONES[$i]="$(awk '/'"$i"'\// {gsub(/'"$i"'\//, ""); print $3, $1}' $f)"
    done

    tput civis
    if ! ZONE="$(menubox "$_TimeZTitle" "$_TimeZBody" 20 70 10 \
        'America' '-' 'Australia' '-' 'Asia' '-' 'Atlantic' '-' 'Africa' '-' \
        'Europe' '-' 'Indian' '-' 'Pacific' '-' 'Arctic' '-' 'Antarctica' '-')"; then
        return 1
    fi

    if ! SUBZONE="$(menubox "$_TimeZTitle" "$_TimeSubZBody" 20 70 12 ${SUBZONES[$ZONE]})"; then
        return 1
    fi

    yesno "$_TimeZTitle" "$_TimeZQ $ZONE/$SUBZONE?\n" && return 0 || select_timezone
}

select_wm_or_de()
{
    tput civis
    if ! INSTALL_WMS="$(dialog --cr-wrap --stdout --no-cancel --backtitle "$BT" \
        --title " $_WMChoice " --checklist "$_WMChoiceBody\n" 0 0 0 \
        "i3-gaps"  "A fork of i3 window manager with more features including gaps" off \
        "dwm"      "A customized fork of dwm, with patches and modifications" off \
        "openbox"  "A lightweight, powerful, and highly configurable stacking window manager" off \
        "bspwm"    "A tiling window manager that represents windows as the leaves of a binary tree" off \
        "gnome"    "A desktop environment that aims to be simple and easy to use" off \
        "cinnamon" "A desktop environment combining a traditional desktop layout with modern graphical effects" off \
        "plasma"   "KDE Plasma is a software project currently comprising a full desktop environment" off \
        "xfce4"    "A lightweight and modular desktop environment based on GTK+ 2 and 3" off)"; then
        return 1
    fi

    WM_NUM=$(awk '{print NF}' <<< "$INSTALL_WMS")
    WM_PACKAGES="${INSTALL_WMS/dwm/}"   # remove dwm from package list
    WM_PACKAGES="${WM_PACKAGES//  / }"  # remove double spaces

    # packages needed for the selected WMs/DEs
    for wm in $INSTALL_WMS; do
        LOGIN_CHOICES+="$wm - "
        if [[ $wm == 'plasma' ]]; then
            if yesno "$_WMChoice" "\nInstall kde-applications?\n\nNOTE: This is a large package group.\n"; then
                WM_PACKAGES+=" ${WM_EXT[$wm]}"
            fi
        else
            WM_PACKAGES+=" ${WM_EXT[$wm]}"
        fi
    done

    # choose how to log in
    select_login || return 1

    # choose which WM/DE to start at login, only for xinit
    if [[ $LOGIN_TYPE == 'xinit' ]]; then
        if [[ $WM_NUM -eq 1 ]]; then
            LOGIN_WM="${WM_SESSIONS[$INSTALL_WMS]}"
        else
            if ! LOGIN_WM="$(menubox "$_WMLogin" "$_WMLoginBody" 0 0 0 $LOGIN_CHOICES)"; then
                return 1
            else
                LOGIN_WM="${WM_SESSIONS[$LOGIN_WM]}"
            fi
        fi

        if yesno "$_WMLogin" "$_AutoLoginBody\n"; then
            AUTOLOGIN=true
        else
            AUTOLOGIN=false
        fi
    else
        AUTOLOGIN=false
    fi

    # add packages to the main package list
    PACKAGES+=" ${WM_PACKAGES/^ /}"
}

select_login()
{
    if ! LOGIN_TYPE="$(menubox "$_WMLogin" "$_LoginTypeBody" 0 0 0 \
        "xinit" "Console login without a display manager" \
        "lightdm" "Lightweight display manager with a gtk greeter")"; then
        return 1
    fi

    if [[ $LOGIN_TYPE == 'lightdm' ]]; then
        WM_PACKAGES+=" lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice"
        EDIT_FILES[11]="/etc/lightdm/lightdm.conf /etc/lightdm/lightdm-gtk-greeter.conf"
    else
        WM_PACKAGES="$(sed 's/ lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice//g' <<< "$WM_PACKAGES")"
        PACKAGES="$(sed 's/ lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice//g' <<< "$PACKAGES")"
        EDIT_FILES[11]="/home/$NEWUSER/.xinitrc /home/$NEWUSER/.xprofile"
    fi
}

select_packages()
{
    if [[ $CURRENT_MENU != "packages" ]]; then
        SAVED=$SELECTED
        SELECTED=1
        CURRENT_MENU="packages"
    elif (( SELECTED < 9 )); then
        ((SELECTED++)) # increment the highlighted menu item
    fi

    tput civis
    SELECTED=$(dialog --cr-wrap --stdout --no-cancel --backtitle "$BT" \
        --title " $_Packages " --default-item $SELECTED \
        --menu "$_PackageMenu" 0 0 0 \
        "1" "Browsers" \
        "2" "Editors" \
        "3" "Terminals" \
        "4" "Multimedia" \
        "5" "Chat/Mail" \
        "6" "Professional" \
        "7" "System" \
        "8" "Miscellaneous" \
        "9" "$_Done")

    if [[ $SELECTED -lt 9 ]]; then
        case $SELECTED in
            1) PACKAGES+=" $(select_browsers)" ;;
            2) PACKAGES+=" $(select_editors)" ;;
            3) PACKAGES+=" $(select_terminals)" ;;
            4) PACKAGES+=" $(select_multimedia)" ;;
            5) PACKAGES+=" $(select_mailchat)" ;;
            6) PACKAGES+=" $(select_professional)" ;;
            7) PACKAGES+=" $(select_managment)" ;;
            8) PACKAGES+=" $(select_extra)" ;;
        esac
        select_packages
    fi

    # add any extras for each package
    for pkg in $PACKAGES; do
        [[ ${PKG_EXT[$pkg]} ]] && PACKAGES+=" ${PKG_EXT[$pkg]}"
    done

    # add mksh to package list if it was chosen as the login shell
    if [[ $MYSHELL == *mksh ]]; then
        PACKAGES+=" mksh"
    fi

    # remove duplicates and leading spaces
    PACKAGES="$(uniq <<< "${PACKAGES/^ /}")"
    return 0
}

select_mirrorcmd()
{
    local c
    local key="5f29642060ab983b31fdf4c2935d8c56"

    if hash reflector >/dev/null 2>&1; then
        MIRROR_CMD="reflector --score 100 -l 50 -f 10 --sort rate --verbose"
        yesno "$_MirrorTitle" "$_MirrorSetup" "Automatic" "Custom" && return 0

        c="$(json 'country_name' "$(json 'ip' "check&?access_key=${key}&fields=ip")?access_key=${key}&fields=country_name")"
        MIRROR_CMD="reflector --country $c --score 80 --latest 40 --fastest 10 --sort rate --verbose"

        tput cnorm
        MIRROR_CMD="$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
            --title " $_MirrorTitle " --inputbox "$_MirrorCmd\n
      --score n     Limit the list to the n servers with the highest score.
      --latest n    Limit the list to the n most recently synchronized servers.
      --fastest n   Return the n fastest mirrors that meet the other criteria.
      --sort {age,rate,country,score,delay}

            'age':      Last server synchronization;
            'rate':     Download rate;
            'country':  Server location;
            'score':    MirrorStatus score;
            'delay':    MirrorStatus delay.\n" 0 0 "$MIRROR_CMD")"
    else
        c="$(json 'country_code' "$(json 'ip' "check&?access_key=${key}&fields=ip")?access_key=${key}&fields=country_code")"
        local w="https://www.archlinux.org/mirrorlist"
        if [[ $c ]]; then
            if [[ $c =~ (CA|US) ]]; then
                MIRROR_CMD="curl -s '$w/?country=US&country=CA&protocol=https&use_mirror_status=on'"
            else
                MIRROR_CMD="curl -s '$w/?country=${c}&protocol=https&use_mirror_status=on'"
            fi
        else
            MIRROR_CMD="curl -s '$w/?country=US&country=CA&country=NZ&country=GB&country=AU&protocol=https&use_mirror_status=on'"
        fi
    fi
    return 0
}

edit_configs()
{
    if [[ $CURRENT_MENU != "edit" ]]; then
        SELECTED=1; CURRENT_MENU="edit"
    elif (( SELECTED < 11 )); then
        (( SELECTED++ ))
    fi

    tput civis
    if [[ $DEBUG == true ]]; then
        local exitstr="View debug log before the exit & reboot"
    else
        local exitstr="Exit & reboot"
    fi

    SELECTED=$(dialog --cr-wrap --no-cancel --stdout --backtitle "$BT" \
        --title " $_EditTitle " --default-item $SELECTED \
        --menu "$_EditBody" 0 0 0 \
        "1"  "$exitstr" \
        "2"  "${EDIT_FILES[2]}" \
        "3"  "${EDIT_FILES[3]}" \
        "4"  "${EDIT_FILES[4]}" \
        "5"  "${EDIT_FILES[5]}" \
        "6"  "${EDIT_FILES[6]}" \
        "7"  "${EDIT_FILES[7]}" \
        "8"  "${EDIT_FILES[8]}" \
        "9"  "${EDIT_FILES[9]}" \
        "10" "${EDIT_FILES[10]}" \
        "11" "${EDIT_FILES[11]}")

    if [[ ! $SELECTED || $SELECTED -eq 1 ]]; then
        [[ $DEBUG == true && -r $DBG ]] && vim $DBG
        # when die() is passed 127 it will call: systemctl -i reboot
        die 127
    else
        local existing_files=""
        for f in $(printf "%s" "${EDIT_FILES[$SELECTED]}"); do
            [[ -e ${MNT}$f ]] && existing_files+=" ${MNT}$f"
        done

        if [[ $existing_files ]]; then
            vim -O $existing_files
        else
            msgbox "$_ErrTitle" "$_NoFileErr"
        fi
    fi

    edit_configs
}

###############################################################################
# entry point

main()
{
    if [[ $CURRENT_MENU != "main" && $SAVED ]]; then
        CURRENT_MENU="main"
        SELECTED=$((SAVED + 1))
        unset SAVED
    elif [[ $CURRENT_MENU != "main" ]]; then
        SELECTED=1
        CURRENT_MENU="main"
    elif (( SELECTED < 10 )); then
        ((SELECTED++))
    fi

    tput civis
    SELECTED=$(dialog --cr-wrap --stdout --backtitle "$BT" \
        --title " $_PrepTitle " --default-item $SELECTED \
        --cancel-label "Exit" --menu "$_PrepBody" 0 0 0 \
        "1" "$_PrepShowDev" \
        "2" "$_PrepParts" \
        "3" "$_PrepLUKS" \
        "4" "$_PrepLVM" \
        "5" "$_PrepMount" \
        "6" "$_PrepConfig" \
        "7" "Select WM/DE(s)" \
        "8" "Select Packages" \
        "9" "Check Choices" \
        "10" "$_PrepInstall")

    if [[ $WARN != true && $SELECTED =~ (2|5) ]]; then
        WARN=true
        msgbox "$_PrepTitle" "$_WarnMount"
    fi

    case $SELECTED in
        1)
            device_tree
            ;;
        2)
            partition || SELECTED=$((SELECTED - 1))
            ;;
        3)
            luks_menu || SELECTED=$((SELECTED - 1))
            ;;
        4)
            lvm_menu || SELECTED=$((SELECTED - 1))
            ;;
        5)
            mnt_menu || SELECTED=$((SELECTED - 1))
            ;;
        6)
            if preinstall_checks; then
                cfg_menu || SELECTED=$((SELECTED - 1))
            fi
            ;;
        7)
            if preinstall_checks 1; then
                select_wm_or_de || SELECTED=$((SELECTED - 1))
            fi
            ;;
        8)
            if preinstall_checks 1; then
                select_packages || SELECTED=$((SELECTED - 1))
            fi
            ;;
        9)
            preinstall_checks 1 && show_cfg
            ;;
        10)
            preinstall_checks 1 && install
            ;;
        *)
            yesno "$_CloseInst" "$_CloseInstBody" "Exit" "Back" && die
    esac
}

# trap Ctrl-C to properly exit
trap sigint INT

for arg in "$@"; do
    [[ $arg =~ (--debug|-d) ]] && debug
done

# initial prep
select_language
select_keymap
system_checks
system_identify
system_devices
msgbox "$_WelTitle $DIST Installer" "$_WelBody"

while true; do
    main
done
