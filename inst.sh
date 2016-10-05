#!/bin/bash
op_title=" -| Arch Linux |- "
log="error.log"
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}  
pac_strap() {
    pacstrap /mnt ${1} --needed 2>> $log
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
		
	mount /dev/${IDEV}2 /mnt

	sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /mnt/etc/default/grub 2>> $log
	sed -i "s/timeout=5/timeout=0/" /mnt/boot/grub/grub.cfg 2>> $log
	arch_chroot "grep -q 'timeout=0' /boot/grub/grub.cfg || grub-mkconfig"

	if [ $(uname -m) == x86_64 ]; then
			sed -i '/\[multilib]$/ {
			N
			/Include/s/#//g}' /mnt/etc/pacman.conf 2>> $log
	fi
	if ! (</mnt/etc/pacman.conf grep "archlinuxfr"); then
		echo -e "\n[archlinuxfr]\nServer = http://repo.archlinux.fr/$(uname -m)\nSigLevel = Never" >> /mnt/etc/pacman.conf 2>> $log
	fi
	arch_chroot "pacman -Syy"

	pac_strap "cinnamon gnome-terminal nemo-fileroller nemo-preview"
	pac_strap "bash-completion gamin gksu python2-xdg ntfs-3g xdg-user-dirs xdg-utils"

	pac_strap "lightdm lightdm-gtk-greeter"
    arch_chroot "systemctl enable lightdm"

	sed -i "s/#autologin-user=/autologin-user=${USER}/" /mnt/etc/lightdm/lightdm.conf 2>> $log
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/" /mnt/etc/lightdm/lightdm.conf 2>> $log
	arch_chroot "groupadd -r autologin"
	arch_chroot "gpasswd -a ${USER} autologin"

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

	pac_strap "libreoffice-fresh-de firefox-i18n-de thunderbird-i18n-de hunspell-de aspell-de ttf-liberation"
	pac_strap "gimp gimp-help-de gthumb simple-scan vlc avidemux-gtk handbrake clementine mkvtoolnix-gui picard meld unrar p7zip lzop cpio"
	pac_strap "flashplugin geany leafpad pitivi frei0r-plugins xfburn simplescreenrecorder qbittorrent mlocate pkgstats"
	pac_strap "libaacs btrfs-progs f2fs-tools tlp tlp-rdw ffmpegthumbs ffmpegthumbnailer x264 upx nss-mdns libquicktime libdvdcss cdrdao"
	pac_strap "alsa-utils fuse-exfat autofs mtpfs icoutils wine-mono playonlinux winetricks nfs-utils gparted gst-plugins-ugly gst-libav"
	pac_strap "wine wine_gecko steam yaourt"
	[[ $(uname -m) == x86_64 ]] && pac_strap "lib32-alsa-plugins lib32-libpulse"
	arch_chroot "upx --best /usr/lib/firefox/firefox"

		
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

	_umount
	nano $log
	exit 0
}

opt="$1"
init
