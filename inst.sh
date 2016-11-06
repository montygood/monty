#!/bin/bash
TOTAL_HDD_SIZE=0
TOTAL_RAM_SIZE=0
SWAP_SIZE=0
ROOT_SIZE=0
HOME_SIZE=0
BOOT_SIZE=200
PID=0
HOSTNAME=''
LANGUAGE=''
KEYMAP=''
ANSWER=''
TIMEZONE=''
ARCH=''
ARCH_ROOT='/mnt'
USERNAME=''
HDD_NAME=''
VERSION=1.0.3
DIALOG_TITLE='ArchFix Install Script Version: '$VERSION

function mainMenu() {
  clear
  echo "               +                                           "
  echo "               A                                           "
  echo "              AAA                                          "
  echo "             AAAAA                                         "
  echo "             AAAAAA                                        "
  echo "            ; AAAAA;                                       "
  echo "           +AA.AAAAA    ArchFix Installation Script        "
  echo "          +AAAAAAAAAA	  The fastest Install script ever! "
  echo "         AAAAAAAAAAAAA;                                    "
  echo "        AAAAAAAAAAAAAAA+     created by MemoryLeakX        "
  echo "       AAAAAAA   AAAAAAA                                   "
  echo "     .AAAAAA;     ;AAA;.A.                                 "
  echo "    .AAAAAAA;     ;AAAAA.                                  "
  echo "    AAAAAAAAA.   .AAAAAAAA.                                "
  echo "   AAAAAA.           ,AAAAAA                               "
  echo "  ;AAAA                 AAAA;                              "
  echo "  AA;                     'AA                              "
  echo " A.                          A;                            "
  echo ""
  message_print 0 "This script comes with no warranty …use at own risk"
  
  echo Press a key...
  read -n 1
  echo
  clear
  
  ANSWER="/tmp/.fc"
  
  dialog --backtitle "$DIALOG_TITLE" \
  --title "Installation Routine" --clear \
  --menu "Please select the installation routine" 20 61 5 \
  "1"  "Base System Installation" \
  "2"  "Install Packages & Configure the System"  2> $ANSWER
  retval=$?
  choice=`cat $ANSWER`
  case $retval in
    0)
      if [ $choice -eq 1 ]
      then
        dolanguage
        dokeymap
        dotimezone
        enter_hostname
        partitioning
        install_base
      else
        load_configs
        optimize_mirrorlist
        install_yaourt
        user_config
        adduser
        install_powerpill
        install_compress_tools
        install_alsa
        install_pulse
        install_bash_goodies
        install_avahi_deamon
        install_ntfs_tools
        install_openssh
        readahead_on
        install_xserver
        install_video_driver
        install_infinality_font_config
        install_cups
        install_xfce
        install_lightdm
        
        #clean package cache
        pacman -Scc --noconfirm
        
        install_plank
        install_archey
        install_libreoffice
        install_gimp
        install_inkscape
        install_firewall
        install_gaming_stuff
        install_extra_gtk_apps
        install_extra_qt_apps
        install_audio_tools_and_codec
        install_video_tools_and_codec
        
        #clean package cache
        pacman -Scc --noconfirm
        
        install_fonts
        install_java
        install_internet_tools
        
        #clean package cache
        pacman -Scc --noconfirm
        resecure_sudoers
        clear
        echo "finished!....."
        sleep 2
        reboot
    fi;;
    1)
    echo "script was canceled!";;
    255)
    echo "script was canceled!";;
  esac
  return 0
}

function message_print() {
  if [ "$1" = 1 ]
  then
    # green
    color="32"
  else
    # red
    color="31"
  fi
  
  printf "\033[0;${color}m**$2**\033[m \n"
  return 0
}

function stop_spinner() {
  kill -s SIGHUP $PID &
  { wait $PID; } &> /dev/null
  PID=0
  return 0
}

function start_spinner() {
  setterm -cursor off
  parts=( "|" "/" "-" "\\" )
  
  while [ 1 ];
  do
    for ix in 0 1 2 3;
    do
      echo -en ${parts[$ix]}
      sleep .1
      echo -en "\b"
    done
  done
  return 0
}

function spinner()  {
  if [ $1 == "start" ];
  then
    if [ $PID -eq 0 ];
    then
      start_spinner&
      PID=$!
    fi
  elif [ $1 == "stop" ];
  then
    if [ $PID -ne 0 ];
    then
      stop_spinner
    fi
  fi
  return 0
}

