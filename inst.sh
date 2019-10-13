#!/bin/bash

# This program is free software, provided under the GNU GPL
# Written by Nathaniel Maia for use in Archlabs
# Some ideas and code reworked from other resources
# AIF, Cnichi, Calamares, Arch Wiki.. Credit where credit is due

VER=2.0.77

# bulk default values {

: ${DIST=ArchLabs}                 # distro name if not set
MNT=/mnt                           # install mountpoint
ANS=/tmp/ans                       # dialog answer file
BOOTDIR=boot                       # location to mount boot partition
FONT=ter-i16n                      # font used for the linux console
HOOKS=shutdown                     # list of additional mkinitcpio HOOKS
SEL=0                              # currently selected menu item
SYS=Unknown                        # bios type to be determined: UEFI/BIOS
ERR=/tmp/errlog                    # error log used internally
DBG=/tmp/debuglog                  # debug log when passed -d
RUN=/run/archiso/bootmnt/arch/boot # path for live system /boot
VM="$(dmesg | grep -i hypervisor)" # system running in a virtual machine
export DIALOGOPTS="--cr-wrap"      # see `man dialog`

BASE_PKGS="base-devel xorg xorg-drivers sudo git gvfs gtk3 libmad libmatroska tumbler "
BASE_PKGS+="playerctl pulseaudio pulseaudio-alsa pavucontrol pamixer scrot xdg-user-dirs "
BASE_PKGS+="ffmpeg gstreamer gst-libav gst-plugins-base gst-plugins-good bash-completion "

WM_BASE_PKGS="arandr nitrogen polkit-gnome network-manager-applet "
WM_BASE_PKGS+="volumeicon xclip exo laptop-detect xdotool compton wmctrl feh "
WM_BASE_PKGS+="gnome-keyring dunst gsimplecal xfce4-power-manager xfce4-settings"

SYS_MEM="$(awk '/MemTotal/ {print int($2 / 1024) "M"}' /proc/meminfo)"
LOCALES="$(awk '/\.UTF-8/ {gsub(/# .*|#/, ""); if ($1) {print $1 " - "}}' /etc/locale.gen)"
CMAPS="$(find /usr/share/kbd/keymaps -name '*.map.gz' | awk '{gsub(/\.map\.gz|.*\//, ""); print $1 " - "}' | sort)"

[[ $LINES ]] || LINES=$(tput lines)
[[ $COLUMNS ]] || COLUMNS=$(tput cols)

# }

# commands used to install each bootloader, however most get modified during runtime {
declare -A BCMDS=(
[refind-efi]='refind-install'
[grub]='grub-install --recheck --force' [syslinux]='syslinux-install_update -i -a -m'
[efistub]='efibootmgr -v -d /dev/sda -p 1 -c -l' [systemd-boot]='bootctl --path=/boot install'
) # }

# executable name for each wm/de used in ~/.xinitrc {
declare -A WM_SESSIONS=(
[dwm]='dwm' [i3-gaps]='i3' [bspwm]='bspwm' [awesome]='awesome' [plasma]='startkde' [xfce4]='startxfce4'
[gnome]='gnome-session' [fluxbox]='startfluxbox' [openbox]='openbox-session' [cinnamon]='cinnamon-session'
) # }

# packages installed for each wm/de, most are depends of the skel packages {
declare -A WM_EXT=(
[dwm]='' [gnome]='' [cinnamon]='gnome-terminal' [plasma]='kdebase-meta'
[awesome]='archlabs-skel-awesome' [bspwm]='archlabs-skel-bspwm' [fluxbox]='archlabs-skel-fluxbox'
[i3-gaps]='archlabs-skel-i3-gaps' [openbox]='archlabs-skel-openbox' [xfce4]='archlabs-skel-xfce4 xfce4-goodies'
) # }

# files offered for editing after install is complete {
declare -A EDIT_FILES=(
[login]='' # login is populated once we know the username and shell
[fstab]='/etc/fstab' [sudoers]='/etc/sudoers' [crypttab]='/etc/crypttab' [pacman]='/etc/pacman.conf'
[console]='/etc/vconsole.conf' [mkinitcpio]='/etc/mkinitcpio.conf' [hostname]='/etc/hostname /etc/hosts'
[bootloader]="/boot/loader/entries/$DIST.conf"  # ** based on bootloader
[locale]='/etc/locale.conf /etc/default/locale' [keyboard]='/etc/X11/xorg.conf.d/00-keyboard.conf /etc/default/keyboard'
) # }

# mkfs command flags for filesystem formatting {
declare -A FS_CMD_FLAGS=(
[f2fs]='' [jfs]='-q' [xfs]='-f' [ntfs]='-q' [ext2]='-q' [ext3]='-q' [ext4]='-q' [vfat]='-F32' [nilfs2]='-q' [reiserfs]='-q'
) # }

# mount options for each filesystem {
declare -A FS_OPTS=(
[vfat]='' [ntfs]='' [ext2]='' [ext3]=''  # NA
[jfs]='discard errors=continue errors=panic nointegrity'
[reiserfs]='acl nolog notail replayonly user_xattr off'
[ext4]='discard dealloc nofail noacl relatime noatime nobarrier nodelalloc'
[xfs]='discard filestreams ikeep largeio noalign nobarrier norecovery noquota wsync'
[nilfs2]='discard nobarrier errors=continue errors=panic order=relaxed order=strict norecovery'
[f2fs]='discard fastboot flush_merge data_flush inline_xattr inline_data noinline_data inline_dentry no_heap noacl nobarrier norecovery noextent_cache disable_roll_forward disable_ext_identify'
) # }

# packages installed for each login option {
declare -A LOGIN_PKGS=(
[xinit]='xorg-xinit' [ly]='archlabs-ly' [gdm]='gdm' [sddm]='sddm'
[lightdm]='lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice'
) # }

# extras installed for user selected packages {
# if a package requires additional packages that aren't already dependencies
# they can be added here eg. [package]="extra"
declare -A PKG_EXT=(
[vlc]='qt4' [mpd]='mpc' [mupdf]='mupdf-tools'
[rxvt-unicode]='urxvt-pearls' [zathura]='zathura-pdf-poppler' [noto-fonts]='noto-fonts-emoji' [cairo-dock]='cairo-dock-plug-ins' [qt5ct]='qt5-styleplugins'
[vlc]='qt5ct qt5-styleplugins' [qutebrowser]='qt5ct qt5-styleplugins' [qbittorrent]='qt5ct qt5-styleplugins' [transmission-qt]='qt5ct qt5-styleplugins'
[bluez]='bluez-libs bluez-utils bluez-tools bluez-plugins bluez-hid2hci' [kdenlive]='kdebase-meta dvdauthor frei0r-plugins breeze breeze-gtk qt5ct qt5-styleplugins'
) # }

# dialog text variables {
# Basics (somewhat in order)
_welcome="\nThis will help you get $DIST installed and setup on your system.\n\nIf you are unsure about a section the default option will be listed or\nthe first selected item will be the default.\n\n\nMenu Navigation:\n\n - Select items with the arrow keys or the option number.\n - Use [Space] to toggle check boxes and [Enter] to accept.\n - Switch between fields using [Tab] or the arrow keys.\n - Use [Page Up] and [Page Down] to jump whole pages\n - Press the highlighted key of an option to select it.\n"
_keymap="\nPick which keymap to use for the system from the list below\n\nThis is used once a graphical environment is running (Xorg).\n\nSystem default: us"
_vconsole="\nSelect the console keymap, the console is the tty shell you reach before starting a graphical environment (Xorg).\n\nIts keymap is seperate from the one used by the graphical environments, though many do use the same such as 'us' English.\n\nSystem default: us"
_device="\nSelect a device to use from the list below.\n\nDevices (/dev) are the available drives on the system. /sda, /sdb, /sdc ..."
_resize="\nSelect a new filesystem size in MB, a new partition will be created from the free space but will be left unformatted.\nThe lowest size is just enough to fit the currently in use space on the partition while the default is set to split the free space evenly.\n\nUse Tab or the arrow keys move the cursor between the buttons and the value, when the cursor is on the value, you can edit it by:\n\n - left/right cursor movement to select a digit to modify\n - +/-  characters to increment/decrement the digit by one\n - 0 through 9 to set the digit to the given value\n\nSome keys are also recognized in all cursor positions:\n\n - Home/End set the value to its maximum or minimum\n - Pageup/Pagedown increment the value so that the slider moves by one column."
_mount="\nUse [Space] to toggle mount options from below, press [Enter] when done to confirm selection.\n\nNot selecting any and confirming will run an automatic mount."
_warn="\nIMPORTANT:\n\nChoose carefully when editing, formatting, and mounting partitions or your DATA MAY BE LOST.\n\nTo mount a partition without formatting it, select 'skip' when prompted to choose a filesystem during the mounting stage.\nThis can only be used for partitions that already contain a filesystem and cannot be the root (/) partition, it needs to be formatted before install.\n"
_part="\nFull device auto partitioning is available for beginners otherwise cfdisk is recommended.\n\n  - All systems will require a root partition (8G or greater).\n  - UEFI or BIOS using LUKS without LVM require a separate boot partition (100-512M)."
_uefi="\nSelect the EFI boot partition (/boot), required for UEFI boot.\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as vfat/fat32 if not already."
_bios="\nDo you want to use a separate boot partition? (optional)\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as ext3/4 if not already."
_biosluks="\nSelect the boot partition (/boot), required for LUKS.\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as ext3/4 if not already."
_format="is already formatted correctly.\n\nFor a clean install, previously existing partitions should be reformatted, however this removes ALL data (bootloaders) on the partition so choose carefully.\n\nDo you want to reformat the partition?\n"
_swapsize="\nEnter the size of the swapfile in megabytes (M) or gigabytes (G).\n\neg. 100M will create a 100 megabyte swapfile, while 10G will create a 10 gigabyte swapfile.\n\nFor ease of use and as an example it is filled in to match the size of your system memory (RAM).\n\nMust be greater than 1, contain only whole numbers, and end with either M or G."
_expart="\nYou can now choose any additional partitions you want mounted, you'll be asked for a mountpoint after.\n\nSelect 'done' to finish the mounting step and begin unpacking the base system in the background."
_exmnt="\nWhere do you want the partition mounted?\n\nEnsure the name begins with a slash (/).\nExamples include: /usr, /home, /var, etc."
_user="\nEnter a name and password for the new user account.\n\nThe name must not use capital letters, contain any periods (.), end with a hyphen (-), or include any colons (:)\n\nNOTE: Use [Up], [Down], or [Tab] to switch between fields, and [Enter] to accept."
_hostname="\nEnter a hostname for the new system.\n\nA hostname is used to identify systems on the network.\n\nIt's restricted to alphanumeric characters (a-z, A-Z, 0-9).\nIt can contain hyphens (-) BUT NOT at the beggining or end."
_locale="\nLocale determines the system language and currency formats.\n\nThe format for locale names is languagecode_COUNTRYCODE\n\neg. en_US is: english United States\n    en_GB is: english Great Britain"
_timez="\nThe time zone is used to set the system clock.\n\nSelect your country or continent from the list below"
_timesubz="\nSelect the nearest city to you or one with the same time zone.\n\nTIP: Pressing the first letter of the city name repeatedly will navigate between entries beggining with that letter."
_sessions="\nUse [Space] to toggle available sessions, use [Enter] to accept the selection and continue.\n\nA basic package set will be installed for compatibility and functionality."
_login="\nSelect which of your session choices to use for the initial login.\n\nYou can be change this later by editing your ~/.xinitrc"
_autologin="\nDo you want autologin enabled for USER?\n\nIf so the following two files will be created (disable autologin by removing them):\n\n - /home/USER/RC (run startx when logging in on tty1)\n - /etc/systemd/system/getty@tty1.service.d/autologin.conf (login USER without password)\n"
_packages="\nUse [Space] to move a package into the selected area and press [Enter] to accept the selection.\n\nPackages may be installed by your DE/WM (if any), or for the packages you select."
_edit="\nBefore exiting you can select configuration files to review/change.\n\nIf you need to make other changes with the drives still mounted, use Ctrl-z to pause the installer, when finished type 'fg' and [Enter] to resume the installer, if you want to avoid the automatic reboot using Ctrl-c will cleanly exit."

# LUKS
_luksnew="Basic LUKS Encryption"
_luksadv="Advanced LUKS Encryption"
_luksopen="Open Existing LUKS Partition"
_luksmenu="\nA seperate boot partition without encryption or logical volume management (LVM) is required (except BIOS systems using grub).\n\nBasic uses the default encryption settings, and is recommended for beginners. Advanced allows cypher and key size parameters to be entered manually."
_luksomenu="\nEnter a name and password for the encrypted device.\n\nIt is not necessary to prefix the name with /dev/mapper/,an example has been provided."
_lukskey="Once the specified flags have been amended, they will automatically be used with the 'cryptsetup -q luksFormat /dev/...' command.\n\nNOTE: Do not specify any additional flags such as -v (--verbose) or -y (--verify-passphrase)."

# LVM
_lvmmenu="\nLogical volume management (LVM) allows 'virtual' hard drives (volume groups) and partitions (logical volumes) to be created from existing device partitions.\n\nA volume group must be created first, then one or more logical volumes within it.\n\nLVM can also be used with an encrypted partition to create multiple logical volumes (e.g. root and home) within it."
_lvmnew="Create Volume Group and Volume(s)"
_lvmdel="Delete an Existing Volume Group"
_lvmdelall="Delete ALL Volume Group(s) and Volume(s)"
_lvmvgname="\nEnter a name for the volume group (VG) being created from the partition(s) selected."
_lvmlvname="\nEnter a name for the logical volume (LV) being created.\n\nThis is similar to setting a label for a partition."
_lvmlvsize="\nEnter what size you want the logical volume (LV) to be in megabytes (M) or gigabytes (G).\n\neg. 100M will create a 100 megabyte volume, 10G will create a 10 gigabyte volume."
_lvmdelask="\nConfirm deletion of volume group(s) and logical volume(s).\n\nDeleting a volume group, will delete all logical volumes within it.\n"

