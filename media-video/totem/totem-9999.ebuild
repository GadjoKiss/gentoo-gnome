# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="5"
GCONF_DEBUG="yes"
GNOME2_LA_PUNT="yes" # plugins are dlopened
PYTHON_COMPAT=( python2_{6,7} )
PYTHON_REQ_USE="threads"

inherit gnome2 multilib python-single-r1
if [[ ${PV} = 9999 ]]; then
	VALA_MIN_API_VERSION="0.14"
	inherit gnome2-live vala
fi

DESCRIPTION="Media player for GNOME"
HOMEPAGE="http://projects.gnome.org/totem/"

LICENSE="GPL-2+ LGPL-2+"
SLOT="0"
IUSE="flash grilo +introspection lirc nautilus nsplugin +python test zeitgeist"
# see bug #359379
REQUIRED_USE="flash? ( nsplugin )
	python? ( introspection )
	zeitgeist? ( introspection )"

if [[ ${PV} = 9999 ]]; then
	IUSE+=" doc vala"
	REQUIRED_USE+=" zeitgeist? ( vala )"
	KEYWORDS=""
else
	KEYWORDS="~amd64 ~x86 ~x86-fbsd"
fi

# TODO:
# Cone (VLC) plugin needs someone with the right setup to test it
#
# FIXME:
# Automagic tracker-0.9.0
# Runtime dependency on gnome-session-2.91
RDEPEND="
	>=dev-libs/glib-2.33:2
	>=x11-libs/gdk-pixbuf-2.23.0:2
	>=x11-libs/gtk+-3.5.2:3[introspection?]
	>=dev-libs/totem-pl-parser-2.32.4[introspection?]
	>=dev-libs/libpeas-1.1.0[gtk]
	>=x11-themes/gnome-icon-theme-2.16
	x11-libs/cairo
	>=dev-libs/libxml2-2.6:2
	>=media-libs/clutter-1.6.8:1.0
	>=media-libs/clutter-gst-1.5.5:2.0
	>=media-libs/clutter-gtk-1.0.2:1.0
	x11-libs/mx:1.0

	media-libs/gstreamer:1.0
	media-libs/gst-plugins-base:1.0[X,introspection?,pango]
	>=media-libs/gst-plugins-bad-1.0.2:1.0
	media-libs/gst-plugins-good:1.0
	media-plugins/gst-plugins-taglib:1.0
	media-plugins/gst-plugins-meta:1.0

	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	>=x11-libs/libXxf86vm-1.0.1

	gnome-base/gsettings-desktop-schemas
	x11-themes/gnome-icon-theme-symbolic

	flash? ( dev-libs/totem-pl-parser[quvi] )
	grilo? ( media-libs/grilo:0.2 )
	introspection? ( >=dev-libs/gobject-introspection-0.6.7 )
	lirc? ( app-misc/lirc )
	nautilus? ( >=gnome-base/nautilus-2.91.3 )
	nsplugin? (
		>=dev-libs/dbus-glib-0.82
		>=x11-misc/shared-mime-info-0.22 )
	python? (
		${PYTHON_DEPS}
		>=dev-python/pygobject-2.90.3:3[${PYTHON_USEDEP}]
		dev-python/pyxdg[${PYTHON_USEDEP}]
		dev-python/dbus-python[${PYTHON_USEDEP}]
		>=x11-libs/gtk+-2.91.7:3[introspection] )
	zeitgeist? ( dev-libs/libzeitgeist )
"
DEPEND="${RDEPEND}
	app-text/docbook-xml-dtd:4.5
	>=app-text/gnome-doc-utils-0.20.3
	app-text/scrollkeeper
	>=dev-util/gtk-doc-am-1.14
	>=dev-util/intltool-0.40
	sys-devel/gettext
	x11-proto/xextproto
	x11-proto/xproto
	virtual/pkgconfig
	test? ( python? ( dev-python/pylint ) )
"
# docbook-xml-dtd is needed for user doc
# Only needed when regenerating C sources from Vala files
if [[ ${PV} = 9999 ]]; then
	DEPEND+=" vala? ( $(vala_depend) )
		doc? ( >=dev-util/gtk-doc-1.14 )"
fi

src_prepare() {
	# AC_CONFIG_AUX_DIR_DEFAULT doesn't exist, and eautoreconf/aclocal fails
	mkdir -p m4

	if [[ ${PV} = 9999 ]]; then
		# Only needed when regenerating C sources from Vala files
		use vala && vala_src_prepare
	fi
	gnome2_src_prepare
}

src_configure() {
	DOCS="AUTHORS ChangeLog NEWS README TODO"
	use nsplugin && DOCS="${DOCS} browser-plugin/README.browser-plugin"

	#--with-smclient=auto needed to correctly link to libICE and libSM
	G2CONF="${G2CONF}
		--disable-run-in-source-tree
		--disable-static
		--with-smclient=auto
		--enable-easy-codec-installation
		$(use_enable flash vegas-plugin)
		$(use_enable introspection)
		$(use_enable nautilus)
		$(use_enable nsplugin browser-plugins)
		$(use_enable python)
		BROWSER_PLUGIN_DIR=/usr/$(get_libdir)/nsbrowser/plugins"

	# XXX: always set to true otherwise tests fails due to pylint not
	# respecting EPYTHON (wait for python-r1)
	# pylint is checked unconditionally, but is only used for make check
	G2CONF="${G2CONF} PYLINT=$(type -P true)"

	# Disabled: sample-python, sample-vala
	local plugins="apple-trailers,autoload-subtitles,brasero-disc-recorder"
	plugins+=",chapters,im-status,gromit,media-player-keys,ontop"
	plugins+=",properties,recent,screensaver,screenshot,sidebar-test"
	plugins+=",skipto"
	use grilo && plugins+=",grilo"
	use lirc && plugins+=",lirc"
	use nautilus && plugins+=",save-file"
	use python && plugins+=",dbusservice,pythonconsole,opensubtitles"
	if [[ ${PV} = 9999 ]]; then
		# Only needed when regenerating C sources from Vala files
		G2CONF="${G2CONF} $(use_enable vala)"
		use vala && plugins+=",rotation"
	else
		G2CONF="${G2CONF} --enable-vala VALAC=$(type -P true)"
		plugins+=",rotation"
	fi
	use zeitgeist && plugins+=",zeitgeist-dp"

	G2CONF="${G2CONF} --with-plugins=${plugins}"

	# Work around sandbox violations when FEATURES=-userpriv caused by
	# gst-inspect-1.0(bug #358755)
	unset DISPLAY
	gnome2_src_configure
}

pkg_postinst() {
	gnome2_pkg_postinst

	ewarn
	ewarn "If totem doesn't play some video format, please check your"
	ewarn "USE flags on media-plugins/gst-plugins-meta"
	ewarn
}