function add_module() {
  for MODULE in $1; do
    [[ $# -lt 2 ]] && MODULE_NAME="$MODULE" || MODULE_NAME="$2";
    echo "$MODULE" >> /etc/modules-load.d/$MODULE_NAME.conf
    modprobe "$MODULE"
  done
  return 0
}

function add_key() {
  pacman-key -r $1
  pacman-key --lsign-key $1
  return 0
}

function add_repository() {
  REPO=${1}
  URL=${2}
  [[ -n ${3} ]] && SIGLEVEL="\nSigLevel = ${3}" || SIGLEVEL=""
  
  CHECK_REPO=`grep -F "${REPO}" /etc/pacman.conf`
  if [[ -z $CHECK_REPO ]]; then
    echo -e "\n[${REPO}]${SIGLEVEL}\nServer = ${URL}" >> /etc/pacman.conf
    pacman -Syy
  fi
  return 0
}

function replace_line() {
  SEARCH=${1}
  REPLACE=${2}
  FILEPATH=${3}
  FILEBASE=`basename ${3}`
  
  sed -e "s/${SEARCH}/${REPLACE}/" ${FILEPATH} > /tmp/${FILEBASE} 2>"$LOG"
  if [[ ${?} -eq 0 ]]; then
    mv /tmp/${FILEBASE} ${FILEPATH}
  else
    echo "failed: ${SEARCH} - ${FILEPATH}"
  fi
  return 0
}

function dokeymap() {
  clear
  echo "Scanning for keymaps..."
  ANSWER="/tmp/.km"
  KEYMAPS=
  for i in $(localectl list-keymaps --no-pager); do
    KEYMAPS="${KEYMAPS} ${i} -"
  done
  CANCEL=""
  dialog --backtitle "$DIALOG_TITLE" --menu "Select A Keymap" 22 60 16 ${KEYMAPS} 2>${ANSWER} || CANCEL="1"
  if [[ "${CANCEL}" = "1" ]]; then
    S_NEXTITEM="1"
    return 1
  fi
  KEYMAP=$(cat ${ANSWER})
  echo ${KEYMAP} > keymap.config
  return 0
}

function dolanguage() {
  clear
  declare -a COUNTRYCODE
  COUNTRYCODE[0]="en_US"
  COUNTRYCODE[1]="en_GB"
  COUNTRYCODE[2]="fr_FR"
  COUNTRYCODE[3]="es_ES"
  COUNTRYCODE[4]="de_DE"
  
  ANSWER="/tmp/.ln"
  COUNTRIES=
  for i in "${COUNTRYCODE[@]}"; do
    COUNTRIES="${COUNTRIES} ${i} -"
  done
  CANCEL=""
  dialog --backtitle "$DIALOG_TITLE" --menu "Select A Localisation" 22 60 16 ${COUNTRIES} 2>${ANSWER} || CANCEL="1"
  if [[ "${CANCEL}" = "1" ]]; then
    S_NEXTITEM="1"
    return 1
  fi
  LANGUAGE=$(cat ${ANSWER})
  echo ${LANGUAGE} > locale.config
  unset COUNTRYCODE
  return 0
}

function load_configs() {
  KEYMAP=$(<keymap.config)
  TIMEZONE=$(<timezone.config)
  HOSTNAME=$(<hostname.config)
  LANGUAGE=$(<locale.config)
  return 0
}

function dotimezone() {
  clear
  echo "Scanning for timezones..."
  ANSWER="/tmp/.tz"
  TIMEZONES=
  for i in $(timedatectl list-timezones --no-pager); do
    TIMEZONES="${TIMEZONES} ${i} -"
  done
  CANCEL=""
  dialog --backtitle "$DIALOG_TITLE" --menu "Select A TIMEZONE" 22 60 16 ${TIMEZONES} 2>${ANSWER} || CANCEL="1"
  if [[ "${CANCEL}" = "1" ]]; then
    S_NEXTITEM="1"
    return 1
  fi
  TIMEZONE=$(cat ${ANSWER})
  echo ${TIMEZONE} > timezone.config
  return 0
}

function enter_hostname() {
  clear
  HOSTNAME=$(dialog --stdout --clear --backtitle "$DIALOG_TITLE" \
    --title "Enter the hostname of your choice" \
  --inputbox "Please enter the hostname of your machine" 8 60)
  echo ${HOSTNAME} > hostname.config
  clear
}

function get_total_hdd_size() {
  TOTAL_HDD_SIZE=$(fdisk -l $1 |grep "Disk "$1":" | head -n 2 | tail -n 1 | cut -d " " -f 5)
  TOTAL_HDD_SIZE=$(($TOTAL_HDD_SIZE / 1024))
  #HDD SIZE IN MB
  TOTAL_HDD_SIZE=$(($TOTAL_HDD_SIZE / 1024))
  return 0
}

function get_total_ram_size() {
  TOTAL_RAM_SIZE=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  #RAM SIZE IN MB
  TOTAL_RAM_SIZE=$(($TOTAL_RAM_SIZE / 1024))
  return 0
}

function calc_optimal_swap_size() {
  get_total_ram_size
  if [ $TOTAL_RAM_SIZE -lt 513 ]
  then
    SWAP_SIZE=$(($TOTAL_RAM_SIZE * 2))
  else
    SWAP_SIZE=$TOTAL_RAM_SIZE
  fi
  return 0
}

function calc_optimal_patition_size() {
  TOTAL_HDD_SIZE=$(($TOTAL_HDD_SIZE - $BOOT_SIZE - $SWAP_SIZE))
  
  CHECK_VALUE=$(($TOTAL_HDD_SIZE - 35000))
  if [ "$CHECK_VALUE" -gt 0 ]
  then
    ROOT_SIZE=35000
  else
    CHECK_VALUE=$(($TOTAL_HDD_SIZE - 15000))
    if [ "$CHECK_VALUE" -gt 0 ]
    then
      ROOT_SIZE=15000
    else
      CHECK_VALUE=$(($TOTAL_HDD_SIZE - 10000))
      if [ "$CHECK_VALUE" -gt 0 ]
      then
        ROOT_SIZE=10000
      else
        message_print 0 'Error! you have not enough disk space!'
        message_print 0 'You need min. 12 GB diskspace!'
      fi
    fi
  fi
  
  HOME_SIZE=$(($TOTAL_HDD_SIZE - $ROOT_SIZE))
  
  return 0
}

function arch_chroot() {
  arch-chroot $ARCH_ROOT /bin/bash -c "${1}"
  return 0
}

function partitioning() {
  clear
  calc_optimal_swap_size
  
  ANSWER="/tmp/.disk"
  
  disks1="`lsblk -r | grep disk | cut -d" " -f1`"
  disks=""
  
  for i in $disks1; do disks="${disks} /dev/${i} -"; done
  
  dialog --backtitle "$DIALOG_TITLE"  \
  --title "Partitioning" --clear \
  --menu "Select a hard drive to partition." 0 0 0 $disks 2> $ANSWER
  
  retval=$?
  
  choice=`cat $ANSWER`
  case $retval in
    0)
      HDD_NAME=$choice
      get_total_hdd_size $HDD_NAME
      calc_optimal_patition_size
      echo '-----------------------'
      echo 'boot: '$BOOT_SIZE ' MB'
      echo 'root: '$ROOT_SIZE ' MB'
      echo 'home: '$HOME_SIZE ' MB'
      echo ''
      echo 'swap: '$SWAP_SIZE ' MB'
      echo '-----------------------'
      
      #Back to KB Sizes
      BOOT_SIZE=$(($BOOT_SIZE * 1024))
      ROOT_SIZE=$(($ROOT_SIZE * 1024))
      HOME_SIZE=$(($HOME_SIZE * 1024))
      SWAP_SIZE=$(($SWAP_SIZE * 1024))
      
      #Wiping the entire disk
      dd if=/dev/zero of=$HDD_NAME  bs=512  count=1
      
      touch /tmp/fdisk.input
      echo -e "n\np\n1\n\n+"$BOOT_SIZE"K\na\n1\nn\np\n2\n\n+"$SWAP_SIZE"K\nt\n2\n82\nn\np\n3\n\n+"$ROOT_SIZE"K\nn\np\n4\n\n+"$HOME_SIZE"K\nn\np\n5\n\nw" > /tmp/fdisk.input
      
      # Create Partitions
      fdisk $HDD_NAME < /tmp/fdisk.input
      
      # Remove fdisk.input file
      rm /tmp/fdisk.input
      
      mkfs.ext2 -L boot $HDD_NAME'1'
      mkswap -L swap $HDD_NAME'2'
      mkfs.ext4 -L root $HDD_NAME'3'
      mkfs.ext4 -L home $HDD_NAME'4'
      
      #enable swap
      swapon $HDD_NAME'2'
      
      #mount all patitions
      mount $HDD_NAME'3' /mnt
      mkdir /mnt/boot
      mkdir /mnt/home
      mount $HDD_NAME'1' /mnt/boot
    mount $HDD_NAME'4' /mnt/home;;
    1)
    echo "script was canceled!";;
    255)
    echo "script was canceled!";;
  esac
  
  return 0
}