# Errors
_errexpart="\nCannot mount partition due to a problem with the mountpoint.\n\nEnsure it begins with a slash (/) followed by atleast one character.\n"
_errpart="\nYou need create the partiton(s) first.\n\n\nBIOS systems require at least one partition (ROOT).\n\nUEFI systems require at least two (ROOT and EFI).\n"
_lukserr="\nA minimum of two partitions are required for encryption:\n\n 1. root (/) - standard or LVM.\n 2. boot (/boot) - standard (unless using LVM on BIOS systems).\n"
_lvmerr="\nThere are no viable partitions available to use for LVM, a minimum of one is required.\n\nIf LVM is already in use, deactivating it will allow the partition(s) to be used again.\n"
_lvmerrvgname="\nInvalid name entered.\n\nThe volume group name may be alpha-numeric, but may not contain spaces, start with a '/', or already be in use.\n"
_lvmerlvname="\nInvalid name entered.\n\nThe logical volume (LV) name may be alpha-numeric, but may not contain spaces or be preceded with a '/'\n"
_lvmerrlvsize="\nInvalid value Entered.\n\nMust be a numeric value with 'M' (megabytes) or 'G' (gigabytes) at the end.\n\neg. 400M, 10G, 250G, etc...\n\nThe value may also not be equal to or greater than the remaining size of the volume group.\n"

# }

###############################################################################
# selection menus
# main is the entry point which calls functions including outside of its block
# once those functions finished they always are returned here with the
# exception of install_main(), it exits upon completion

main()
{
	(( SEL < 12 )) && (( SEL++ ))
	tput civis
	dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " Prepare " --default-item $SEL --cancel-label 'Exit' --menu "$_prep" 0 0 0 \
		1 "Device tree (optional)" \
		2 "Partitioning (optional)" \
		3 "LUKS setup (optional)" \
		4 "LVM setup (optional)" \
		5 "Mount partitions" \
		6 "System bootloader" \
		7 "User and password" \
		8 "System configuration" \
		9 "Select WM/DE (optional)" \
		10 "Select Packages (optional)" \
		11 "View configuration (optional)" \
		12 "Start the installation" 2>"$ANS"

	read -r SEL < "$ANS"
	[[ -z $WARN && $SEL =~ (2|5) ]] && { msg "Data Warning" "$_warn"; WARN=true; }
	case $SEL in
		1) part_show ;;
		2) part_menu || (( SEL-- )) ;;
		3) luks_menu || (( SEL-- )) ;;
		4) lvm_menu || (( SEL-- )) ;;
		5) mount_menu || (( SEL-- )) ;;
		6) prechecks 0 && { select_boot || (( SEL-- )); } ;;
		7) prechecks 1 && { select_mkuser || (( SEL-- )); } ;;
		8) prechecks 2 && { select_config || (( SEL-- )); } ;;
		9) prechecks 3 && { select_sessions || (( SEL-- )); } ;;
		10) prechecks 3 && { select_packages || (( SEL-- )); } ;;
		11) prechecks 3 && select_show ;;
		12) prechecks 3 && install_main ;;
		*) yesno "Exit" "\nUnmount partitions (if any) and exit the installer?\n" && die 0
	esac
}

select_boot()
{
	if [[ $SYS == 'BIOS' ]]; then
		dlg BOOTLDR menu "BIOS Bootloader" "\nSelect which bootloader to use." \
			"grub"     "The Grand Unified Bootloader, standard among many Linux distributions" \
			"syslinux" "A collection of boot loaders for booting drives, CDs, or over the network" || return 1
	else
		dlg BOOTLDR menu "UEFI Bootloader" "\nSelect which bootloader to use." \
			"systemd-boot" "A simple UEFI boot manager which executes configured EFI images" \
			"grub"         "The Grand Unified Bootloader, standard among many Linux distributions" \
			"refind-efi"   "A UEFI boot manager that aims to be platform neutral and simplify multi-boot" \
			"efistub"      "Boot the kernel image directly (no chainloading support)" \
			"syslinux"     "A collection of boot loaders for booting drives, CDs, or over the network (no chainloading support)" || return 1
	fi
	setup_${BOOTLDR}
}

select_show()
{
	local pkgs="${USER_PKGS//  / } ${PACKAGES//  / }"
	[[ $BOOT_PART ]] && local mnt="/$BOOTDIR"
	[[ $INSTALL_WMS == *dwm* ]] && pkgs="dwm st dmenu $pkgs"
	pkgs="${pkgs//  / }" pkgs="${pkgs# }"
	msg "Show Configuration" "
---------- PARTITION CONFIGURATION ------------

  Root:  ${ROOT_PART:-none}
  Boot:  ${BOOT_PART:-${BOOT_DEV:-none}}
  Mount: ${mnt:-none}
  Swap:  ${SWAP_PART:-none}
  Size:  ${SWAP_SIZE:-none}
  Extra: ${EXMNTS:-${EXMNT:-none}}
  Hooks: ${HOOKS:-none}

  LVM:   ${LVM:-none}
  LUKS:  ${LUKS:-none}


------------ SYSTEM CONFIGURATION -------------

  Locale:   ${MYLOCALE:-none}
  Keymap:   ${KEYMAP:-none}
  Hostname: ${MYHOST:-none}
  Timezone: ${ZONE:-none}/${SUBZ:-none}


------------ USER CONFIGURATION ---------------

  Username:      ${NEWUSER:-none}
  Login Shell:   ${MYSHELL:-none}
  Login Session: ${LOGIN_WM:-none}
  Autologin:     ${AUTOLOGIN:-none}
  Login Type:    ${LOGIN_TYPE:-none}


----------- PACKAGE CONFIGURATION -------------

  Kernel:     ${KERNEL:-none}
  Bootloader: ${BOOTLDR:-none}
  Packages:   ${pkgs:-none}
"
}

select_login()
{
	[[ $INSTALL_WMS ]] || return 0

	AUTOLOGIN='' # no autologin unless using xinit

	dlg LOGIN_TYPE menu "Login Management" "\nSelect what kind of login management to use." \
		"xinit"   "Console login without a display manager" \
		"ly"      "TUI display manager with a ncurses-like interface" \
		"lightdm" "Lightweight display manager with a gtk greeter" \
		"gdm"     "Gnome display manager" \
		"sddm"    "Simple desktop display manager" || return 1

	case $LOGIN_TYPE in
		ly) EDIT_FILES[login]="/etc/ly/config.ini" ;;
		gdm|sddm) EDIT_FILES[login]="" ;;
		lightdm) EDIT_FILES[login]="/etc/lightdm/lightdm.conf /etc/lightdm/lightdm-gtk-greeter.conf" ;;
		xinit) EDIT_FILES[login]="/home/$NEWUSER/.xinitrc /home/$NEWUSER/.xprofile"
			if (( $(wc -w <<< "$INSTALL_WMS") > 1 )); then
				dlg LOGIN_WM menu "Login Management" "$_login" $LOGIN_CHOICES || return 1
				LOGIN_WM="${WM_SESSIONS[$LOGIN_WM]}"
			fi
			[[ -z $LOGIN_WM ]] && LOGIN_WM="${WM_SESSIONS[${INSTALL_WMS%% *}]}"
			yesno "Autologin" "$(sed "s|USER|$NEWUSER|g; s|RC|$LOGINRC|g" <<< "$_autologin")" && AUTOLOGIN=true || AUTOLOGIN=''
			;;
	esac
}

select_config()
{
	typeset -i i=0
	CONFIG_DONE=''

	until [[ $CONFIG_DONE ]]; do
		case $i in
			0) dlg MYSHELL menu "Shell" "\nChoose which shell to use." \
					zsh  'A very advanced and programmable command interpreter (shell) for UNIX' \
					bash 'The GNU Bourne Again shell, standard in many GNU/Linux distributions' \
					mksh 'The MirBSD Korn Shell - an enhanced version of the public domain ksh' || return 1
				;;
			1) dlg MYHOST input "Hostname" "$_hostname" "${DIST,,}" limit || { i=0; continue; } ;;
			2) dlg MYLOCALE menu "Locale" "$_locale" $LOCALES || { i=1; continue; } ;;
			3) ZONE='' SUBZ=''
				until [[ $ZONE && $SUBZ ]]; do
					dlg ZONE menu "Timezone" "$_timez" America - Australia - Asia - Atlantic - Africa - Europe - Indian - Pacific - Arctic - Antarctica - || break
					dlg SUBZ menu "Timezone" "$_timesubz" $(awk '/'"$ZONE"'\// {gsub(/'"$ZONE"'\//, ""); print $3 " - "}' /usr/share/zoneinfo/zone.tab | sort) || continue
				done
				[[ $ZONE && $SUBZ ]] || { i=2; continue; } ;;
			4) dlg KERNEL menu "Kernel" "\nChoose which kernel to use." \
					linux          'Vanilla linux kernel and modules, with a few patches applied' \
					linux-lts      'Long-term support (LTS) linux kernel and modules' \
					linux-zen      'A effort of kernel hackers to provide the best kernel for everyday systems' \
					linux-hardened 'A security-focused linux kernel with hardening patches to mitigate exploits' || { i=3; continue; }
				CONFIG_DONE=true
				;;
		esac
		(( i++ )) # progress through to the next choice
	done

	case $MYSHELL in
		bash) LOGINRC='.bash_profile' ;;
		zsh) LOGINRC='.zprofile' ;;
		mksh) LOGINRC='.profile' ;;
	esac

	return 0
}

