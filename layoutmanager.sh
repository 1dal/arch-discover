#!/bin/bash
# --------------------------------------------
# Downloads and installs GNOME extensions to match layout
#
# Revision history :
#   14/04/2017 - V1.0 : by bill-mavromatis ALPHA (use on a VM or liveUSB not on your main system, it may affect your extensions)
#   16/04/2017 - V1.1 : Tweaked gsettings, bugfixes
#   16/04/2017 - V1.2 : Added more extensions and themes for Unity
#   17/04/2017 - V1.3 : Fixed invalid URL for United, changed to United Light theme
# -------------------------------------------

# check tools availability
command -v unzip >/dev/null 2>&1 || { zenity --error --text="Please install unzip"; exit 1; }
command -v wget >/dev/null 2>&1 || { zenity --error --text="Please install wget"; exit 1; }

# install path (user and system mode)
USER_PATH="$HOME/.local/share/gnome-shell/extensions"
[ -f /etc/debian_version ] && SYSTEM_PATH="/usr/local/share/gnome-shell/extensions" || SYSTEM_PATH="/usr/share/gnome-shell/extensions"

# set gnome shell extension site URL
GNOME_SITE="https://extensions.gnome.org"

# get current gnome version (major and minor only)
GNOME_VERSION="$(DISPLAY=":0" gnome-shell --version | tr -cd "0-9." | cut -d'.' -f1,2)"

# default installation path for default mode (user mode, no need of sudo)
INSTALL_MODE="user"
EXTENSION_PATH="${USER_PATH}"
INSTALL_SUDO=""

LAYOUT=""

# help message if no parameter
if [ ${#} -eq 0 ];
then
    echo "Downloads and installs GNOME extensions from Gnome Shell Extensions site https://extensions.gnome.org/"
    echo "Parameters are :"
    echo "  --windows               Windows 10 layout (panel and no topbar)"
    echo "  --macosx                Mac OS X layout (bottom dock /w autohide + topbar)"
    echo "  --unity                 Unity 7 layout (left dock + topbar)"
    exit 1
fi

# iterate thru parameters
while test ${#} -gt 0
do
  case $1 in
    --windows) declare -a arr=("1160" "608" "1031"); LAYOUT="windows"; shift; ;;
    --macosx) declare -a arr=("307" "1031" "1011"); LAYOUT="macosx"; shift; ;;
    --unity) declare -a arr=("307" "1031" "19" "744" "2"); shift; LAYOUT="unity"; shift; ;;
    *) echo "Unknown parameter $1"; shift; ;;
  esac
done