function install_base() {
  clear
  echo "******************************************************"
  echo "***************  Install Base System!  ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  pacstrap /mnt base base-devel
  genfstab -p /mnt > /mnt/etc/fstab
  echo 'tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0' >> /mnt/etc/fstab
  echo $HOSTNAME > /mnt/etc/hostname
  echo 'LANG='$LANGUAGE'.UTF-8' > /mnt/etc/locale.conf
  echo 'LC_COLLATE=C' >> /mnt/etc/locale.conf
  echo 'KEYMAP='$KEYMAP > /mnt/etc/vconsole.conf
  arch_chroot 'ln -s /usr/share/zoneinfo/'$TIMEZONE' /etc/localtime'
  arch_chroot 'rm -rf /etc/locale.gen'
  arch_chroot 'touch /etc/locale.gen'
  echo $LANGUAGE'.UTF-8 UTF-8' > /mnt/etc/locale.gen
  
  #Set locales
  #Steam workaround
  if [ $LANGUAGE = "en_US" ]
  then
    echo "OK!"
  else
    echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
  fi
  
  #create locales
  arch_chroot 'locale-gen'
  
  #Install extra system stuff
  arch_chroot "pacman --noconfirm -S networkmanager sudo wpa_supplicant dialog"
  
  #enable NetworkManager
  arch_chroot 'systemctl enable NetworkManager.service'
  
  #enable mutilib
  MULTILIB=''
  ARCH=$(uname -m)
  if [ $ARCH = "x86_64" ]
  then
    MULTILIB=`grep -n "\[multilib\]" /mnt/etc/pacman.conf | cut -f1 -d:`
    if [ -z $MULTILIB ]
    then
      echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
    else
      sed -i "${MULTILIB}s/^#//" /mnt/etc/pacman.conf
      local MULTILIB=$(( $MULTILIB + 1 ))
      sed -i "${MULTILIB}s/^#//" /mnt/etc/pacman.conf
    fi
  fi
  
  arch_chroot 'pacman -Syy'
  
  #create Linux Kernel
  arch_chroot 'mkinitcpio -p linux'
  
  #configure Clock
  arch_chroot "hwclock --systohc --utc"
  
  #accountsservice Lightdm bugFix
  arch_chroot "pacman --noconfirm -S accountsservice"
  #git
  arch_chroot "pacman --noconfirm -S git"
  
  #Enable Grub
  arch_chroot 'pacman --noconfirm -S grub'
  echo "" >> /mnt/etc/default/grub
  echo "# fix broken grub.cfg gen" >> /mnt/etc/default/grub
  echo "GRUB_DISABLE_SUBMENU=y" >> /mnt/etc/default/grub
  arch_chroot 'grub-install --target=i386-pc --recheck --debug '${HDD_NAME}
  arch_chroot 'grub-mkconfig -o /boot/grub/grub.cfg'
  
  clear
  #SET Root password
  set_user_password "root" 1
  clear

  cd
  cp -r archfix/ /mnt/root/
  
  umount $HDD_NAME'1'
  umount $HDD_NAME'3'
  umount $HDD_NAME'4'
  
  reboot #<< end
  return 0
}