select_mkuser()
{
	NEWUSER=''
	typeset -a ans

	until [[ $NEWUSER ]]; do
		tput cnorm
		dialog --insecure --backtitle "$DIST Installer - $SYS - v$VER" --separator $'\n' --title " User " --mixedform "$_user" 0 0 0 \
			"Username:"  1 1 "${ans[0]}" 1 11 "$COLUMNS" 0 0 \
			"Password:"  2 1 ''          2 11 "$COLUMNS" 0 1 \
			"Password2:" 3 1 ''          3 12 "$COLUMNS" 0 1 \
			"--- Root password, if left empty the user password will be used ---" 6 1 '' 6 68 "$COLUMNS" 0 2 \
			"Password:"  8 1 ''          8 11 "$COLUMNS" 0 1 \
			"Password2:" 9 1 ''          9 12 "$COLUMNS" 0 1 2>"$ANS" || return 1

		mapfile -t ans <"$ANS"

		# root passwords empty, so use the user passwords
		if [[ -z "${ans[4]}" && -z "${ans[5]}" ]]; then
			ans[4]="${ans[1]}"
			ans[5]="${ans[2]}"
		fi

		# make sure a username was entered and that the passwords match
		if [[ -z ${ans[0]} || ${ans[0]} =~ \ |\' || ${ans[0]} =~ [^a-z0-9] ]]; then
			msg "Invalid Username" "\nInvalid user name.\n\nPlease try again.\n"; u=''
		elif [[ -z "${ans[1]}" || "${ans[1]}" != "${ans[2]}" ]]; then
			msg "Password Mismatch" "\nThe user passwords do not match.\n\nPlease try again.\n"
		elif [[ "${ans[4]}" != "${ans[5]}" ]]; then
			msg "Password Mismatch" "\nThe root passwords do not match.\n\nPlease try again.\n"
		else
			NEWUSER="${ans[0]}"
			USER_PASS="${ans[1]}"
			ROOT_PASS="${ans[4]}"
		fi
	done
	return 0
}

select_keymap()
{
	dlg KEYMAP menu "Keyboard Layout" "$_keymap" \
		us English    cm    English     gb English    au English    gh English \
		za English    ng    English     ca French    'cd' French    gn French \
		tg French     fr    French      de German     at German     ch German \
		es Spanish    latam Spanish     br Portuguese pt Portuguese ma Arabic \
		sy Arabic     ara   Arabic      ua Ukrainian  cz Czech      ru Russian \
		sk Slovak     nl    Dutch       it Italian    hu Hungarian  cn Chinese \
		tw Taiwanese  vn    Vietnamese  kr Korean     jp Japanese   th Thai \
		la Lao        pl    Polish      se Swedish    is Icelandic 'fi' Finnish \
		dk Danish     be    Belgian     in Indian     al Albanian   am Armenian \
		bd Bangla     ba    Bosnian    'bg' Bulgarian dz Berber     mm Burmese \
		hr Croatian   gr    Greek       il Hebrew     ir Persian    iq Iraqi \
		af Afghani    fo    Faroese     ge Georgian   ee Estonian   kg Kyrgyz \
		kz Kazakh     lt    Lithuanian  mt Maltese    mn Mongolian  ro Romanian \
		no Norwegian  rs    Serbian     si Slovenian  tj Tajik      lk Sinhala \
		tr Turkish    uz    Uzbek       ie Irish      pk Urdu      'mv' Dhivehi \
		np Nepali     et    Amharic     sn Wolof      ml Bambara    tz Swahili \
		ke Swahili    bw    Tswana      ph Filipino   my Malay      tm Turkmen \
		id Indonesian bt    Dzongkha    lv Latvian    md Moldavian mao Maori \
		by Belarusian az    Azerbaijani mk Macedonian kh Khmer     epo Esperanto \
		me Montenegrin || return 1

	if [[ $CMAPS == *"$KEYMAP"* ]]; then
		CMAP="$KEYMAP"
	else
		dlg CMAP menu "Console Keymap" "$_vconsole" $CMAPS || return 1
	fi

	if [[ $TERM == 'linux' ]]; then
		loadkeys "$CMAP" >/dev/null 2>&1
	else
		setxkbmap "$KEYMAP" >/dev/null 2>&1
	fi

	return 0
}

select_sessions()
{
	LOGIN_CHOICES=''
	dlg INSTALL_WMS check "Sessions" "$_sessions\n" \
		openbox "A lightweight, powerful, and highly configurable stacking wm" "$(ofn openbox "${INSTALL_WMS[*]}")" \
		i3-gaps "A fork of i3wm with more features including gaps" "$(ofn i3-gaps "${INSTALL_WMS[*]}")" \
		dwm "A dynamic WM for X that manages windows in tiled, floating, or monocle layouts" "$(ofn dwm "${INSTALL_WMS[*]}")" \
		bspwm "A tiling wm that represents windows as the leaves of a binary tree" "$(ofn bspwm "${INSTALL_WMS[*]}")" \
		xfce4 "A lightweight and modular desktop environment based on gtk+2/3" "$(ofn xfce4 "${INSTALL_WMS[*]}")" \
		awesome "A customized Awesome WM session created by @elanapan" "$(ofn awesome "${INSTALL_WMS[*]}")" \
		fluxbox "A lightweight and highly-configurable window manager" "$(ofn fluxbox "${INSTALL_WMS[*]}")" \
		plasma "A kde software project currently comprising a full desktop environment" "$(ofn plasma "${INSTALL_WMS[*]}")" \
		gnome "A desktop environment that aims to be simple and easy to use" "$(ofn gnome "${INSTALL_WMS[*]}")" \
		cinnamon "A desktop environment combining traditional desktop with modern effects" "$(ofn cinnamon "${INSTALL_WMS[*]}")"

	[[ $INSTALL_WMS ]] || return 0

	WM_PKGS="${INSTALL_WMS/dwm/}" # remove dwm from package list
	WM_PKGS="${WM_PKGS//  / }"    # remove double spaces
	WM_PKGS="${WM_PKGS# }"        # remove leading space

	for i in $INSTALL_WMS; do
		LOGIN_CHOICES+="$i - "
		[[ ${WM_EXT[$i]} && $WM_PKGS != *"${WM_EXT[$i]}"* ]] && WM_PKGS+=" ${WM_EXT[$i]}"
	done

	select_login || return 1

	while IFS=' ' read -r pkg; do
		[[ $PACKAGES != *"$pkg"* ]] && PACKAGES+=" $pkg"
	done <<< "$WM_PKGS"

	return 0
}

select_packages()
{
	dlg USER_PKGS check " Packages " "$_packages" \
		abiword "A Fully-featured word processor" "$(ofn abiword "${USER_PKGS[*]}")" \
		alacritty "A cross-platform, GPU-accelerated terminal emulator" "$(ofn alacritty "${USER_PKGS[*]}")" \
		atom "An open-source text editor developed by GitHub" "$(ofn atom "${USER_PKGS[*]}")" \
		audacious "A free and advanced audio player based on GTK+" "$(ofn audacious "${USER_PKGS[*]}")" \
		audacity "A program that lets you manipulate digital audio waveforms" "$(ofn audacity "${USER_PKGS[*]}")" \
		blueman "GUI bluetooth device manager" "$(ofn blueman "${USER_PKGS[*]}")" \
		bluez "Simple CLI based bluetooth support" "$(ofn bluez "${USER_PKGS[*]}")" \
		cairo-dock "Light eye-candy fully themable animated dock" "$(ofn cairo-dock "${USER_PKGS[*]}")" \
		calligra "A set of applications for productivity" "$(ofn calligra "${USER_PKGS[*]}")" \
		chromium "An open-source web browser based on the Blink rendering engine" "$(ofn chromium "${USER_PKGS[*]}")" \
		clementine "A modern music player and library organizer" "$(ofn clementine "${USER_PKGS[*]}")" \
		cmus "A small, fast and powerful console music player" "$(ofn cmus "${USER_PKGS[*]}")" \
		deadbeef "A GTK+ audio player for GNU/Linux" "$(ofn deadbeef "${USER_PKGS[*]}")" \
		deluge "A BitTorrent client written in python" "$(ofn deluge "${USER_PKGS[*]}")" \
		emacs "An extensible, customizable, self-documenting real-time display editor" "$(ofn emacs "${USER_PKGS[*]}")" \
		epiphany "A GNOME web browser based on the WebKit rendering engine" "$(ofn epiphany "${USER_PKGS[*]}")" \
		evince "A document viewer" "$(ofn evince "${USER_PKGS[*]}")" \
		evolution "Manage your email, contacts and schedule" "$(ofn evolution "${USER_PKGS[*]}")" \
		file-roller "Create and modify archives" "$(ofn file-roller "${USER_PKGS[*]}")" \
		firefox "A popular open-source web browser from Mozilla" "$(ofn firefox "${USER_PKGS[*]}")" \
		gcolor2 "A simple GTK+2 color selector" "$(ofn gcolor2 "${USER_PKGS[*]}")" \
		geany "A fast and lightweight IDE" "$(ofn geany "${USER_PKGS[*]}")" \
		geary "A lightweight email client for the GNOME desktop" "$(ofn geary "${USER_PKGS[*]}")" \
		gimp "GNU Image Manipulation Program" "$(ofn gimp "${USER_PKGS[*]}")" \
		gnome-calculator "GNOME Scientific calculator" "$(ofn gnome-calculator "${USER_PKGS[*]}")" \
		gnome-disk-utility "Disk Management Utility" "$(ofn gnome-disk-utility "${USER_PKGS[*]}")" \
		gnome-system-monitor "View current processes and monitor system state" "$(ofn gnome-system-monitor "${USER_PKGS[*]}")" \
		gparted "A GUI frontend for creating and manipulating partition tables" "$(ofn gparted "${USER_PKGS[*]}")" \
		gpick "Advanced color picker using GTK+ toolkit" "$(ofn gpick "${USER_PKGS[*]}")" \
		gpicview "Lightweight image viewer" "$(ofn gpicview "${USER_PKGS[*]}")" \
		guvcview "Capture video from camera devices" "$(ofn guvcview "${USER_PKGS[*]}")" \
		hexchat "A popular and easy to use graphical IRC client" "$(ofn hexchat "${USER_PKGS[*]}")" \
		inkscape "Professional vector graphics editor" "$(ofn inkscape "${USER_PKGS[*]}")" \
		irssi "Modular text mode IRC client" "$(ofn irssi "${USER_PKGS[*]}")" \
		kdenlive "A popular non-linear video editor for Linux" "$(ofn kdenlive "${USER_PKGS[*]}")" \
		krita "Edit and paint images" "$(ofn krita "${USER_PKGS[*]}")" \
		libreoffice-fresh "Full featured office suite" "$(ofn libreoffice-fresh "${USER_PKGS[*]}")" \
		lollypop "A new music playing application" "$(ofn lollypop "${USER_PKGS[*]}")" \
		mousepad "A simple text editor" "$(ofn mousepad "${USER_PKGS[*]}")" \
		mpd "A flexible, powerful, server-side application for playing music" "$(ofn mpd "${USER_PKGS[*]}")" \
		mpv "A media player based on mplayer" "$(ofn mpv "${USER_PKGS[*]}")" \
		mupdf "Lightweight PDF and XPS viewer" "$(ofn mupdf "${USER_PKGS[*]}")" \
		mutt "Small but very powerful text-based mail client" "$(ofn mutt "${USER_PKGS[*]}")" \
		nautilus "The default file manager for Gnome" "$(ofn nautilus "${USER_PKGS[*]}")" \
		ncmpcpp "A mpd client and almost exact clone of ncmpc with some new features" "$(ofn ncmpcpp "${USER_PKGS[*]}")" \
		neovim "A fork of Vim aiming to improve user experience, plugins, and GUIs." "$(ofn neovim "${USER_PKGS[*]}")" \
		noto-fonts "Google Noto fonts" "$(ofn noto-fonts "${USER_PKGS[*]}")" \
		noto-fonts-cjk "Google Noto CJK fonts (Chinese, Japanese, Korean)" "$(ofn noto-fonts-cjk "${USER_PKGS[*]}")" \
		obs-studio "Free opensource streaming/recording software" "$(ofn obs-studio "${USER_PKGS[*]}")" \
		openshot "An open-source, non-linear video editor for Linux" "$(ofn openshot "${USER_PKGS[*]}")" \
		opera "A Fast and secure, free of charge web browser from Opera Software" "$(ofn opera "${USER_PKGS[*]}")" \
		pcmanfm "A fast and lightweight file manager based in Lxde" "$(ofn pcmanfm "${USER_PKGS[*]}")" \
		pidgin "Multi-protocol instant messaging client" "$(ofn pidgin "${USER_PKGS[*]}")" \
		plank "An elegant, simple, and clean dock" "$(ofn plank "${USER_PKGS[*]}")" \
		qbittorrent "An advanced BitTorrent client" "$(ofn qbittorrent "${USER_PKGS[*]}")" \
		qpdfview "A tabbed PDF viewer" "$(ofn qpdfview "${USER_PKGS[*]}")" \
		qt5ct "GUI for managing Qt based application themes, icons, and fonts" "$(ofn qt5ct "${USER_PKGS[*]}")" \
		qutebrowser "A keyboard-focused vim-like web browser based on Python and PyQt5" "$(ofn qutebrowser "${USER_PKGS[*]}")" \
		rhythmbox "A Music playback and management application" "$(ofn rhythmbox "${USER_PKGS[*]}")" \
		rxvt-unicode "A unicode enabled rxvt-clone terminal emulator" "$(ofn rxvt-unicode "${USER_PKGS[*]}")" \
		sakura "A terminal emulator based on GTK and VTE" "$(ofn sakura "${USER_PKGS[*]}")" \
		simple-scan "Simple scanning utility" "$(ofn simple-scan "${USER_PKGS[*]}")" \
		simplescreenrecorder "A feature-rich screen recorder" "$(ofn simplescreenrecorder "${USER_PKGS[*]}")" \
		steam "A popular game distribution platform by Valve" "$(ofn steam "${USER_PKGS[*]}")" \
		surf "A simple web browser based on WebKit2/GTK+" "$(ofn surf "${USER_PKGS[*]}")" \
		terminator "Terminal emulator that supports tabs and grids" "$(ofn terminator "${USER_PKGS[*]}")" \
		termite "A minimal VTE-based terminal emulator" "$(ofn termite "${USER_PKGS[*]}")" \
		thunar "A modern file manager for the Xfce Desktop Environment" "$(ofn thunar "${USER_PKGS[*]}")" \
		thunderbird "Standalone mail and news reader from mozilla" "$(ofn thunderbird "${USER_PKGS[*]}")" \
		tilda "A GTK based drop down terminal for Linux and Unix" "$(ofn tilda "${USER_PKGS[*]}")" \
		tilix "A tiling terminal emulator for Linux using GTK+ 3" "$(ofn tilix "${USER_PKGS[*]}")" \
		transmission-cli "Free BitTorrent client CLI" "$(ofn transmission-cli "${USER_PKGS[*]}")" \
		transmission-gtk "GTK+ Front end for transmission" "$(ofn transmission-gtk "${USER_PKGS[*]}")" \
		transmission-qt "Qt Front end for transmission" "$(ofn transmission-qt "${USER_PKGS[*]}")" \
		ttf-anonymous-pro "A family fixed-width fonts designed with code in mind" "$(ofn ttf-anonymous-pro "${USER_PKGS[*]}")" \
		ttf-fira-code "Monospaced font with programming ligatures" "$(ofn ttf-fira-code "${USER_PKGS[*]}")" \
		ttf-font-awesome "Iconic font designed for Bootstrap" "$(ofn ttf-font-awesome "${USER_PKGS[*]}")" \
		ttf-hack "A hand groomed typeface based on Bitstream Vera Mono" "$(ofn ttf-hack "${USER_PKGS[*]}")" \
		vlc "A free and open source cross-platform multimedia player" "$(ofn vlc "${USER_PKGS[*]}")" \
		weechat "Fast, light and extensible IRC client" "$(ofn weechat "${USER_PKGS[*]}")" \
		xapps "Common library for X-Apps project" "$(ofn xapps "${USER_PKGS[*]}")" \
		xarchiver "A GTK+ frontend to various command line archivers" "$(ofn xarchiver "${USER_PKGS[*]}")" \
		xed "A small and lightweight text editor. X-Apps Project." "$(ofn xed "${USER_PKGS[*]}")" \
		xfce4-terminal "A terminal emulator based in the Xfce Desktop Environment" "$(ofn xfce4-terminal "${USER_PKGS[*]}")" \
		xreader "Document viewer for files like PDF and Postscript. X-Apps Project." "$(ofn xed "${USER_PKGS[*]}")" \
		xterm "The standard terminal emulator for the X window system" "$(ofn xterm "${USER_PKGS[*]}")" \
		zathura "Minimalistic document viewer" "$(ofn zathura "${USER_PKGS[*]}")"

	if [[ $USER_PKGS ]]; then    # add any needed PKG_EXT to the list
		for i in $USER_PKGS; do
			[[ ${PKG_EXT[$i]} && $USER_PKGS != *"${PKG_EXT[$i]}"* ]] && USER_PKGS+=" ${PKG_EXT[$i]}"
		done
	fi

	return 0
}

###############################################################################
# partitioning menus
# non-essential partitioning helpers called by the user when using the optional
# partition menu and selecting a device to edit

part_menu()
{
	no_bg_install || return 0
	local device choice devhash
	devhash="$(lsblk -f | base64)"
	umount_dir $MNT
	part_device || return 1
	device="$DEVICE"

	while :; do
		choice=""
		dlg choice menu "Edit Partitions" "$_part\n\n$(lsblk -no NAME,MODEL,SIZE,TYPE,FSTYPE $device)" \
			"auto"   "Whole device automatic partitioning" \
			"shrink" "Shrink an existing ext or ntfs partition" \
			"cfdisk" "Curses based variant of fdisk" \
			"parted" "GNU partition editor" \
			"fdisk"  "Dialog-driven creation and manipulation of partitions" \
			"done"   "Return to the main menu"

		if [[ -z $choice || $choice == 'done' ]]; then
			return 0
		elif [[ $choice == 'shrink' ]]; then
			part_shrink "$device"
		elif [[ $choice == 'auto' ]]; then
			local root_size txt table boot_fs
			root_size=$(lsblk -lno SIZE "$device" | awk 'NR == 1 {
				if ($1 ~ "G") {
					sub(/G/, "")
					print ($1 * 1000 - 512) / 1000 "G"
				} else {
					sub(/M/, "")
					print ($1 - 512) "M"
				}
			}')
			txt="\nWARNING:\n\nALL data on $device will be destroyed and the following partitions will be created\n\n- "
			if [[ $SYS == 'BIOS' ]]; then
				table="msdos" boot_fs="ext4"
				txt+="An $boot_fs boot partition with the boot flag enabled (512M)\n- "
			else
				table="gpt" boot_fs="fat32"
				txt+="A $boot_fs efi boot partition (512M)\n- "
			fi
			txt+="An ext4 partition using all remaining space ($root_size)\n\nDo you want to continue?\n"
			yesno "Auto Partition" "$txt" && part_auto "$device" "$table" "$boot_fs" "$root_size"
		else
			clear
			tput cnorm
			$choice "$device"
		fi
		if [[ $devhash != "$(lsblk -f | base64)" ]]; then
			msg "Probing Partitions" "\nInforming kernel of partition changes using partprobe\n" 0
			partprobe >/dev/null 2>&1
			[[ $choice == 'auto' ]] && return
		fi
	done
}

part_show()
{
	local txt
	if [[ $IGNORE_DEV ]]; then
		txt="$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINT | awk "!/$IGNORE_DEV/"' && /disk|part|lvm|crypt|NAME/')"
	else
		txt="$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINT | awk '/disk|part|lvm|crypt|NAME/')"
	fi
	msg "Device Tree" "\n\n$txt\n\n"
}

part_auto()
{
	local device="$1" table="$2" boot_fs="$3" size="$4" dev_info=""
	dev_info="$(parted -s "$device" print)"

	msg "Auto Partition" "\nRemoving partitions on $device and setting table to $table\n" 1

	swapoff -a
	while read -r PART; do
		parted -s "$device" rm "$PART" >/dev/null 2>&1
	done <<< "$(awk '/^ [1-9][0-9]?/ {print $1}' <<< "$dev_info" | sort -r)"

	[[ $(awk '/Table:/ {print $3}' <<< "$dev_info") != "$table" ]] && parted -s "$device" mklabel "$table" >/dev/null 2>&1

	msg "Auto Partition" "\nCreating a 512M $boot_fs boot partition.\n" 1
	if [[ $SYS == "BIOS" ]]; then
		parted -s "$device" mkpart primary "$boot_fs" 1MiB 513MiB >/dev/null 2>&1
	else
		parted -s "$device" mkpart ESP "$boot_fs" 1MiB 513MiB >/dev/null 2>&1
	fi

	sleep 0.5
	BOOT_DEV="$device"
	AUTO_BOOT_PART=$(lsblk -lno NAME,TYPE "$device" | awk 'NR==2 {print "/dev/" $1}')

	if [[ $SYS == "BIOS" ]]; then
		mkfs.ext4 -q "$AUTO_BOOT_PART" >/dev/null 2>&1
	else
		mkfs.vfat -F32 "$AUTO_BOOT_PART" >/dev/null 2>&1
	fi

	msg "Auto Partition" "\nCreating a $size ext4 root partition.\n" 0
	parted -s "$device" mkpart primary ext4 513MiB 100% >/dev/null 2>&1
	sleep 0.5
	AUTO_ROOT_PART="$(lsblk -lno NAME,TYPE "$device" | awk 'NR==3 {print "/dev/" $1}')"
	mkfs.ext4 -q "$AUTO_ROOT_PART" >/dev/null 2>&1
	sleep 0.5
	msg "Auto Partition" "\nProcess complete.\n\n$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE "$device")\n"
}

part_shrink()
{
	part=""
	typeset -i size num
	local device="$1" fs=""

	part_find "${device##*/}[^ ]" || return 1
	(( COUNT == 1 )) && part="$(awk '{print $1}' <<< "${PARTS[@]}" )"

	if (( COUNT == 1 )) || dlg part menu "Resize" "\nWhich partition on $device do you want to resize?" $PARTS; then
		fs=$(lsblk -lno FSTYPE "$part")
		case "$fs" in
			ext*|ntfs)
				msg "Resize" "\nGathering device size info.\n" 0
				num="${part: -1}"
				end=$(parted -s "$device" unit KiB print | awk '/^\s*'"$num"'/ {print $3}')                    # part size in KiB
				devsize=$(parted -s "$device" unit KiB print | awk '/Disk '"${device//\//\\/}"':/ {print $3}') # whole device size in KiB
				mount "$part" $MNT >/dev/null 2>&1; sleep 0.5
				min=$(df --output=used --block-size=MiB "$part" | awk 'NR == 2 {print int($1) + 256}')
				max=$(df --output=avail --block-size=MiB "$part" | awk 'NR == 2 {print int($1)}')
				umount_dir $MNT
				tput cnorm
				if dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " Resize: $part " --rangebox "$_resize" 17 "$COLUMNS" "$min" "$max" $((max / 2)) 2>$ANS; then
					size=$(< "$ANS")
					size=$((size * 1024))
				else
					return 1
				fi
				clear
				case "$fs" in
					ntfs)
						if ntfsresize -fc "$part"; then
							ntfsresize -ff --size $(( (size * 1024) / 1000 ))k "$part" 2>$ERR # k=10^3 bytes
							errshow "ntfsresize -f -s $(( (size * 1024) / 1000 ))k $part" || return 1
						else
							msg "Resize" "\nThe ntfs partition $part cannot be resized because it is scheduled for a consistency check.\n\nTo do a consistency check in windows open command prompt as admin and run:\n\n\tchkdsk /f /r /x\n"
							return 1
						fi
						;;
					*)
						e2fsck -f "$part"; sleep 0.5
						resize2fs -f "$part" ${size}K 2>$ERR # K=2^10 bytes
						errshow "resize2fs -f $part ${size}K" || return 1
						;;
				esac
				sleep 0.5
				parted "$device" resizepart "$num" ${size}KiB || return 1
				(( size++ ))
				sleep 0.5
				if [[ $devsize == "$end" ]]; then
					parted -s "$device" mkpart primary ext4 ${size}KiB 100% 2>$ERR
					errshow "parted -s $device mkpart primary ext4 ${size}KiB 100%" || return 1
				else
					parted -s "$device" mkpart primary ext4 ${size}KiB ${end}KiB 2>$ERR
					errshow "parted -s $device mkpart primary ext4 ${size}KiB ${end}KiB" || return 1
				fi
				msg "Resize Complete" "\n$part has been successfully resized to $((size / 1024))M.\n" 1
				;;
			"") msg "No Filesystem" "\nFor unformatted partitions, cfdisk can be used in the partition menu.\n" ;;
			*) msg "Invalid Filesystem: $fs" "\nResizing only supports ext and ntfs.\n" ;;
		esac
	fi
}