#disable all current extensions
if [ $LAYOUT == "windows" -o $LAYOUT == "macosx" -o $LAYOUT == "unity" ]; then
	echo "Layout selected: $LAYOUT"
	echo "Disabling all current extensions"
	array=($(gsettings get org.gnome.shell enabled-extensions | sed -e 's/[;,()'\'']/ /g;s/  */ /g' ))

	for each in "${array[@]}"
	do
	  echo "gnome-shell-extension-tool -d $each"
	  gnome-shell-extension-tool -d $each
	done
fi 

#install all extensions from array
for EXTENSION_ID in "${arr[@]}"
do
	# if no extension id, exit
	#[ "${EXTENSION_ID}" = "" ] && { echo "You must specify an extension ID"; exit; }

	# if no action, exit
	#[ "${ACTION}" = "" ] && { echo "You must specify a layout"; exit; }

	# if system mode, set system installation path and sudo mode
	#[ "${INSTALL_MODE}" = "system" ] && { EXTENSION_PATH="${SYSTEM_PATH}"; INSTALL_SUDO="sudo"; }

	# create temporary files
	TMP_DESC=$(mktemp -t ext-XXXXXXXX.txt)
	TMP_ZIP=$(mktemp -t ext-XXXXXXXX.zip)
	TMP_VERSION=$(mktemp -t ext-XXXXXXXX.ver)
	rm ${TMP_DESC} ${TMP_ZIP}

	# get extension description
	wget --quiet --header='Accept-Encoding:none' -O "${TMP_DESC}" "${GNOME_SITE}/extension-info/?pk=${EXTENSION_ID}"

	# get extension name
	EXTENSION_NAME=$(sed 's/^.*name[\": ]*\([^\"]*\).*$/\1/' "${TMP_DESC}")

	# get extension description
	EXTENSION_DESCR=$(sed 's/^.*description[\": ]*\([^\"]*\).*$/\1/' "${TMP_DESC}")

	# get extension UUID
	EXTENSION_UUID=$(sed 's/^.*uuid[\": ]*\([^\"]*\).*$/\1/' "${TMP_DESC}")

	# if ID not known
	if [ ! -s "${TMP_DESC}" ];
	then
	  echo "Extension with ID ${EXTENSION_ID} is not available from Gnome Shell Extension site."
	
	else
	# else, if installation mode
	#elif [ "${ACTION}" = "install" ];
	#then

	  # extract all available versions
	  sed "s/\([0-9]*\.[0-9]*[0-9\.]*\)/\n\1/g" "${TMP_DESC}" | grep "pk" | grep "version" | sed "s/^\([0-9\.]*\).*$/\1/" > "${TMP_VERSION}"

	  # check if current version is available
	  VERSION_AVAILABLE=$(grep "^${GNOME_VERSION}$" "${TMP_VERSION}")

	  # if version is not available, get the next one available
	  if [ "${VERSION_AVAILABLE}" = "" ]
	  then
	    echo "${GNOME_VERSION}" >> "${TMP_VERSION}"
	    VERSION_AVAILABLE=$(cat "${TMP_VERSION}" | sort -V | sed "1,/${GNOME_VERSION}/d" | head -n 1)
	  fi

	  # if still no version is available, error message
	  if [ "${VERSION_AVAILABLE}" = "" ]
	  then
	    echo "Gnome Shell version is ${GNOME_VERSION}."
	    echo "Extension ${EXTENSION_NAME} is not available for this version."
	    echo "Available versions are :"
	    sed "s/\([0-9]*\.[0-9]*[0-9\.]*\)/\n\1/g" "${TMP_DESC}" | grep "pk" | grep "version" | sed "s/^\([0-9\.]*\).*$/\1/" | sort -V | xargs

	  # else, install extension
	  else
	    # get extension description
	    wget --quiet --header='Accept-Encoding:none' -O "${TMP_DESC}" "${GNOME_SITE}/extension-info/?pk=${EXTENSION_ID}&shell_version=${VERSION_AVAILABLE}"

	    # get extension download URL
	    EXTENSION_URL=$(sed 's/^.*download_url[\": ]*\([^\"]*\).*$/\1/' "${TMP_DESC}")

	    # download extension archive
	    wget --quiet --header='Accept-Encoding:none' -O "${TMP_ZIP}" "${GNOME_SITE}${EXTENSION_URL}"

	    # unzip extension to installation folder
	    ${INSTALL_SUDO} mkdir -p ${EXTENSION_PATH}/${EXTENSION_UUID}
	    ${INSTALL_SUDO} unzip -oq "${TMP_ZIP}" -d ${EXTENSION_PATH}/${EXTENSION_UUID}
	    ${INSTALL_SUDO} chmod +r ${EXTENSION_PATH}/${EXTENSION_UUID}/*

	    # list enabled extensions
	    EXTENSION_LIST=$(gsettings get org.gnome.shell enabled-extensions | sed 's/^.\(.*\).$/\1/')

	    # if extension not already enabled, declare it
	    EXTENSION_ENABLED=$(echo ${EXTENSION_LIST} | grep ${EXTENSION_UUID})
	    [ "$EXTENSION_ENABLED" = "" ] && gsettings set org.gnome.shell enabled-extensions "[${EXTENSION_LIST},'${EXTENSION_UUID}']"

	    # success message
	    echo "Gnome Shell version is ${GNOME_VERSION}."
	    echo "Extension ${EXTENSION_NAME} version ${VERSION_AVAILABLE} has been installed in ${INSTALL_MODE} mode (Id ${EXTENSION_ID}, Uuid ${EXTENSION_UUID})"
	    #echo "Restart Gnome Shell to take effect."

	  fi

	# else, it is remove mode
	#else

	    # remove extension folder
	    #${INSTALL_SUDO} rm -f -r "${EXTENSION_PATH}/${EXTENSION_UUID}"

	    # success message
	    #echo "Extension ${EXTENSION_NAME} has been removed in ${INSTALL_MODE} mode (Id ${EXTENSION_ID}, Uuid ${EXTENSION_UUID})"
	    #echo "Restart Gnome Shell to take effect."

	fi

	# remove temporary files
	rm -f ${TMP_DESC} ${TMP_ZIP} ${TMP_VERSION}
done

#tweak gsettings
  case $LAYOUT in
    windows) 
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/TopIcons@phocean.net/schemas/ set org.gnome.shell.extensions.topicons tray-pos 'Center'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/TopIcons@phocean.net/schemas/ set org.gnome.shell.extensions.topicons tray-order '2'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com/schemas set org.gnome.shell.extensions.dash-to-panel panel-position 'BOTTOM'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com/schemas set org.gnome.shell.extensions.dash-to-panel location-clock 'STATUSRIGHT'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/gnomenu@panacier.gmail.com/schemas set org.gnome.shell.extensions.gnomenu disable-activities-hotcorner 'true'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/gnomenu@panacier.gmail.com/schemas set org.gnome.shell.extensions.gnomenu hide-panel-view 'true'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/gnomenu@panacier.gmail.com/schemas set org.gnome.shell.extensions.gnomenu hide-panel-apps 'true'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/gnomenu@panacier.gmail.com/schemas set org.gnome.shell.extensions.gnomenu panel-menu-label-text 'Start'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/gnomenu@panacier.gmail.com/schemas set org.gnome.shell.extensions.gnomenu disable-panel-menu-keyboard 'true'
	gnome-shell-extension-tool -e dash-to-panel@jderose9.github.com
	gnome-shell-extension-tool -e gnomenu@panacier.gmail.com
	gnome-shell-extension-tool -e TopIcons@phocean.net
	gnome-shell --replace &
	;;
    macosx) 
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock intellihide 'true'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock extend-height 'false'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock background-opacity '0.1'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock background-color '#FFFFFF'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock dock-fixed 'false'
	gnome-shell-extension-tool -e dash-to-dock@micxgx.gmail.com
	gnome-shell-extension-tool -e TopIcons@phocean.net
	gnome-shell-extension-tool -e dash-to-dock@micxgx.gmail.com
	gnome-shell --replace &
	;;
    unity) 
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock intellihide 'false'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock background-opacity '0.7'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock background-color '#2C001E'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock dock-fixed 'true'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock extend-height 'true'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock show-running 'false'
	gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock show-apps-at-top 'true'
	gnome-shell-extension-tool -e dash-to-dock@micxgx.gmail.com
	gnome-shell-extension-tool -e TopIcons@phocean.net
	gnome-shell-extension-tool -e user-theme@gnome-shell-extensions.gcampax.github.com
	gnome-shell-extension-tool -e Hide_Activities@shay.shayel.org
	gnome-shell-extension-tool -e Move_Clock@rmy.pobox.com
	mkdir ~/.themes && wget https://dl.opendesktop.org/api/files/download/id/1492388511/United%20GNOME.tar.gz && tar -xvzf United\ GNOME.tar.gz -C ~/.themes/ 
	#wget https://dl.opendesktop.org/api/files/download/id/1492218139/United%201.2.tar.gz && tar -xvzf United\ 1.2.tar.gz -C ~/.themes/ && mv ~/.themes/United\ 1.2 ~/.themes/United
	gsettings set org.gnome.desktop.interface gtk-theme "United"
	gsettings set org.gnome.shell.extensions.user-theme name "United"
	gsettings set org.gnome.desktop.background picture-uri file:///$HOME/.themes/United/wallpaper.png
	gnome-shell-extension-tool -e user-theme@gnome-shell-extensions.gcampax.github.com
	gnome-shell --replace &
	;;
  esac