function optimize_mirrorlist() {
  clear
  echo "******************************************************"
  echo "*************** optimizing mirrorlist! ***************"
  echo "******************************************************"
  echo ""
  message_print 0 "******************************************************"
  message_print 0 "*******please wait, this will take a few minutes!*****"
  message_print 0 "******************************************************"
  echo ""
  
  TFILE="/tmp/mirrorlist.tmp"
  CCODE=${LANGUAGE:3:2}
  URL="https://www.archlinux.org/mirrorlist/?country=${CCODE}&use_mirror_status=on"
  
  curl -so ${TFILE} ${URL}
  sed -i 's/^#Server/Server/g' ${TFILE}
  
  echo -n " [working]... "
  spinner "start"
  rankmirrors -n 12 $TFILE > /etc/pacman.d/mirrorlist
  sed -i '/^#/ d' /etc/pacman.d/mirrorlist
  spinner "stop"
  echo "";
  echo "";
  
  pacman -Syy
  return 0
}

function install_yaourt() {
  clear
  echo "******************************************************"
  echo "***************   Installing YAOURT!   ***************"
  echo "******************************************************"
  echo ""
  
  cd /tmp
  echo "Retrieving package-query ..."
  curl -O https://aur.archlinux.org/packages/pa/package-query/package-query.tar.gz
  echo "Retrieving yaourt ..."
  curl -O https://aur.archlinux.org/packages/ya/yaourt/yaourt.tar.gz
  
  echo "Uncompressing package-query ..."
  tar zxvf package-query.tar.gz
  cd package-query
  echo "Installing package-query ..."
  makepkg -si --asroot --noconfirm
  
  cd ..
  
  echo "Uncompressing yaourt ..."
  tar zxvf yaourt.tar.gz
  cd yaourt
  echo "Installing yaourt ..."
  makepkg -si --asroot --noconfirm
  
  cd ..
  
  rm -rf package-query
  rm -rf yaourt
  rm -rf package-query.tar.gz
  rm -rf yaourt.tar.gz
  
  cd
  return 0
}