###############################################################################
# partition management functions
# these are helpers for use by other functions to do essential setup/teardown

part_find()
{
	local regexp="$1" err=''

	# string of partitions as /TYPE/PART SIZE
	if [[ $IGNORE_DEV ]]; then
		PARTS="$(lsblk -lno TYPE,NAME,SIZE |
			awk "/$regexp/"' && !'"/$IGNORE_DEV/"' {
				sub(/^part/, "/dev/")
				sub(/^lvm|^crypt/, "/dev/mapper/")
				print $1$2, $3
			}')"
	else
		PARTS="$(lsblk -lno TYPE,NAME,SIZE |
			awk "/$regexp/"' {
				sub(/^part/, "/dev/")
				sub(/^lvm|^crypt/, "/dev/mapper/")
				print $1$2 " " $3
			}')"
	fi

	# number of partitions total
	COUNT=0
	while read -r line; do
		(( COUNT++ ))
	done <<< "$PARTS"

	# ensure we have enough partitions for the system and action type
	case "$str" in
		'part|lvm|crypt') [[ $COUNT -lt 1 || ($SYS == 'UEFI' && $COUNT -lt 2) ]] && err="$_errpart" ;;
		'part|crypt') (( COUNT < 1 )) && err="$_lvmerr" ;;
		'part|lvm') (( COUNT < 2 )) && err="$_lukserr" ;;
	esac

	# if there aren't enough partitions show the relevant error message
	[[ $err ]] && { msg "Not Enough Partitions" "$err" 2; return 1; }

	return 0
}

part_swap()
{
	if [[ $1 == "$MNT/swapfile" && $SWAP_SIZE ]]; then
		fallocate -l $SWAP_SIZE "$1" 2>$ERR
		errshow "fallocate -l $SWAP_SIZE $1"
		chmod 600 "$1" 2>$ERR
		errshow "chmod 600 $1"
	fi
	mkswap "$1" >/dev/null 2>$ERR
	errshow "mkswap $1"
	swapon "$1" >/dev/null 2>$ERR
	errshow "swapon $1"
	return 0
}

part_mount()
{
	local part="$1" mountp="${MNT}$2" fs=""
	fs="$(lsblk -lno FSTYPE "$part")"
	mkdir -p "$mountp"

	if [[ $fs && ${FS_OPTS[$fs]} && $part != "$BOOT_PART" && $part != "$AUTO_ROOT_PART" ]] && select_mntopts "$fs"; then
		mount -o "$MNT_OPTS" "$part" "$mountp" >/dev/null 2>&1
	else
		mount "$part" "$mountp" >/dev/null 2>&1
	fi

	part_mountconf "$part" "$mountp" || return 1
	part_cryptlv "$part"

	return 0
}

part_format()
{
	local part="$1" fs="$2" delay="$3"

	msg "Format" "\nFormatting $part as $fs\n" 0
	mkfs.$fs ${FS_CMD_FLAGS[$fs]} "$part" >/dev/null 2>$ERR
	errshow "mkfs.$fs ${FS_CMD_FLAGS[$fs]} "$part"" || return 1
	FORMATTED+="$part "
	sleep "${delay:-0}"
}

part_device()
{
	if [[ $DEV_COUNT -eq 1 && $SYS_DEVS ]]; then
		DEVICE="$(awk '{print $1}' <<< "$SYS_DEVS")"
	elif (( DEV_COUNT > 1 )); then
		if [[ $1 ]]; then
			dlg DEVICE menu "Boot Device" "\nSelect the device to use for bootloader install." $SYS_DEVS
		else
			dlg DEVICE menu "Select Device" "$_device" $SYS_DEVS
		fi
		[[ $DEVICE ]] || return 1
	elif [[ $DEV_COUNT -lt 1 && ! $1 ]]; then
		msg "Device Error" "\nNo available devices.\n\nExiting..\n" 2
		die 1
	fi

	[[ $1 ]] && BOOT_DEV="$DEVICE"

	return 0
}

part_bootdev()
{
	BOOT_DEV="${BOOT_PART%[1-9]}"
	BOOT_PART_NUM="${BOOT_PART: -1}"
	[[ $BOOT_PART = /dev/nvme* ]] && BOOT_DEV="${BOOT_PART%p[1-9]}"
	if [[ $SYS == 'UEFI' ]]; then
		parted -s $BOOT_DEV set $BOOT_PART_NUM esp on >/dev/null 2>&1
	else
		parted -s $BOOT_DEV set $BOOT_PART_NUM boot on >/dev/null 2>&1
	fi
	return 0
}

