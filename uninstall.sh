#!/bin/bash

SLE=/System/Library/Extensions
RM=/bin/rm
PKGUTIL=/usr/sbin/pkgutil
TOUCH=/usr/bin/touch

if (( $UID != 0 )); then
	echo This script must be run as root, try \'sudo $0\'
	exit 1
fi

function chk_util
{
	if [[ !(-x $1) ]]; then
		echo $1 not found
		exit 1
	fi
	return 0
}

chk_util $RM
chk_util $PKGUTIL
chk_util $TOUCH

function pkg_rm
{
	case $1 in
	audio)
		L='pkg\.10\.[5-9]\.(appleac97audio|ensoniqaudiopci)' ;;
	vmmouse)
		L='vmmouse_for_(apple|voodoo)_S?L\.pkg' ;;
	guestd)
		L='guestd_patches_[1-3]\.pkg' ;;
	vmsvga2)
		L='vmsvga2(Lion|(Snow)?Leo)\.pkg' ;;
	*)
		L='(vmsvga2(|accel|ga)|vmmouse_for_(apple|voodoo)|vmwaretoolsguestd|appleac97audio|ensoniqaudiopci)\.pkg' ;;
	esac
	$PKGUTIL --regexp --forget net\\.osx86\\.$L 2>/dev/null
	return 0
}

function kext_rm
{
	case $1 in
	ensoniq)
		L=AppleAC97Audio.kext/Contents/PlugIns/EnsoniqAudioPCI.kext ;;
	ac97)
		L=AppleAC97Audio.kext ;;
	vmmouse)
		L='ApplePS2Controller.kext/Contents/PlugIns/VMMouse.kext VoodooPS2Controller.kext/Contents/PlugIns/VMMouse.kext' ;;
	vmsvga2)
		L='VMsvga2.kext VMsvga2Accel.kext VMsvga2GA.plugin VMsvga2GLDriver.bundle' ;;
	*)
		echo Must specify one of ensoniq, ac97, vmmouse or vmsvga2
		return 1 ;;
	esac
	for l in $L; do
		if [[ !(-d $SLE/$l) ]]; then continue; fi
		echo $RM -rf $SLE/$l
		$RM -rf $SLE/$l
	done
	return 0
}

function guestd_note
{
	echo
	echo If you\'ve patched VMware Tools daemon for use with VMsvga2 and you\'d
	echo like to return to using VMware\'s display driver, you should reinstall
	echo VMware Tools.  This script neither removes the patch nor restores the
	echo original VMware Tools daemon.
	return 0
}

echo Removing receipts for old package ids
pkg_rm

#
# detect vmmouse
#
if [[ (-d $SLE/ApplePS2Controller.kext/Contents/PlugIns/VMMouse.kext) || (-d $SLE/VoodooPS2Controller.kext/Contents/PlugIns/VMMouse.kext) ]]; then
	echo
	echo VMMouse.kext detected.
	PS3='remove? '
	select ans in yes no quit; do
		case $ans in
		yes)
			pkg_rm vmmouse
			kext_rm vmmouse
			$TOUCH -c $SLE ;;
		quit)
			exit 0 ;;
		esac
		break;
	done
fi

#
# detect VMsvga2
#
if [[ (-d $SLE/VMsvga2.kext) || (-d $SLE/VMsvga2Accel.kext) || (-d $SLE/VMsvga2GA.plugin) || (-d $SLE/VMsvga2GLDriver.bundle) ]]; then
	echo
	echo VMsvga2.kext detected.
	PS3='remove? '
	select ans in yes no quit; do
		case $ans in
		yes)
			pkg_rm vmsvga2
			pkg_rm guestd
			kext_rm vmsvga2
			guestd_note ;;
		quit)
			exit 0 ;;
		esac
		break;
	done
fi

#
# detect EnsoniqAudioPCI
#
if [[ -d $SLE/AppleAC97Audio.kext/Contents/PlugIns/EnsoniqAudioPCI.kext ]]; then
	echo
	echo EnsoniqAudioPCI.kext detected.
	echo select yes to remove EnsoniqAudioPCI.kext
	echo select all to remove all of AppleAC97Audio.kext
	PS3='remove? '
	select ans in yes all no quit; do
		case $ans in
		yes)
			pkg_rm audio
			kext_rm ensoniq
			$TOUCH -c $SLE ;;
		all)
			pkg_rm audio
			kext_rm ac97 ;;
		quit)
			exit 0 ;;
		esac
		break;
	done
fi
exit 0