function install_package() {
  case "$1" in
    "pacman")
      pacman --noconfirm --needed -S ${2}
    ;;
    "yaourt")
      su - ${USERNAME} -c ' yaourt --noconfirm -S '${2}
    ;;
    "powerpill")
      powerpill --noconfirm --needed -S ${2}
    ;;
    *)
      echo ''
    ;;
  esac
  
  return 0
}

function adduser() {
  clear
  USERNAME=$(dialog --stdout --clear --backtitle "$DIALOG_TITLE" \
    --title "Enter your Username" \
  --inputbox "Please enter your Username" 8 60)
  clear
  useradd -m -g users -G audio,lp,network,optical,scanner,storage,sys,video,power,wheel -d /home/$USERNAME -s /bin/bash $USERNAME
  
  set_user_password $USERNAME 0
  
  ## Uncomment to allow members of group wheel to execute any command
  sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /etc/sudoers
  return 0
}

function set_user_password() {
    while true; do
    PASSWORD=$(dialog --stdout --clear --backtitle "$DIALOG_TITLE" --title "Enter the Password for the User: $1" --passwordbox "Enter your password" 10 60)
    clear
    CPASSWORD=$(dialog --stdout --clear --backtitle "$DIALOG_TITLE" --title "Re-enter the Password for the User: $1" --passwordbox "Enter your password" 10 60)
    clear
    if [ "$PASSWORD" == "$CPASSWORD" ]
    then
      if [ $2 -eq 0 ] 
      then
        echo -e "$PASSWORD\n$PASSWORD" | passwd $1
      else
        echo -e "$PASSWORD\n$PASSWORD" | arch_chroot passwd $1
      fi
      break
    else
      message_print 0 "Input was not identical"
      sleep 2
    fi
  done
}

function resecure_sudoers(){
  sed -i "/%wheel ALL=(ALL) NOPASSWD: ALL/s/^\(.*\)/#\1/g"  /etc/sudoers
  sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers
}

function install_powerpill() {
  clear
  echo "******************************************************"
  echo "***************  Installing POWERPILL! ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "yaourt" "powerpill"
  
  echo -n " [updating powerpill]... "
  spinner "start"
  
  reflector -p rsync -f n -l m
  powerpill -Syu
  
  spinner "stop"
  echo ""
  echo ""
  
  return 0
}

function install_compress_tools() {
  clear
  echo "******************************************************"
  echo "*********   Installing Compress Tools! ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "unrar zip p7zip arj unace unzip"
  install_package "yaourt" "file-roller2-nn"
  return 0
}

function install_alsa() {
  clear
  echo "******************************************************"
  echo "*********       Installing Alsa!       ***************"
  echo "******************************************************"
  echo ""
  ARCH=$(uname -m)
  install_package "powerpill" "alsa-utils alsa-plugins"
  [[ ${ARCH} == x86_64 ]] && install_package "powerpill" "lib32-alsa-plugins"
  return 0
}

function install_pulse() {
  clear
  echo "******************************************************"
  echo "*********     Installing Pulseaudio!   ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  ARCH=$(uname -m)
  install_package "powerpill" "pulseaudio pulseaudio-alsa pavucontrol"
  [[ ${ARCH} == x86_64 ]] && install_package "powerpill" "lib32-libpulse"
  echo "load-module module-switch-on-connect" >> /etc/pulse/default.pa
  return 0
}

function install_bash_goodies() {
  clear
  echo "******************************************************"
  echo "*********   Installing Bash Goodies!   ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "bc rsync mlocate bash-completion pkgstats ntp"
  updatedb
  timedatectl set-ntp true
  return 0
}

function user_config() {
  clear
  echo "******************************************************"
  echo "*********     configure system!        ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  git clone https://github.com/memoryleakx/dotfiles.git
  cp dotfiles/.bashrc dotfiles/.dircolors dotfiles/.dircolors_256 dotfiles/.nanorc dotfiles/.yaourtrc /etc/skel/
  cp -r dotfiles/.config/ /etc/skel/
  cp dotfiles/.bashrc dotfiles/.dircolors dotfiles/.dircolors_256 dotfiles/.nanorc dotfiles/.yaourtrc ~/
  rm -rf dotfiles
  return 0
}