part_cryptlv()
{
	local part="$1" devs=""
	devs="$(lsblk -lno NAME,FSTYPE,TYPE)"

	# Identify if $part is LUKS+LVM, LVM+LUKS, LVM alone, or LUKS alone
	if lsblk -lno TYPE "$part" | grep -q 'crypt'; then
		LUKS='encrypted'
		LUKS_NAME="${part#/dev/mapper/}"
		for dev in $(awk '/lvm/ && /crypto_LUKS/ {print "/dev/mapper/"$1}' <<< "$devs" | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$LUKS_NAME"; then
				LUKS_DEV="$LUKS_DEV cryptdevice=$dev:$LUKS_NAME"
				LVM='logical volume'
				break
			fi
		done
		for dev in $(awk '/part/ && /crypto_LUKS/ {print "/dev/"$1}' <<< "$devs" | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$LUKS_NAME"; then
				LUKS_UUID="$(lsblk -lno UUID,TYPE,FSTYPE "$dev" | awk '/part/ && /crypto_LUKS/ {print $1}')"
				LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
				break
			fi
		done
	elif lsblk -lno TYPE "$part" | grep -q 'lvm'; then
		LVM='logical volume'
		VNAME="${part#/dev/mapper/}"
		for dev in $(awk '/crypt/ && /lvm2_member/ {print "/dev/mapper/"$1}' <<< "$devs" | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$VNAME"; then
				LUKS_NAME="${dev/\/dev\/mapper\//}"
				break
			fi
		done
		for dev in $(awk '/part/ && /crypto_LUKS/ {print "/dev/"$1}' <<< "$devs" | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$LUKS_NAME"; then
				LUKS_UUID="$(lsblk -lno UUID,TYPE,FSTYPE "$dev" | awk '/part/ && /crypto_LUKS/ {print $1}')"
				LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
				LUKS='encrypted'
				break
			fi
		done
	fi
}

part_countdec()
{
	for pt; do
		if (( COUNT > 0 )); then
			PARTS="$(sed "/${pt//\//\\/}/d" <<< "$PARTS")"
			(( COUNT-- ))
		fi
	done
}

part_mountconf()
{
	if grep -qw "$1" /proc/mounts; then
		msg "Mount Success" "\nPartition $1 mounted at $2\n" 1
		part_countdec "$1"
		return 0
	else
		msg "Mount Fail" "\nPartition $1 failed to mount at $2\n" 2
		return 1
	fi
}

###############################################################################
# mounting menus
# mount_menu is the entry point which calls all other functions
# once finished it returns to the main menu: main()

mount_menu()
{
	msg "Info" "\nGathering device info.\n" 0
	no_bg_install || return 0
	lvm_detect
	umount_dir $MNT
	part_find 'part|lvm|crypt' || { SEL=2; return 1; }

	[[ $LUKS && $LUKS_PART ]] && part_countdec $LUKS_PART
	[[ $LVM && $LVM_PARTS ]] && part_countdec $LVM_PARTS

	select_root_partition || return 1

	if [[ $SYS == 'UEFI' ]]; then
		select_efi_partition || { BOOT_PART=''; return 1; }
	elif (( COUNT > 0 )); then
		select_boot_partition || { BOOT_PART=''; return 1; }
	fi

	if [[ $BOOT_PART ]]; then
		part_mount "$BOOT_PART" "/$BOOTDIR" && SEP_BOOT=true || return 1
		part_bootdev
	fi

	select_swap || return 1
	select_extra_partitions || return 1
	install_background

	return 0
}

select_swap()
{
	dlg SWAP_PART menu "Swap Setup" "\nSelect whether to use a swapfile, swap partition, or none." \
		"none" "Don't allocate any swap space" \
		"swapfile" "Allocate $SYS_MEM at /swapfile" \
		$PARTS

	if [[ -z $SWAP_PART || $SWAP_PART == "none" ]]; then
		SWAP_PART=''
		return 0
	elif [[ $SWAP_PART == "swapfile" ]]; then
		local i=0
		until [[ ${SWAP_SIZE:0:1} =~ [1-9] && ${SWAP_SIZE: -1} =~ (M|G) ]]; do
			(( i > 0 )) && msg "Swap Size Error" "\nSwap size must be 1(M|G) or greater, and can only contain whole numbers\n\nSize entered: $SWAP_SIZE\n" 2
			dlg SWAP_SIZE input "Swap Setup" "$_swapsize" "$SYS_MEM" || { SWAP_PART=''; SWAP_SIZE=''; return 1; }
			(( i++ ))
		done
		part_swap "$MNT/$SWAP_PART"
		SWAP_PART="/$SWAP_PART"
	elif [[ $PARTS == *"$SWAP_PART"* ]]; then
		part_swap $SWAP_PART
		part_countdec $SWAP_PART
		SWAP_SIZE="$(lsblk -lno SIZE $SWAP_PART)"
	else
		return 1
	fi

	return 0
}

select_mntopts()
{
	local fs="$1" opts=''
	local title="${fs^} Mount Options"

	for i in ${FS_OPTS[$fs]}; do
		opts+="$i - off "
	done

	until [[ $MNT_OPTS ]]; do
		dlg MNT_OPTS check "$title" "$_mount" $opts
		[[ $MNT_OPTS ]] || return 1
		MNT_OPTS="${MNT_OPTS// /,}"
		yesno "$title" "\nConfirm the following options: $MNT_OPTS\n" || MNT_OPTS=''
	done

	return 0
}

select_mountpoint()
{
	EXMNT=''
	until [[ $EXMNT ]]; do
		dlg EXMNT input "Extra Mount $part" "$_exmnt" "/" || return 1
		if [[ ${EXMNT:0:1} != "/" || ${#EXMNT} -le 1 || $EXMNT =~ \ |\' || $EXMNTS == *"$EXMNT"* ]]; then
			msg "Mountpoint Error" "$_errexpart"
			EXMNT=''
		fi
	done
	return 0
}

select_filesystem()
{
	local part="$1" fs='' cur=''
	local txt="\nSelect which filesystem to use for: $part\n\nDefault:  ext4"
	cur="$(lsblk -lno FSTYPE "$part" 2>/dev/null)"

	# bail early if the partition was created in part_auto()
	[[ $cur && $part == "$AUTO_ROOT_PART" ]] && return 0

	until [[ $fs ]]; do
		if [[ $cur && $FORMATTED == *"$part"* ]]; then
			dlg fs menu "Filesystem" "$txt\nCurrent:  $cur" skip - ext4 - ext3 - ext2 - vfat - ntfs - f2fs - jfs - xfs - nilfs2 - reiserfs - || return 1
		else
			dlg fs menu "Filesystem" "$txt" ext4 - ext3 - ext2 - vfat - ntfs - f2fs - jfs - xfs - nilfs2 - reiserfs - || return 1
		fi
		[[ $fs == 'skip' ]] && return 0
		yesno "Filesystem" "\nFormat $part as $fs?\n" || fs=''
	done
	part_format "$part" "$fs"
}

select_efi_partition()
{
	if [[ $AUTO_BOOT_PART ]]; then
		BOOT_PART="$AUTO_BOOT_PART"
		return 0 # were done here
	else
		local pts size dev isize bsize ptcount=0

		# walk partition list and skip ones that are too small/big for boot
		while read -r dev size; do
			size_t="${size: -1:1}"  # size type eg. K, M, G, T
			isize=${size:0:-1}      # remove trailing size type character
			isize=${isize%.*}       # remove any decimal (round down)
			[[ $size_t =~ [KT] || ($size_t == 'G' && $isize -gt 2) || ($size_t == 'M' && $isize -lt 100) ]] || { pts+="$dev $size "; (( ptcount++ )); }
		done <<< "$PARTS"

		if (( ptcount == 1 )); then
			msg "EFI Boot Partition" "\nOnly one partition available that meets size requirements.\n" 1
			BOOT_PART="$(awk 'NF > 0 {print $1}' <<< "$pts")"
		else
			dlg BOOT_PART menu "EFI Partition" "$_uefi" $pts
		fi
	fi

	if [[ -z $BOOT_PART ]]; then
		return 1
	elif grep -q 'fat' <<< "$(fsck -N "$BOOT_PART")"; then
		local txt="\nIMPORTANT:\n\nThe EFI partition $BOOT_PART $_format"
		if yesno "Format EFI Partition" "$txt" "Format $BOOT_PART" "Skip Formatting" 1; then
			part_format "$BOOT_PART" "vfat" 2
		fi
	else
		part_format "$BOOT_PART" "vfat" 2
	fi

	return 0
}

select_boot_partition()
{
	if [[ $AUTO_BOOT_PART && ! $LVM ]]; then
		BOOT_PART="$AUTO_BOOT_PART"
		return 0 # were done here
	else
		local pts size dev isize bsize ptcount=0

		# walk partition list and skip ones that are too small/big for boot
		while read -r dev size; do
			size_t="${size: -1:1}"  # size type eg. K, M, G, T
			isize=${size:0:-1}      # remove trailing size type character
			isize=${isize%.*}       # remove any decimal (round down)
			[[ $size_t =~ [KT] || ($size_t == 'G' && $isize -gt 2) || ($size_t == 'M' && $isize -lt 100) ]] || { pts+="$dev $size "; (( ptcount++ )); }
		done <<< "$PARTS"

		if [[ $LUKS && ! $LVM ]]; then
			dlg BOOT_PART menu "Boot Partition" "$_biosluks" $pts
			[[ $BOOT_PART ]] || return 1
		else
			dlg BOOT_PART menu "Boot Partition" "$_bios" "skip" "don't use a separate boot" $pts
			[[ -z $BOOT_PART || $BOOT_PART == "skip" ]] && { BOOT_PART=''; return 0; }
		fi
	fi

	if grep -q 'ext[34]' <<< "$(fsck -N "$BOOT_PART")"; then
		local txt="\nIMPORTANT:\n\nThe boot partition $BOOT_PART $_format"
		if yesno "Format Boot Partition" "$txt" "Format $BOOT_PART" "Skip Formatting" 1; then
			part_format "$BOOT_PART" "ext4" 2
		fi
	else
		part_format "$BOOT_PART" "ext4" 2
	fi
	return 0
}

select_root_partition()
{
	if [[ $AUTO_ROOT_PART && -z $LVM && -z $LUKS ]]; then
		ROOT_PART="$AUTO_ROOT_PART"
		msg "Mount Menu" "\nUsing partitions created during automatic format.\n" 2
		part_mount "$ROOT_PART" || { ROOT_PART=''; return 1; }
		return 0  # we're done here
	else
		local pts size dev isize bsize ptcount=0

		# walk partition list and skip ones that are too small for / (root)
		while read -r dev size; do
			size_t="${size: -1:1}"  # size type eg. K, M, G, T
			isize=${size:0:-1}      # remove trailing size type character
			isize=${isize%.*}       # remove any decimal (round down)
			[[ $size_t =~ [MK] || ($size_t == 'G' && $isize -lt 4) ]] || { pts+="$dev $size "; (( ptcount++ )); }
		done <<< "$PARTS"

		if (( ptcount == 1 )); then  # only one available device
			msg "Root Partition (/)" "\nOnly one partition available that meets size requirements.\n" 2
			ROOT_PART="$(awk 'NF > 0 {print $1}' <<< "$pts")"
		else
			dlg ROOT_PART menu "Mount Root" "\nSelect the root (/) partition, this is where $DIST will be installed.\n\nDevices smaller than 8G will not be shown here." $pts
		fi
	fi

	if [[ -z $ROOT_PART ]] || ! select_filesystem "$ROOT_PART" || ! part_mount "$ROOT_PART"; then
		ROOT_PART=''
		return 1
	fi

	return 0
}

select_extra_partitions()
{
	local part size dev

	# walk partition list and skip ones that are too small to be usable
	while read -r dev size; do
		[[ ${size: -1:1} =~ [KM] ]] && part_countdec "$dev"
	done <<< "$PARTS"

	while (( COUNT > 0 )); do
		part=''
		dlg part menu 'Mount Extra' "$_expart" 'done' 'finish mounting step' $PARTS || break
		if [[ $part == 'done' ]]; then
			break
		elif select_filesystem "$part" && select_mountpoint && part_mount "$part" "$EXMNT"; then
			EXMNTS+="$part: $EXMNT "
			[[ $EXMNT == '/usr' && $HOOKS != *usr* ]] && HOOKS="usr $HOOKS"
		else
			return 1
		fi
	done
	return 0
}

###############################################################################
# installation
# main is the entry point which calls all other install functions, once
# complete it shows a dialog to edit files on the new system before reboot

install_main()
{
	install_base
	genfstab -U $MNT >$MNT/etc/fstab 2>$ERR
	errshow 1 "genfstab -U $MNT >$MNT/etc/fstab"
	[[ -f $MNT/swapfile ]] && sed -i "s~${MNT}~~" $MNT/etc/fstab
	install_packages
	install_mkinitcpio
	install_boot
	chrun "hwclock --systohc --utc" || chrun "hwclock --systohc --utc --directisa"
	install_user
	install_login
	chrun "chown -Rf $NEWUSER:users /home/$NEWUSER"

	while :; do
		dlg choice menu "Finalization" "$_edit" \
			finished   "exit the installer and reboot" \
			keyboard   "${EDIT_FILES[keyboard]}" \
			console    "${EDIT_FILES[console]}" \
			locale     "${EDIT_FILES[locale]}" \
			hostname   "${EDIT_FILES[hostname]}" \
			sudoers    "${EDIT_FILES[sudoers]}" \
			mkinitcpio "${EDIT_FILES[mkinitcpio]}" \
			fstab      "${EDIT_FILES[fstab]}" \
			crypttab   "${EDIT_FILES[crypttab]}" \
			bootloader "${EDIT_FILES[bootloader]}" \
			pacman     "${EDIT_FILES[pacman]}" \
			login      "${EDIT_FILES[login]}"

		if [[ -z $choice || $choice == 'finished' ]]; then
			[[ $DEBUG == true && -r $DBG ]] && $EDITOR $DBG
			clear && die 127
		else
			local exists=''
			for f in ${EDIT_FILES[$choice]}; do
				[[ -e ${MNT}$f ]] && exists+=" ${MNT}$f"
			done
			if [[ $exists ]]; then
				$EDITOR -O $exists
			else
				msg "File Missing" "\nThe file(s) selected do not exist:\n\n${EDIT_FILES[$choice]}\n"
			fi
		fi
	done
}

install_base()
{
	clear
	tput cnorm
	while kill -0 $BG_PID 2>/dev/null; do
		clear; printf "\nA background install process is still running...\n"; sleep 1
	done
	trap - EXIT
	unset BG_PID

	rm -rf $MNT/etc/mkinitcpio-archiso.conf
	find $MNT/usr/lib/initcpio -name 'archiso*' -type f -delete
	sed -i 's/#\(Storage=\)volatile/\1auto/' $MNT/etc/systemd/journald.conf
	find $MNT/boot -name '*-ucode.img' -delete

	[[ $DIST != "ArchLabs" ]] || sed -i "s/ArchLabs/$DIST/g" $MNT/etc/{lsb-release,os-release}

	if [[ $VM ]]; then
		find $MNT/etc/X11/xorg.conf.d/ -name '*.conf' -delete
	elif lspci | grep ' VGA ' | grep -q 'Intel'; then
		echo "Creating Intel VGA Tear Free config /etc/X11/xorg.conf.d/20-intel.conf"
		cat > $MNT/etc/X11/xorg.conf.d/20-intel.conf <<- EOF
		Section "Device"
		    Identifier  "Intel Graphics"
		    Driver      "intel"
		    Option      "TearFree" "true"
		EndSection
		EOF
	fi

	[[ -e /run/archiso/sfs/airootfs && $KERNEL == 'linux' ]] && cp -vf $RUN/x86_64/vmlinuz $MNT/boot/vmlinuz-linux
	[[ -d /etc/netctl ]] && cp -rfv /etc/netctl $MNT/etc/
	[[ -f /etc/resolv.conf ]] && cp -fv /etc/resolv.conf $MNT/etc/
	[[ -e /etc/NetworkManager/system-connections ]] && cp -rvf /etc/NetworkManager/system-connections $MNT/etc/NetworkManager/

	echo "LANG=$MYLOCALE" > $MNT/etc/locale.conf
	cp -fv $MNT/etc/locale.conf $MNT/etc/default/locale
	sed -i "s/#en_US.UTF-8/en_US.UTF-8/g; s/#${MYLOCALE}/${MYLOCALE}/g" $MNT/etc/locale.gen
	chrun "locale-gen"
	chrun "ln -svf /usr/share/zoneinfo/$ZONE/$SUBZ /etc/localtime"

	cat > $MNT/etc/X11/xorg.conf.d/00-keyboard.conf <<- EOF
	# Use localectl(1) to instruct systemd-localed to update it.
	Section "InputClass"
	    Identifier      "system-keyboard"
	    MatchIsKeyboard "on"
	    Option          "XkbLayout" "$KEYMAP"
	EndSection
	EOF

	cat > $MNT/etc/default/keyboard <<- EOF
	# KEYBOARD CONFIGURATION FILE
	# Consult the keyboard(5) manual page.
	XKBMODEL=""
	XKBLAYOUT="$KEYMAP"
	XKBVARIANT=""
	XKBOPTIONS=""
	BACKSPACE="guess"
	EOF
	printf "KEYMAP=%s\nFONT=%s\n" "$CMAP" "$FONT" > $MNT/etc/vconsole.conf
	echo "$MYHOST" > $MNT/etc/hostname
	cat > $MNT/etc/hosts <<- EOF
	127.0.0.1	localhost
	127.0.1.1	$MYHOST
	::1			localhost ip6-localhost ip6-loopback
	ff02::1		ip6-allnodes
	ff02::2		ip6-allrouters
	EOF
}

install_boot()
{
	echo "Installing $BOOTLDR"

	if [[ $ROOT_PART == /dev/mapper* ]]; then
		ROOT_PART_ID="$ROOT_PART"
	else
		local uuid_type="UUID"
		[[ $BOOTLDR =~ (systemd-boot|refind-efi|efistub) ]] && uuid_type="PARTUUID"
		ROOT_PART_ID="$uuid_type=$(blkid -s $uuid_type -o value $ROOT_PART)"
	fi

	if [[ $SYS == 'UEFI' ]]; then
		# remove our old install and generic BOOT/ dir
		find $MNT/$BOOTDIR/EFI/ -maxdepth 1 -mindepth 1 -iname "$DIST" -type d -delete
		find $MNT/$BOOTDIR/EFI/ -maxdepth 1 -mindepth 1 -iname 'BOOT' -type d -delete
	fi

	prerun_$BOOTLDR
	chrun "${BCMDS[$BOOTLDR]}" 2>$ERR
	errshow 1 "${BCMDS[$BOOTLDR]}"

	if [[ -d $MNT/hostrun ]]; then
		# cleanup the bind mounts we made earlier for the grub-probe module
		umount_dir $MNT/hostrun/{udev,lvm}
		rm -rf $MNT/hostrun >/dev/null 2>&1
	fi

	if [[ $SYS == 'UEFI' ]]; then
		# some UEFI firmware requires a generic esp/BOOT/BOOTX64.EFI
		mkdir -pv $MNT/$BOOTDIR/EFI/BOOT
		case "$BOOTLDR" in
			grub) cp -fv $MNT/$BOOTDIR/EFI/$DIST/grubx64.efi $MNT/$BOOTDIR/EFI/BOOT/BOOTX64.EFI ;;
			syslinux) cp -rf "$MNT/$BOOTDIR/EFI/syslinux/"* $MNT/$BOOTDIR/EFI/BOOT/ && cp -f $MNT/$BOOTDIR/EFI/syslinux/syslinux.efi $MNT/$BOOTDIR/EFI/BOOT/BOOTX64.EFI ;;
			refind-efi) sed -i '/#extra_kernel_version_strings/ c extra_kernel_version_strings linux-hardened,linux-zen,linux-lts,linux' $MNT/$BOOTDIR/EFI/refind/refind.conf
				cp -fv $MNT/$BOOTDIR/EFI/refind/refind_x64.efi $MNT/$BOOTDIR/EFI/BOOT/BOOTX64.EFI ;;
		esac
	fi

	return 0
}

install_user()
{
	rm -f $MNT/root/.zshrc  # remove welcome message from root zshrc

	chrun "chpasswd <<< 'root:$ROOT_PASS'" 2>$ERR
	errshow 1 "set root password"
	if [[ $MYSHELL != 'zsh' ]]; then # root uses zsh by default
		chrun "usermod -s /bin/$MYSHELL root" 2>$ERR
		errshow 1 "usermod -s /bin/$MYSHELL root"
		# copy the default mkshrc to /root if it was selected
		[[ $MYSHELL == 'mksh' ]] && cp -fv $MNT/etc/skel/.mkshrc $MNT/root/.mkshrc
	fi

	echo "Creating new user $NEWUSER and setting password"
	local groups='audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel'

	chrun "useradd -m -u 1000 -g users -G $groups -s /bin/$MYSHELL $NEWUSER" 2>$ERR
	errshow 1 "useradd -m -u 1000 -g users -G $groups -s /bin/$MYSHELL $NEWUSER"
	chrun "chpasswd <<< '$NEWUSER:$USER_PASS'" 2>$ERR
	errshow 1 "set $NEWUSER password"

	if [[ $INSTALL_WMS == *dwm* ]];then
		mkdir -pv "$MNT/home/$NEWUSER/suckless"
		for i in dwm dmenu st; do
			if chrun "git clone https://git.suckless.org/$i /home/$NEWUSER/suckless/$i"; then
				chrun "cd /home/$NEWUSER/suckless/$i; make prefix=/usr install; make clean"
			else
				printf "failed to clone %s repo\n" "$i"
			fi
		done
	fi

	[[ $MYSHELL != 'bash' ]] && rm -rf "$MNT/home/$NEWUSER/.bash"*

	# remove some commands from ~/.xprofile when using KDE or Gnome as the login session
	if [[ $LOGIN_WM =~ (startkde|gnome-session) || ($LOGIN_TYPE != 'xinit' && $WM_PKGS =~ (plasma|gnome)) ]]; then
		sed -i '/super/d; /nitrogen/d; /compton/d' "$MNT/home/$NEWUSER/.xprofile" "$MNT/root/.xprofile"
	elif [[ $INSTALL_WMS == 'dwm' ]]; then # and dwm
		sed -i '/super/d; /compton/d' "$MNT/home/$NEWUSER/.xprofile" "$MNT/root/.xprofile"
	fi

	# create user home directories (Music, Documents, Downloads, etc..)
	chrun 'xdg-user-dirs-update'

	return 0
}

install_login()
{
	local serv="$MNT/etc/systemd/system/getty@tty1.service.d"
	echo "Setting up $LOGIN_TYPE"
	case $LOGIN_TYPE in
		ly|sddm|gdm|lightdm)
			rm -rf "$serv" "$MNT/home/$NEWUSER/.xinitrc"
			chrun "systemctl enable $LOGIN_TYPE.service" 2>$ERR
			errshow 1 "systemctl enable $LOGIN_TYPE.service"
			${LOGIN_TYPE}_config
			;;
		xinit)
			if [[ $INSTALL_WMS ]]; then
				sed -i "/exec/ c exec ${LOGIN_WM}" "$MNT/home/$NEWUSER/.xinitrc"
			elif [[ -e $MNT/home/$NEWUSER/.xinitrc ]]; then
				sed -i '/exec/d' "$MNT/home/$NEWUSER/.xinitrc"
				return 0
			fi
			if [[ $AUTOLOGIN ]]; then
				sed -i "s/root/${NEWUSER}/g" $serv/autologin.conf
				cat > "$MNT/home/$NEWUSER/$LOGINRC" <<- EOF
				# automatically run startx when logging in on tty1
				[ -z "\$DISPLAY" ] && [ \$XDG_VTNR -eq 1 ] && startx
				EOF
			else
				rm -rf $serv
			fi
			;;
	esac
}

install_packages()
{
	local rmpkg="archlabs-installer "
	local inpkg="$PACKAGES $USER_PKGS "

	if [[ $MYSHELL == 'zsh' ]]; then
		inpkg+="zsh-completions "
	else
		rmpkg+="zsh "
	fi

	[[ $KERNEL != 'linux' ]] && rmpkg+='linux '

	if [[ $INSTALL_WMS == 'dwm' ]]; then
		inpkg+="nitrogen polkit-gnome xclip gnome-keyring dunst feh "
	else
		[[ $INSTALL_WMS =~ ^(plasma|gnome|cinnamon)$ ]] || inpkg+="archlabs-ksuperkey "
		[[ $INSTALL_WMS =~ (openbox|bspwm|i3-gaps|fluxbox) ]] && inpkg+="$WM_BASE_PKGS "
		[[ $inpkg =~ (term|gnome|xfce|plasma|cinnamon|rxvt|tilda|tilix|sakura) ]] || inpkg+="xterm "
	fi

	# update and install crucial packages first to avoid issues
	chrun "pacman -Syyu $KERNEL $BASE_PKGS ${LOGIN_PKGS[$LOGIN_TYPE]} $MYSHELL --noconfirm --needed" 2>$ERR
	errshow 1 "pacman -Syyu $KERNEL $BASE_PKGS ${LOGIN_PKGS[$LOGIN_TYPE]} $MYSHELL --noconfirm --needed"

	# remove the packages we don't want on the installed system
	chrun "pacman -Rnsc $rmpkg --noconfirm"

	# reinstalling iputils fixes the network issue for non-root users
	chrun "pacman -S iputils $UCODE --noconfirm"

	# install the packages chosen throughout the install
	chrun "pacman -S $inpkg --needed --noconfirm" 2>$ERR
	errshow 1 "pacman -S $inpkg --needed --noconfirm"

	# bootloader packages
	if [[ $BOOTLDR == 'grub' ]]; then
		[[ $SYS == 'UEFI' ]] && local efib="efibootmgr"
		chrun "pacman -S os-prober grub $efib --needed --noconfirm" 2>$ERR
		errshow 1 "pacman -S os-prober grub $efib --needed --noconfirm"
	elif [[ $BOOTLDR == 'refind-efi' ]]; then
		chrun "pacman -S refind-efi efibootmgr --needed --noconfirm" 2>$ERR
		errshow 1 "pacman -S refind-efi efibootmgr --needed --noconfirm"
	elif [[ $SYS == 'UEFI' ]]; then
		chrun "pacman -S efibootmgr --needed --noconfirm" 2>$ERR
		errshow 1 "pacman -S efibootmgr --needed --noconfirm"
	fi

	# allow members of the wheel group to run commands as root
	sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" $MNT/etc/sudoers

	return 0
}

install_mkinitcpio()
{
	local add=''
	[[ $LUKS ]] && add="encrypt"
	[[ $LVM ]] && { [[ $add ]] && add+=" lvm2" || add+="lvm2"; }
	sed -i "s/block filesystems/block ${add} filesystems ${HOOKS}/g" $MNT/etc/mkinitcpio.conf
	chrun "mkinitcpio -p $KERNEL" 2>$ERR
	errshow 1 "mkinitcpio -p $KERNEL"
}

install_mirrorlist()
{
	if hash reflector >/dev/null 2>&1; then
		reflector --verbose --score 80 -l 40 -f 5 --sort rate --save "$1"
	elif hash rankmirrors >/dev/null 2>&1; then
		echo "Sorting mirrorlist"
		local key="access_key=5f29642060ab983b31fdf4c2935d8c56"
		ip_add="$(curl -fsSL "http://api.ipstack.com/check&?$key&fields=ip" | python -c "import sys, json; print(json.load(sys.stdin)['ip'])")"
		country="$(curl -fsSL "http://api.ipstack.com/$ip_add?$key&fields=country_code" | python -c "import sys, json; print(json.load(sys.stdin)['country_code'])")"
		if [[ "$country" ]]; then
			if [[ $country =~ (CA|US) ]]; then
				# use both CA and US mirrors for CA or US countries
				mirror="https://www.archlinux.org/mirrorlist/?country=US&country=CA&use_mirror_status=on"
			elif [[ $country =~ (AU|NZ) ]]; then
				# use both AU and NZ mirrors for AU or NZ countries
				mirror="https://www.archlinux.org/mirrorlist/?country=AU&country=NZ&use_mirror_status=on"
			else
				mirror="https://www.archlinux.org/mirrorlist/?country=${country}&use_mirror_status=on"
			fi
		else # no country code so just grab all mirrors, will be a very slow sort but we don't have other options
			mirror="https://www.archlinux.org/mirrorlist/?country=all&use_mirror_status=on"
		fi
		curl -fsSL "$mirror" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - >"$1"
	fi

	return 0
}

install_background()
{
	( rsync -a /run/archiso/sfs/airootfs/ $MNT/ && install_mirrorlist "$MNT/etc/pacman.d/mirrorlist" >/dev/null 2>&1 ) &
	BG_PID=$!
	trap "kill $BG_PID 2>/dev/null" EXIT
}

###############################################################################
# display manager config
# these are called based on which DM is chosen after it is installed
# additional config can be  handled here, for now only lightdm has one

lightdm_config()
{
	cat > $MNT/etc/lightdm/lightdm-gtk-greeter.conf <<- EOF
	[greeter]
	default-user-image=/usr/share/icons/ArchLabs-Dark/64x64/places/distributor-logo-archlabs.png
	background=/usr/share/backgrounds/archlabs/archlabs.jpg
	theme-name=Adwaita-dark
	icon-theme-name=Adwaita
	font-name=DejaVu Sans Mono 11
	position=30%,end 50%,end
	EOF
}

ly_config()
{
	:
}

gdm_config()
{
	:
}

sddm_config()
{
	:
}

###############################################################################
# bootloader setup
# prerun_* set up the configs needed before actually running the commands
# setup_* are run after selecting a bootloader and build the command used later
# they can also be used for further user input as these run before control is taken away

setup_grub()
{
	EDIT_FILES[bootloader]="/etc/default/grub"

	if [[ $SYS == 'BIOS' ]]; then
		[[ $BOOT_DEV ]] || { part_device 1 || return 1; }
		BCMDS[grub]="grub-install --recheck --force --target=i386-pc $BOOT_DEV"
	else
		BCMDS[grub]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1
		grub-install --recheck --force --target=x86_64-efi --efi-directory=/$BOOTDIR --bootloader-id=$DIST"
		grep -q /sys/firmware/efi/efivars /proc/mounts || mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1
	fi

	BCMDS[grub]="mkdir -p /run/udev /run/lvm &&
		mount --bind /hostrun/udev /run/udev &&
		mount --bind /hostrun/lvm /run/lvm &&
		${BCMDS[grub]} &&
		grub-mkconfig -o /boot/grub/grub.cfg &&
		sleep 1 && umount /run/udev /run/lvm"

	return 0
}

prerun_grub()
{
	sed -i "s/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"${DIST}\"/g; s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/g" $MNT/etc/default/grub

	if [[ $LUKS_DEV ]]; then
		sed -i "s~#GRUB_ENABLE_CRYPTODISK~GRUB_ENABLE_CRYPTODISK~g; s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"${LUKS_DEV}\"~g" $MNT/etc/default/grub 2>$ERR
		errshow 1 "sed -i 's~#GRUB_ENABLE_CRYPTODISK~GRUB_ENABLE_CRYPTODISK~g; s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"${LUKS_DEV}\"~g' $MNT/etc/default/grub"
	fi

	if [[ $SYS == 'BIOS' && $LVM && -z $SEP_BOOT ]]; then
		sed -i "s/GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"lvm\"/g" $MNT/etc/default/grub 2>$ERR
		errshow 1 "sed -i 's/GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"lvm\"/g' $MNT/etc/default/grub"
	fi

	# setup for os-prober module
	mkdir -p /run/{lvm,udev} $MNT/hostrun/{lvm,udev}
	mount --bind /run/lvm $MNT/hostrun/lvm
	mount --bind /run/udev $MNT/hostrun/udev

	return 0
}

setup_efistub()
{
	EDIT_FILES[bootloader]=""
}

prerun_efistub()
{
	BCMDS[systemd-boot]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1
		efibootmgr -v -d $BOOT_DEV -p $BOOT_PART_NUM -c -L '${DIST} Linux' -l /vmlinuz-${KERNEL} \
		-u 'root=$ROOT_PART_ID rw $([[ $UCODE ]] && printf 'initrd=\%s.img ' "$UCODE")initrd=\initramfs-${KERNEL}.img'"
}

setup_syslinux()
{
	if [[ $SYS == 'BIOS' ]]; then
		EDIT_FILES[bootloader]="/boot/syslinux/syslinux.cfg"
	else
		EDIT_FILES[bootloader]="/boot/EFI/syslinux/syslinux.cfg"
		BCMDS[syslinux]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1
		efibootmgr -v -c -d $BOOT_DEV -p $BOOT_PART_NUM -l /EFI/syslinux/syslinux.efi -L $DIST"
	fi
}

prerun_syslinux()
{
	local c="$MNT/boot/syslinux" s="/usr/lib/syslinux/bios" d=".."
	[[ $SYS == 'UEFI' ]] && { c="$MNT/boot/EFI/syslinux"; s="/usr/lib/syslinux/efi64"; d=''; }

	mkdir -pv "$c"
	cp -rfv "$s/"* "$c/"
	cat > "$c/syslinux.cfg" <<- EOF
	UI menu.c32
	PROMPT 0
	MENU TITLE $DIST Boot Menu
	TIMEOUT 50
	DEFAULT $DIST

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
	EOF
	return 0
}

setup_refind-efi()
{
	EDIT_FILES[bootloader]="/boot/refind_linux.conf"
	BCMDS[refind-efi]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1; refind-install"
}

prerun_refind-efi()
{
	cat > $MNT/boot/refind_linux.conf <<- EOF
	"$DIST Linux"          "root=$ROOT_PART_ID $([[ $LUKS_DEV ]] &&
						printf "%s " "$LUKS_DEV")rw add_efi_memmap $([[ $UCODE ]] &&
						printf "initrd=%s " "/$UCODE.img")initrd=/initramfs-$KERNEL.img"
	"$DIST Linux Fallback" "root=$ROOT_PART_ID $([[ $LUKS_DEV ]] &&
						printf "%s " "$LUKS_DEV")rw add_efi_memmap $([[ $UCODE ]] &&
						printf "initrd=%s " "/$UCODE.img")initrd=/initramfs-$KERNEL-fallback.img"
	EOF
	mkdir -p $MNT/etc/pacman.d/hooks
	cat > $MNT/etc/pacman.d/hooks/refind.hook <<- EOF
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

setup_systemd-boot()
{
	EDIT_FILES[bootloader]="/boot/loader/entries/$DIST.conf"
	BCMDS[systemd-boot]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1; bootctl --path=/boot install"
}

prerun_systemd-boot()
{
	mkdir -p $MNT/boot/loader/entries
	cat > $MNT/boot/loader/loader.conf <<- EOF
	default  $DIST
	timeout  5
	editor   no
	EOF
	cat > $MNT/boot/loader/entries/$DIST.conf <<- EOF
	title   $DIST Linux
	linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/$UCODE.img")
	initrd  /initramfs-$KERNEL.img
	options root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
	EOF
	cat > $MNT/boot/loader/entries/$DIST-fallback.conf <<- EOF
	title   $DIST Linux Fallback
	linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/$UCODE.img")
	initrd  /initramfs-$KERNEL-fallback.img
	options root=$ROOT_PART_ID $([[ $LUKS_DEV ]] && printf "%s " "$LUKS_DEV")rw
	EOF
	mkdir -p $MNT/etc/pacman.d/hooks
	cat > $MNT/etc/pacman.d/hooks/systemd-boot.hook <<- EOF
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
	msg "Info" "\nGathering device info.\n" 0
	no_bg_install || return 1
	lvm_detect
	local choice
	while :; do
		dlg choice menu "Logical Volume Management" "$_lvmmenu" \
			"$_lvmnew"    "vgcreate -f, lvcreate -L -n" \
			"$_lvmdel"    "vgremove -f" \
			"$_lvmdelall" "lvrmeove, vgremove, pvremove -f" \
			"Back"        "Return to the main menu"
		case "$choice" in
			"$_lvmnew") lvm_create && break ;;
			"$_lvmdel") lvm_delgroup && yesno "$_lvmdel" "$_lvmdelask" && vgremove -f "$DEL_VG" >/dev/null 2>&1 ;;
			"$_lvmdelall") lvm_del_all ;;
			*) break ;;
		esac
	done

	return 0
}

lvm_detect()
{
	local v pv
	pv="$(pvs -o pv_name --noheading 2>/dev/null)"
	v="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"
	VGROUP="$(vgs -o vg_name --noheading 2>/dev/null)"

	if [[ $VGROUP && $v && $pv ]]; then
		msg "LVM Setup" "\nActivating existing logical volume management.\n" 0
		modprobe dm-mod >/dev/null 2>$ERR
		errshow 'modprobe dm-mod'
		vgscan >/dev/null 2>&1
		vgchange -ay >/dev/null 2>&1
	fi
}

lvm_create()
{
	VGROUP='' LVM_PARTS='' VGROUP_MB=0
	umount_dir $MNT
	lvm_mkgroup || return 1
	local txt="\nThe last (or only) logical volume will automatically use all remaining space in the volume group."
	dlg VOL_COUNT menu "$_lvmnew" "\nSelect the number of logical volumes (LVs) to create in: $VGROUP\n$txt" 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 -
	[[ $VOL_COUNT ]] || return 1
	lvm_extra_lvs || return 1
	lvm_volume_name "$_lvmlvname\nNOTE: This LV will use up all remaining space in the volume group (${VGROUP_MB}MB)" || return 1
	msg "$_lvmnew (LV:$VOL_COUNT)" "\nCreating volume $VNAME from remaining space in $VGROUP\n" 0
	lvcreate -l +100%FREE "$VGROUP" -n "$VNAME" >/dev/null 2>$ERR
	errshow "lvcreate -l +100%FREE $VGROUP -n $VNAME" || return 1
	LVM='logical volume'; sleep 0.5
	txt="\nDone, volume: $VGROUP-$VNAME (${VOLUME_SIZE:-${VGROUP_MB}MB}) has been created.\n"
	msg "$_lvmnew (LV:$VOL_COUNT)" "$txt\n$(lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE $LVM_PARTS)\n"
	return 0
}