function install_avahi_deamon() {
  clear
  echo "******************************************************"
  echo "*********   Installing Avahi Deamon!   ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "avahi nss-mdns"
  systemctl enable avahi-daemon
  systemctl enable avahi-dnsconfd
  return 0
}

function install_ntfs_tools() {
  clear
  echo "******************************************************"
  echo "*********   Installing NTFS TOOLS!     ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "ntfs-3g dosfstools exfat-utils fuse fuse-exfat"
  add_module "fuse"
  return 0
}

function install_openssh() {
  clear
  echo "******************************************************"
  echo "*********   Installing OPEN SSH  !     ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "openssh"
  echo 'eval $(ssh-agent)' >> /etc/profile
  return 0
}

function readahead_on() {
  clear
  echo "******************************************************"
  echo "*********      enable readahead  !     ***************"
  echo "******************************************************"
  echo ""
  
  systemctl enable systemd-readahead-collect
  systemctl enable systemd-readahead-replay
  return 0
}

function install_xserver() {
  clear
  echo "******************************************************"
  echo "*********   Installing X Server  !     ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "xorg-server xorg-server-utils xorg-xinit"
  install_package "powerpill" "xf86-input-synaptics xf86-input-mouse xf86-input-keyboard"
  install_package "powerpill" "mesa gamin"
  localectl set-keymap ${KEYMAP}
  
  #X Server Keyboard layout
  CCODE=${LANGUAGE:0:2}
  touch /etc/X11/xorg.conf.d/20-keyboard.conf
  echo 'Section "InputClass"' >> /etc/X11/xorg.conf.d/20-keyboard.conf
  echo '       Identifier "keyboard"' >> /etc/X11/xorg.conf.d/20-keyboard.conf
  echo '       MatchIsKeyboard "yes"' >> /etc/X11/xorg.conf.d/20-keyboard.conf
  echo '       Option "XkbLayout" "'$CCODE'"' >> /etc/X11/xorg.conf.d/20-keyboard.conf
  echo 'EndSection' >> /etc/X11/xorg.conf.d/20-keyboard.conf
  
  return 0
}

function install_infinality_font_config() {
  clear
  echo "******************************************************"
  echo "*******     Installing infinality font config ! ******"
  echo "******************************************************"
  echo ""
  sleep 2
  ARCH=$(uname -m)
  add_key "962DDE58"
  add_repository "infinality-bundle" "http://bohoomil.com/repo/\$arch"
  [[ $ARCH == x86_64 ]] && add_repository "infinality-bundle-multilib" "http://bohoomil.com/repo/multilib/\$arch"
  
  pacman --noconfirm -Rdds freetype2 fontconfig cairo
  pacman --noconfirm -Rdds freetype2-ubuntu fontconfig-ubuntu cairo-ubuntu
  
  pacman --noconfirm --needed -S infinality-bundle
  [[ $ARCH == x86_64 ]] && pacman --noconfirm --needed -S infinality-bundle-multilib
  
  return 0
}

function install_openssh() {
  clear
  echo "******************************************************"
  echo "*********   Installing OPEN SSH  !     ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "openssh"
  return 0
}