lvm_lv_size()
{
	local txt="${VGROUP}: ${SIZE}$SIZE_UNIT (${VGROUP_MB}MB remaining).$_lvmlvsize"

	while :; do
		ERR_SIZE=0
		dlg VOLUME_SIZE input "$_lvmnew (LV:$VOL_COUNT)" "$txt" ''
		if [[ -z $VOLUME_SIZE ]]; then
			ERR_SIZE=1
			break # allow bailing with escape or an empty choice
		elif (( ${VOLUME_SIZE:0:1} == 0 )); then
			ERR_SIZE=1 # size values can't begin with '0'
		else
			# walk the string and make sure all but the last char are digits
			local lv=$((${#VOLUME_SIZE} - 1))
			for (( i=0; i<lv; i++ )); do
				[[ ${VOLUME_SIZE:$i:1} =~ [0-9] ]] || { ERR_SIZE=1; break; }
			done
			if (( ERR_SIZE != 1 )); then
				case ${VOLUME_SIZE:$lv:1} in
					[mMgG]) local s=${VOLUME_SIZE:0:$lv} m=$((s * 1000))
						case ${VOLUME_SIZE:$lv:1} in
							[Gg]) (( m >= VGROUP_MB )) && ERR_SIZE=1 || VGROUP_MB=$((VGROUP_MB - m)) ;;
							[Mm]) (( ${VOLUME_SIZE:0:$lv} >= VGROUP_MB )) && ERR_SIZE=1 || VGROUP_MB=$((VGROUP_MB - s)) ;;
							*) ERR_SIZE=1
						esac ;;
					*) ERR_SIZE=1
				esac
			fi
		fi
		if (( ERR_SIZE )); then
			msg "Invalid Logical Volume Size" "$_lvmerrlvsize"
		else
			break
		fi
	done

	return $ERR_SIZE
}

lvm_mkgroup()
{
	local named=''

	until [[ $named ]]; do
		lvm_partitions || return 1
		lvm_group_name || return 1
		yesno "$_lvmnew" "\nCreate volume group: $VGROUP\n\nusing these partition(s): $LVM_PARTS\n" && named=true
	done

	msg "$_lvmnew" "\nCreating volume group: $VGROUP\n" 0
	vgcreate -f "$VGROUP" $LVM_PARTS >/dev/null 2>$ERR
	errshow "vgcreate -f $VGROUP $LVM_PARTS" || return 1

	SIZE=$(vgdisplay "$VGROUP" | awk '/VG Size/ { gsub(/[^0-9.]/, ""); print int($0) }')
	SIZE_UNIT="$(vgdisplay "$VGROUP" | awk '/VG Size/ { print substr($NF, 0, 1) }')"

	if [[ $SIZE_UNIT == 'G' ]]; then
		VGROUP_MB=$((SIZE * 1000))
	else
		VGROUP_MB=$SIZE
	fi

	msg "$_lvmnew" "\nVolume group $VGROUP (${SIZE}$SIZE_UNIT) successfully created\n"
}

lvm_del_all()
{
	local v pv
	pv="$(pvs -o pv_name --noheading 2>/dev/null)"
	v="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"
	VGROUP="$(vgs -o vg_name --noheading 2>/dev/null)"

	if [[ $VGROUP || $v || $pv ]]; then
		if yesno "$_lvmdelall" "$_lvmdelask"; then
			for i in $v; do lvremove -f "/dev/mapper/$i" >/dev/null 2>&1; done
			for i in $VGROUP; do vgremove -f "$i" >/dev/null 2>&1; done
			for i in $pv; do pvremove -f "$i" >/dev/null 2>&1; done
			LVM=''
		fi
	else
		msg "Delete LVM" "\nNo LVMs to remove...\n" 2
		LVM=''
	fi
}

lvm_delgroup()
{
	DEL_VG=''
	VOL_GROUP_LIST=''

	for i in $(lvs --noheadings | awk '{print $2}' | uniq); do
		VOL_GROUP_LIST+="$i $(vgdisplay "$i" | awk '/VG Size/ {print $3$4}') "
	done

	[[ $VOL_GROUP_LIST ]] || { msg "No Groups" "\nNo volume groups found."; return 1; }

	dlg DEL_VG menu "Logical Volume Management" "\nSelect volume group to delete.\n\nAll logical volumes within will also be deleted." $VOL_GROUP_LIST
	[[ $DEL_VG ]]
}

lvm_extra_lvs()
{
	while (( VOL_COUNT > 1 )); do
		lvm_volume_name "$_lvmlvname" && lvm_lv_size || return 1
		msg "$_lvmnew (LV:$VOL_COUNT)" "\nCreating a $VOLUME_SIZE volume $VNAME in $VGROUP\n" 0
		lvcreate -L "$VOLUME_SIZE" "$VGROUP" -n "$VNAME" >/dev/null 2>$ERR
		errshow "lvcreate -L $VOLUME_SIZE $VGROUP -n $VNAME" || return 1
		msg "$_lvmnew (LV:$VOL_COUNT)" "\nDone, logical volume (LV) $VNAME ($VOLUME_SIZE) has been created.\n"
		(( VOL_COUNT-- ))
	done
	return 0
}

lvm_partitions()
{
	part_find 'part|crypt' || return 1
	PARTS="$(awk 'NF > 0 {print $0 " off"}' <<< "$PARTS")"
	dlg LVM_PARTS check "$_lvmnew" "\nSelect the partition(s) to use for the physical volume (PV)." $PARTS
	[[ $LVM_PARTS ]]
}