function install_video_driver() {
  clear
  ARCH=$(uname -m)
  
  ANSWER="/tmp/.video"
  
  dialog --backtitle "$DIALOG_TITLE" \
  --title "Install Video Card Driver" --clear \
  --menu "Please select your Video Card" 20 30 5 \
  "1"  "NVIDIA" \
  "2"  "bumblebee" \
  "3"  "Catalyst" \
  "4"  "VirtualBox" 2> $ANSWER
  
  retval=$?
  
  choice=`cat $ANSWER`
  case $retval in
    0)
      if [ $choice -eq 1 ] #NVIDIA
      then
        pacman --noconfirm -Rdds nouveau-dri
        pacman --noconfirm -Rdds mesa-libgl
        pacman --noconfirm -Rdds lib32-mesa-libgl
        install_package "powerpill" "nvidia nvidia-libgl nvidia-utils opencl-nvidia"
        install_package "powerpill" "pangox-compat"
        install_package "powerpill" "libva-vdpau-driver"
        if [[ ${ARCH} == x86_64 ]]
        then
          pacman --noconfirm -Rdds lib32-nouveau-dri
          install_package "powerpill" "lib32-nvidia-utils"
          install_package "powerpill" "lib32-nvidia-libgl"
          install_package "powerpill" "lib32-opencl-nvidia"
        fi
        mkinitcpio -p linux
        depmod $(uname -r)
        nvidia-xconfig --add-argb-glx-visuals --allow-glx-with-composite --composite -no-logo --render-accel -o /etc/X11/xorg.conf.d/20-nvidia.conf;
      fi
      
      if [ $choice -eq 2 ] #bumblebee
      then
        pacman --noconfirm -Rdds nouveau-dri
        pacman --noconfirm -Rdds mesa-libgl
        pacman --noconfirm -Rdds lib32-mesa-libgl
        install_package "powerpill" "xf86-video-intel bumblebee nvidia nvidia-libgl nvidia-utils opencl-nvidia"
        install_package "powerpill" "pangox-compat"
        install_package "powerpill" "libva-vdpau-driver"
        if [[ ${ARCH} == x86_64 ]]
        then
          pacman --noconfirm -Rdds lib32-nouveau-dri
          install_package "powerpill" "lib32-nvidia-utils"
          install_package "powerpill" "lib32-nvidia-libgl"
          install_package "powerpill" "lib32-opencl-nvidia"
        fi
        replace_line '*options nouveau modeset=1' '#options nouveau modeset=1' /etc/modprobe.d/modprobe.conf
        replace_line '*MODULES="nouveau"' '#MODULES="nouveau"' /etc/mkinitcpio.conf
        mkinitcpio -p linux
        depmod $(uname -r)
        gpasswd -a ${USERNAME} bumblebee
      fi
      
      if [ $choice -eq 3 ] #Catalyst
      then
        pacman --noconfirm -Rdds ati-dri
        [[ -f /etc/modules-load.d/ati.conf ]] && rm /etc/modules-load.d/ati.conf
        if [[ ${ARCHI} == x86_64 ]]; then
          pacman --noconfirm -Rdds lib32-ati-dri
        fi
        install_package "powerpill" "linux-headers"
        install_package "yaourt" "catalyst-total"
        mkinitcpio -p linux
        depmod $(uname -r)
        aticonfig --initial --output=/etc/X11/xorg.conf.d/20-radeon.conf
        systemctl enable atieventsd
        systemctl enable catalyst-hook
        systemctl enable temp-links-catalyst
      fi
      
      if [ $choice -eq 4 ] #VirtualBox
      then
        install_package "powerpill" "virtualbox-guest-utils"
        install_package "powerpill" "mesa-libgl"
        mkinitcpio -p linux
        depmod $(uname -r)
        add_module "vboxguest vboxsf vboxvideo" "virtualbox-guest"
        gpasswd -a ${USERNAME} vboxsf
        systemctl disable ntpd
        systemctl enable vboxservice
    fi;;
    1)
    echo "Cancel pressed.";;
    255)
    echo "ESC pressed.";;
  esac
  return 0
}

function install_cups() {
  clear
  echo "******************************************************"
  echo "*********     Installing CUPS!         ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "cups cups-filters ghostscript gsfonts"
  install_package "powerpill" "gutenprint foomatic-db foomatic-db-engine foomatic-db-nonfree foomatic-filters hplip splix cups-pdf"
  install_package "powerpill" "system-config-printer"
  systemctl enable cups
  return 0
}

function install_xfce() {
  clear
  echo "******************************************************"
  echo "*********     Installing XFCE4!        ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "xfce4 xfce4-goodies mupdf"
  install_package "powerpill" "gvfs gvfs-smb gvfs-afc lxpolkit"
  install_package "powerpill" "xdg-user-dirs"
  install_package "yaourt" "gnome-defaults-list"
  install_package "yaourt" "xfce-theme-greybird-git"
  install_package "powerpill" "faenza-icon-theme"
  install_package "yaourt" "pa-applet-git"
  install_package "yaourt" "xfce4-whiskermenu-plugin"
  install_package "powerpill" "light-locker"
  install_package "powerpill" "network-manager-applet"
  
  cp -fv /etc/skel/.xinitrc /home/${USERNAME}/
  echo -e "exec startxfce4" >> /home/${USERNAME}/.xinitrc
  chown -R ${USERNAME}:users /home/${USERNAME}/.xinitrc
  
  cd
  rm -rf /usr/share/backgrounds/xfce
  curl -O  http://fc01.deviantart.net/fs71/f/2014/081/b/e/arch_creative_construction_zone_by_memoryleakxxx-d7b6288.png
  mv arch_creative_construction_zone_by_memoryleakxxx-d7b6288.png /usr/share/backgrounds/archbg.png
  
  return 0
}

function install_lightdm() {
  clear
  echo "******************************************************"
  echo "*********     Installing LIGHTDM!      ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "lightdm lightdm-gtk3-greeter"
  cd
  rm -rf /etc/lightdm/lightdm-gtk-greeter.conf
  curl -O  https://gist.githubusercontent.com/memoryleakx/a4b35ab3901241128d3e/raw/f5a95f823bf5871dd65059f8971977203640275f/lightdm-gtk-greeter.conf
  mv lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf
  systemctl enable lightdm
  return 0
}