lvm_group_name()
{
	VGROUP=''
	until [[ $VGROUP ]]; do
		dlg VGROUP input "$_lvmnew" "$_lvmvgname" "lvgroup"
		if [[ -z $VGROUP ]]; then
			return 1
		elif [[ ${VGROUP:0:1} == "/" || $VGROUP =~ \ |\' ]] || vgdisplay | grep -q "$VGROUP"; then
			msg "LVM Name Error" "$_lvmerrvgname"
			VGROUP=''
		fi
	done
	return 0
}

lvm_volume_name()
{
	VNAME=''
	local txt="$1" default="mainvolume"
	(( VOL_COUNT > 1 )) && default="extvolume$VOL_COUNT"
	until [[ $VNAME ]]; do
		dlg VNAME input "$_lvmnew (LV:$VOL_COUNT)" "\n$txt" "$default"
		if [[ -z $VNAME ]]; then
			return 1
		elif [[ ${VNAME:0:1} == "/" || $VNAME =~ \ |\' ]] || lsblk | grep -q "$VNAME"; then
			msg "LVM Name Error" "$_lvmerlvname"
			VNAME=''
		fi
	done
	return 0
}

###############################################################################
# luks functions

luks_menu()
{
	local choice
	no_bg_install || return 1
	dlg choice menu "LUKS Encryption" "$_luksmenu" \
		"$_luksnew"  "cryptsetup -q luksFormat" \
		"$_luksopen" "cryptsetup open --type luks" \
		"$_luksadv"  "cryptsetup -q -s -c luksFormat" \
		"Back"       "Return to the main menu"

	case "$choice" in
		"$_luksnew") luks_basic || return 1 ;;
		"$_luksopen") luks_open || return 1 ;;
		"$_luksadv") luks_advanced || return 1 ;;
	esac

	return 0
}

luks_open()
{
	modprobe -a dm-mod dm_crypt >/dev/null 2>&1
	umount_dir $MNT
	part_find 'part|crypt|lvm' || return 1

	if (( COUNT == 1 )); then
		LUKS_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
	else
		dlg LUKS_PART menu "$_luksopen" "\nSelect which partition to open." $PARTS
	fi

	[[ $LUKS_PART ]] || return 1

	luks_pass "$_luksopen" || return 1
	msg "$_luksopen" "\nOpening encrypted partition: $LUKS_NAME\n\nUsing device/volume: $LUKS_PART\n" 0
	cryptsetup open --type luks "$LUKS_PART" "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
	errshow "cryptsetup open --type luks $LUKS_PART $LUKS_NAME" || return 1
	LUKS='encrypted'; luks_show
	return 0
}

luks_pass()
{
	LUKS_PASS=''
	local t="$1"
	typeset -a ans=(cryptroot) # default name to start

	until [[ $LUKS_PASS ]]; do
		tput cnorm
		dialog --insecure --backtitle "$DIST Installer - $SYS - v$VER" --separator $'\n' --title " $t " --mixedform "$_luksomenu" 0 0 0 \
			"Name:"      1 1 "${ans[0]}" 1  7 "$COLUMNS" 0 0 \
			"Password:"  2 1 ''          2 11 "$COLUMNS" 0 1 \
			"Password2:" 3 1 ''          3 12 "$COLUMNS" 0 1 2>"$ANS" || return 1

		mapfile -t ans <"$ANS"

		if [[ -z "${ans[0]}" ]]; then
			msg "Name Empty" "\nEncrypted device name cannot be empty.\n\nPlease try again.\n" 2
		elif [[ -z "${ans[1]}" || "${ans[1]}" != "${ans[2]}" ]]; then
			LUKS_NAME="${ans[0]}"
			msg "Password Mismatch" "\nThe passwords entered do not match.\n\nPlease try again.\n" 2
		else
			LUKS_NAME="${ans[0]}"
			LUKS_PASS="${ans[1]}"
		fi
	done

	return 0
}

luks_show()
{
	sleep 0.5
	msg "$_luksnew" "\nEncrypted partition ready for mounting.\n\n$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE "$LUKS_PART")\n\n"
}

luks_setup()
{
	modprobe -a dm-mod dm_crypt >/dev/null 2>&1
	umount_dir $MNT
	part_find 'part|lvm' || return 1

	if [[ $AUTO_ROOT_PART ]]; then
		LUKS_PART="$AUTO_ROOT_PART"
	elif (( COUNT == 1 )); then
		LUKS_PART="$(awk 'NF > 0 {print $1}' <<< "$PARTS")"
	else
		dlg LUKS_PART menu "$_luksnew" "\nSelect the partition you want to encrypt." $PARTS
	fi

	[[ $LUKS_PART ]] || return 1
	luks_pass "$_luksnew"
}

luks_basic()
{
	luks_setup || return 1
	msg "$_luksnew" "\nCreating encrypted partition: $LUKS_NAME\n\nDevice or volume used: $LUKS_PART\n" 0
	cryptsetup -q luksFormat "$LUKS_PART" <<< "$LUKS_PASS" 2>$ERR
	errshow "cryptsetup -q luksFormat $LUKS_PART" || return 1
	cryptsetup open "$LUKS_PART" "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
	errshow "cryptsetup open $LUKS_PART $LUKS_NAME" || return 1
	LUKS='encrypted'; luks_show
	return 0
}

luks_advanced()
{
	if luks_setup; then
		local cipher
		dlg cipher input "LUKS Encryption" "$_lukskey" "-s 512 -c aes-xts-plain64"
		[[ $cipher ]] || return 1
		msg "$_luksadv" "\nCreating encrypted partition: $LUKS_NAME\n\nDevice or volume used: $LUKS_PART\n" 0
		cryptsetup -q $cipher luksFormat "$LUKS_PART" <<< "$LUKS_PASS" 2>$ERR
		errshow "cryptsetup -q $cipher luksFormat $LUKS_PART" || return 1
		cryptsetup open "$LUKS_PART" "$LUKS_NAME" <<< "$LUKS_PASS" 2>$ERR
		errshow "cryptsetup open $LUKS_PART $LUKS_NAME" || return 1
		luks_show
		return 0
	fi
	return 1
}

###############################################################################
# simple functions
# some help avoid repetition and improve usability of some commands
# others are initial setup functions used before reaching the main loop

ofn()
{
	[[ "$2" == *"$1"* ]] && printf "on" || printf "off"
}

die()
{
	# cleanup and exit the installer cleanly with exit code $1
	local e="$1" # when e is 127 unmount /run/archiso/bootmnt and reboot

	trap - INT
	tput cnorm
	if [[ -d $MNT ]]; then
		umount_dir $MNT
		if (( e == 127 )); then
			umount_dir /run/archiso/bootmnt && sleep 0.5 && reboot -f
		fi
	fi
	exit $e
}

dlg()
{
	local var="$1"   # assign output from dialog to var
	local dlg_t="$2" # dialog type (menu, check, input)
	local title="$3" # dialog title
	local body="$4"  # dialog message
	local n=0        # number of items to display for menu and check dialogs

	shift 4  # shift off args assigned above

	# adjust n when passed a large list
	local l=$((LINES - 20))
	(( ($# / 2) > l )) && n=$l

	tput civis
	case "$dlg_t" in
		menu) dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " $title " --menu "$body" 0 0 $n "$@" 2>"$ANS" || return 1 ;;
		check) dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " $title " --checklist "$body" 0 0 $n "$@" 2>"$ANS" || return 1 ;;
		input)
			tput cnorm
			local def="$1" # assign default value for input
			shift
			if [[ $1 == 'limit' ]]; then
				dialog --backtitle "$DIST Installer - $SYS - v$VER" --max-input 63 --title " $title " --inputbox "$body" 0 0 "$def" 2>"$ANS" || return 1
			else
				dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " $title " --inputbox "$body" 0 0 "$def" 2>"$ANS" || return 1
			fi
			;;
	esac
	# if answer file isn't empty read from it into $var
	[[ -s "$ANS" ]] && printf -v "$var" "%s" "$(< "$ANS")"
}

msg()
{
	# displays a message dialog
	# when more than 2 args the message will disappear after sleep time ($3)
	local title="$1"
	local body="$2"
	shift 2
	tput civis
	if (( $# )); then
		dialog --backtitle "$DIST Installer - $SYS - v$VER" --sleep "$1" --title " $title " --infobox "$body\n" 0 0
	else
		dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " $title " --msgbox "$body\n" 0 0
	fi
}

live()
{
	local e=0

	if (( $# == 0 )); then
		msg "No Session" "\nRunning live requires a session to use.\n\nExiting..\n" 2
		clear
		die 1
	if ! select_keymap; then
		clear
		die 0
	elif ! net_connect; then
		msg "Not Connected" "\nRunning live requires an active internet connection.\n\nExiting..\n" 2
		die 1
	else
		clear
		pacman -Syyu --noconfirm || die 1
		pacman -S $WM_BASE_PKGS xorg-xinit xorg-server --needed --noconfirm || die 1
		for ses; do
			case "$ses" in
				dwm)
					pacman -S git --needed --noconfirm || die 1
					mkdir -pv /root/suckless
					for i in dwm dmenu st; do
						git clone https://git.suckless.org/$i /root/suckless/$i && cd /root/suckless/$i && make PREFIX=/usr install
					done
					;;
				i3-gaps|oepnbox|fluxbox|bspwm|xfce4|gnome|plasma|cinnamon|awesome)
					pacman -S "$ses" ${WM_EXT[$ses]} xterm --needed --noconfirm || die 1
					;;
				*) echo "error: invalid session for -l, --live, see -h, --help"; die 1 ;;
			esac
		done
		pacman -Scc --noconfirm
		rm -rf "/var/cache/pacman/pkg/"*
		cp -rfT /etc/skel /root || die 1
		sed -i "/exec/ c exec ${WM_SESSIONS[$ses]}" /root/.xinitrc
#		printf "\n%s has been set as the login session in /root/.xinitrc, to start the session simply run\n\n\tstartx\n\n" "${WM_SESSIONS[$ses]}"
		die 0
	fi
}

usage()
{
	cat <<-EOF
	usage: $1 [-hdl] [session]

	options:
	    -h, --help     print this message and exit
	    -l, --live     install and setup a live session
	    -d, --debug    enable debugging and log output to $DBG

	sessions:
	    i3-gaps  - A fork of i3wm with more features including gaps
	    openbox  - A lightweight, powerful, and highly configurable stacking wm
	    dwm      - A dynamic WM for X that manages windows in tiled, floating, or monocle layouts
	    awesome  - A customized Awesome WM session created by @elanapan
	    bspwm    - A tiling wm that represents windows as the leaves of a binary tree
	    fluxbox  - A lightweight and highly-configurable window manager
	    gnome    - A desktop environment that aims to be simple and easy to use
	    cinnamon - A desktop environment combining traditional desktop with modern effects
	    plasma   - A kde software project currently comprising a full desktop environment
	    xfce4    - A lightweight and modular desktop environment based on gtk+2/3

	EOF
	exit 0
}

yesno()
{
	local title="$1" body="$2" yes='Yes' no='No'
	(( $# >= 3 )) && yes="$3"
	(( $# >= 4 )) && no="$4"
	tput civis
	if (( $# == 5 )); then
		dialog --backtitle "$DIST Installer - $SYS - v$VER" --defaultno --title " $title " --yes-label "$yes" --no-label "$no" --yesno "$body\n" 0 0
	else
		dialog --backtitle "$DIST Installer - $SYS - v$VER" --title " $title " --yes-label "$yes" --no-label "$no" --yesno "$body\n" 0 0
	fi
}

chrun()
{
	arch-chroot "$MNT" bash -c "$1"
}

debug()
{
	export PS4='| ${BASH_SOURCE} LINE:${LINENO} FUNC:${FUNCNAME[0]:+ ${FUNCNAME[0]}()} |>  '
	set -x
	exec 3>| $DBG
	BASH_XTRACEFD=3
	DEBUG=true
}

termcol()
{
	local colors=(
	"\e]P0191919" # #191919
	"\e]P1D15355" # #D15355
	"\e]P2609960" # #609960
	"\e]P3FFCC66" # #FFCC66
	"\e]P4255A9B" # #255A9B
	"\e]P5AF86C8" # #AF86C8
	"\e]P62EC8D3" # #2EC8D3
	"\e]P7949494" # #949494
	"\e]P8191919" # #191919
	"\e]P9D15355" # #D15355
	"\e]PA609960" # #609960
	"\e]PBFF9157" # #FF9157
	"\e]PC4E88CF" # #4E88CF
	"\e]PDAF86C8" # #AF86C8
	"\e]PE2ec8d3" # #2ec8d3
	"\e]PFE1E1E1" # #E1E1E1
	)

	[[ $TERM == 'linux' ]] && printf "%b" "${colors[@]}" && clear
}

errshow()
{
	[ $? -eq 0 ] && return 0

	local fatal=0 err=""
	err="$(sed 's/[^[:print:]]//g; s/\[[0-9\;:]*\?m//g; s/==> //g; s/] ERROR:/]\nERROR:/g' "$ERR")"
	[[ -z $err ]] && err="no error message was found"

	(( $1 == 1 )) && { fatal=1; shift; }

	local txt="\nCommand: $1\n\n\n\nError: $err\n\n"

	if (( fatal )); then
		msg "Install Error" "${txt}Errors at this stage are fatal, the install cannot continue.\n"
		[[ -r $DBG && $TERM == 'linux' ]] && less "$DBG"
		die 1
	fi

	msg "Install Error" "${txt}Errors at this stage are non-fatal and may be fixed or ignored depending on the error.\n"
	return 1
}

prechecks()
{
	local i=1

	if (( $1 >= 0 )) && ! grep -qw "$MNT" /proc/mounts; then
		msg "Not Mounted" "\nPartition(s) must be mounted first.\n" 2
		SEL=4 i=0
	elif [[ $1 -ge 1 && -z $BOOTLDR ]]; then
		msg "No Bootloader" "\nBootloader must be selected first.\n" 2
		SEL=5 i=0
	elif [[ $1 -ge 2 && (-z $NEWUSER || -z $USER_PASS) ]]; then
		msg "No User" "\nA user must be created first.\n" 2
		SEL=6 i=0
	elif [[ $1 -ge 3 && -z $CONFIG_DONE ]]; then
		msg "Not Configured" "\nSystem configuration must be done first.\n" 2
		SEL=7 i=0
	fi
	(( i )) # return code
}

umount_dir()
{
	mount | grep -q 'swap' && swapoff -a
	for dir; do
		if [[ -d $dir ]] && mount | grep -q "on $dir "; then
			if ! umount "$dir" 2>/dev/null; then
				sleep 0.5
				umount -f "$dir" 2>/dev/null || umount -l "$dir"
			fi
		fi
	done
}

chk_connect()
{
	msg "Network Connect" "\nVerifying network connection\n" 0
	curl -sIN --connect-timeout 5 'https://www.archlinux.org/' | sed '1q' | grep -q '200'
}

net_connect()
{
	if chk_connect; then
		return 0
	elif hash nmtui >/dev/null 2>&1; then
		tput civis
		if [[ $TERM == 'linux' ]]; then
			printf "%b" "\e]P1191919" "\e]P4191919"
			nmtui-connect
			printf "%b" "\e]P1D15355" "\e]P4255a9b"
		else
			nmtui-connect
		fi
		chk_connect
	elif hash wifi-menu >dev/null 2>&1; then
		wifi-menu
		chk_connect
	else
		return 1
	fi
}

no_bg_install()
{
	[[ $BG_PID ]] || return 0
	msg "Install Running" "\nA background install process is currently running.\n" 2
	return 1
}

system_devices()
{
	IGNORE_DEV="$(lsblk -lno NAME,MOUNTPOINT | awk '/\/run\/archiso\/bootmnt/ {sub(/[1-9]/, ""); print $1}')"

	if [[ $IGNORE_DEV ]]; then
		SYS_DEVS="$(lsblk -lno NAME,SIZE,TYPE | awk '/disk/ && !'"/$IGNORE_DEV/"' {print "/dev/" $1 " " $2}')"
	else
		SYS_DEVS="$(lsblk -lno NAME,SIZE,TYPE | awk '/disk/ {print "/dev/" $1 " " $2}')"
	fi

	if [[ -z $SYS_DEVS ]]; then
		msg "Device Error" "\nNo available devices...\n\nExiting..\n" 2
		die 1
	fi

	DEV_COUNT=0
	while read -r line; do
		(( DEV_COUNT++ ))
	done <<< "$SYS_DEVS"
}

system_identify()
{
	if [[ $VM ]]; then
		UCODE=''
	# amd-ucode is not needed it's provided by linux-firmware
	# elif grep -q 'AuthenticAMD' /proc/cpuinfo; then
	# 	UCODE="amd-ucode"
	elif grep -q 'GenuineIntel' /proc/cpuinfo; then
		UCODE="intel-ucode"
	fi

	modprobe -q efivarfs >/dev/null 2>&1

	_prep="\nOnce a step is finished a step you will be returned here, if the step was successful the cursor will be advanced to the next step.\nIf a step is unsuccessful the cursor will be placed on the step required to advance (when possible).\n\nTo begin the install you should have:\n\n  - A root (/) partition mounted."
	if [[ -d /sys/firmware/efi/efivars ]]; then
		export SYS="UEFI"
		grep -q /sys/firmware/efi/efivars /proc/mounts || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
		_prep+="\n  - An EFI boot partition mounted."
	else
		export SYS="BIOS"
	fi
	_prep+="\n\nOnce finished mounting, a portion of the install can be done in the background while you continue configuring the system:\n"
	_prep+="\n  - Choose the system bootloader.\n  - Create a user and password."
	_prep+="\n  - Basic system configuration, kernel, shell, login, packages, etc..\n\nOnce you're happy with the choices and the required steps are complete, the main install can be started."
}

###############################################################################
# entry point

# enable some nicer colours in the linux console
termcol

if (( UID != 0 )); then
	msg "Not Root" "\nThis installer must be run as root or using sudo.\n\nExiting..\n" 2
	die 1
elif ! grep -qwm 1 'lm' /proc/cpuinfo; then
	msg "Not x86_64 Architecture" "\nThis installer only supports x86_64 architectures.\n\nExiting..\n" 2
	die 1
else
	case "$1" in
		-d|--debug) debug ;;
		-h|--help) usage "$0" ;;
		-l|--live) shift; live "$@" ;;
	esac
fi

# trap ^C to perform cleanup
trap 'printf "\n^C\n" && die 1' INT

system_identify
system_devices

msg "Welcome to the $DIST Installer" "$_welcome"

if ! select_keymap; then
	clear; die 0
elif ! net_connect; then
	msg "Not Connected" "\nThis installer requires an active internet connection.\n\nExiting..\n" 2
	die 1
fi

FORMATTED=""

while :; do
	main
done
# vim:fdm=marker:fmr={,}