function install_plank() {
  clear
  echo "******************************************************"
  echo "*********     Installing PLANK DOCK!   ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "plank plank-config"
  return 0
}

function install_archey() {
  clear
  echo "******************************************************"
  echo "*********     Installing ArchEY!       ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "yaourt" "archey"
  return 0
}

function install_libreoffice() {
  clear
  echo "******************************************************"
  echo "*********     Installing libreoffice!  ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  CCODE=${LANGUAGE:0:2}
  install_package "powerpill" "libreoffice-still-common libreoffice-still-calc libreoffice-still-writer"
  install_package "powerpill" "hunspell hunspell-"$CCODE" libreoffice-still-"$CCODE
  return 0
}

function install_gimp() {
  clear
  echo "******************************************************"
  echo "*********     Installing GIMP!         ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  CCODE=${LANGUAGE:0:2}
  install_package "powerpill" "gimp gimp-help-"$CCODE" gimp-plugin-gmic gimp-plugin-fblur"
  return 0
}

function install_inkscape() {
  clear
  echo "******************************************************"
  echo "*********     Installing inkscape!     ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  CCODE=${LANGUAGE:0:2}
  install_package "powerpill" "inkscape"
  return 0
}

function install_firewall() {
  clear
  echo "******************************************************"
  echo "*********     Installing Firewall!     ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  pacman --noconfirm -Rdds firewalld
  install_package "powerpill" "ufw gufw"
  return 0
}

function install_gaming_stuff() {
  clear
  echo "******************************************************"
  echo "*********     Installing Gaming Stuff! ***************"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "steam playonlinux"
  return 0
}

function install_extra_gtk_apps() {
  clear
  echo "******************************************************"
  echo "*********   Installing GTK Apps!            **********"
  echo "******************************************************"
  echo ""
  sleep 2
  pacman --noconfirm -Rns mousepad xfce4-taskmanager
  install_package "powerpill" "geany geany-plugins"
  install_package "yaourt" "geany-themes"
  install_package "yaourt" "gnome-system-monitor-gtk2"
  return 0
}

function install_extra_qt_apps() {
  clear
  echo "******************************************************"
  echo "*********   Installing QT Apps!             **********"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "qtcreator gdb"
  install_package "powerpill" "keepassx"
  return 0
}

function install_audio_tools_and_codec() {
  clear
  echo "******************************************************"
  echo "*********   Installing Audio Tools!         **********"
  echo "******************************************************"
  echo ""
  sleep 2
  #Codecs
  install_package "powerpill" "gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav gstreamer0.10 gstreamer0.10-plugins"
  #Tools
  install_package "yaourt" "spotify"
  install_package "yaourt" "radiotray"
  install_package "powerpill" "ffmpeg-compat"
  return 0
}

function install_video_tools_and_codec() {
  clear
  echo "******************************************************"
  echo "*********   Installing Video Tools!         **********"
  echo "******************************************************"
  echo ""
  sleep 2
  #Codecs
  package_install "libquicktime libdvdread libdvdnav libdvdcss cdrdao"
  #Tools
  install_package "powerpill" "parole openshot"
  return 0
}

function install_fonts() {
  clear
  echo "******************************************************"
  echo "*********      Installing Fonts!            **********"
  echo "******************************************************"
  echo ""
  sleep 2
  pacman --noconfirm -Rns ttf-droid
  pacman --noconfirm -Rns ttf-roboto
  pacman --noconfirm -Rns ttf-ubuntu-font-family
  pacman --noconfirm -Rns otf-oswald-ib
  install_package "yaourt" "ttf-google-fonts-git"
  install_package "yaourt" "ttf-ms-fonts"
  return 0
}

function install_internet_tools() {
  clear
  echo "******************************************************"
  echo "*********     Installing Internet Tools!    **********"
  echo "******************************************************"
  echo ""
  sleep 2
  CCODE=${LANGUAGE:0:2}
  install_package "powerpill" "chromium"
  install_package "yaourt" "chromium-pepper-flash"
  install_package "powerpill" "thunderbird thunderbird-i18n-"$CCODE
  install_package "powerpill" "pidgin skype"
  install_package "yaourt" "pidgin-pbar"
  install_package "powerpill" "uget transmission-gtk"
  return 0
}

function install_java() {
  clear
  echo "******************************************************"
  echo "*********     Installing Java!              **********"
  echo "******************************************************"
  echo ""
  sleep 2
  install_package "powerpill" "jre7-openjdk icedtea-web"
  return 0
}

mainMenu
