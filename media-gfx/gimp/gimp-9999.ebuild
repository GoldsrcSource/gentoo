# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LUA_COMPAT=( luajit )
PYTHON_COMPAT=( python3_{11..14} )
VALA_USE_DEPEND=vapigen

inherit flag-o-matic git-r3 lua-single meson python-single-r1 toolchain-funcs vala xdg

DESCRIPTION="GNU Image Manipulation Program"
HOMEPAGE="https://www.gimp.org/"
EGIT_REPO_URI="https://gitlab.gnome.org/GNOME/gimp.git"
LICENSE="GPL-3+ LGPL-3+"
SLOT="0/3"

IUSE="X aalib alsa doc fits gnome heif javascript jpeg2k jpegxl lua mng openexr openmp postscript test udev unwind vala vector-icons wayland webp wmf xpm"
REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	lua? ( ${LUA_REQUIRED_USE} )
	test? ( X )
	xpm? ( X )
"

RESTRICT="!test? ( test )"

# media-libs/{babl,gegl} are required to be built with USE="introspection"
# to fix the compilation checking of /usr/share/gir-1.0/{Babl-0.1gir,Gegl-0.4.gir}
COMMON_DEPEND="
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		>=dev-python/pygobject-3.0:3[${PYTHON_USEDEP}]
	')
	>=app-accessibility/at-spi2-core-2.46.0
	app-arch/bzip2
	app-arch/libarchive:=
	>=app-arch/xz-utils-5.0.0
	>=app-text/poppler-0.90.1[cairo]
	>=app-text/poppler-data-0.4.9
	>=dev-libs/appstream-glib-0.7.16:=
	>=dev-libs/glib-2.70.0:2
	dev-libs/gobject-introspection
	>=dev-libs/json-glib-1.4.4
	>=gnome-base/librsvg-2.57.3:2
	>=media-gfx/mypaint-brushes-1.3.0:2.0=
	>=media-libs/babl-9999[introspection,lcms,vala?]
	>=media-libs/fontconfig-2.12.6
	>=media-libs/freetype-2.10.2
	>=media-libs/gegl-9999[cairo,introspection,lcms,vala?]
	>=media-libs/gexiv2-0.14.0
	>=media-libs/harfbuzz-2.6.5:=
	>=media-libs/lcms-2.13.1:2
	media-libs/libjpeg-turbo:=
	>=media-libs/libmypaint-1.6.1:=
	>=media-libs/libpng-1.6.37:0=
	>=media-libs/tiff-4.1.0:=
	net-libs/glib-networking[ssl]
	sys-libs/zlib
	>=x11-libs/cairo-1.16.0[X?]
	>=x11-libs/gdk-pixbuf-2.40.0:2[introspection]
	>=x11-libs/gtk+-3.24.48:3[introspection,wayland?,X?]
	>=x11-libs/pango-1.50.0[X?]
	aalib? ( media-libs/aalib )
	alsa? ( >=media-libs/alsa-lib-1.0.0 )
	fits? ( sci-libs/cfitsio )
	heif? ( >=media-libs/libheif-1.13.0:= )
	javascript? ( dev-libs/gjs )
	jpeg2k? ( >=media-libs/openjpeg-2.3.1:2= )
	jpegxl? ( >=media-libs/libjxl-0.6.1:= )
	lua? (
		${LUA_DEPS}
		$(lua_gen_cond_dep '
			dev-lua/lgi[${LUA_USEDEP}]
		')
	)
	mng? ( media-libs/libmng:= )
	openexr? ( >=media-libs/openexr-2.3.0:= )
	postscript? ( app-text/ghostscript-gpl:= )
	udev? ( >=dev-libs/libgudev-167:= )
	unwind? ( >=sys-libs/libunwind-1.1.0:= )
	webp? ( >=media-libs/libwebp-0.6.0:= )
	wmf? ( >=media-libs/libwmf-0.2.8[X?] )
	X? (
		x11-libs/libX11
		x11-libs/libXcursor
		x11-libs/libXext
		x11-libs/libXfixes
		>=x11-libs/libXmu-1.1.4
	)
	xpm? ( x11-libs/libXpm )
"

RDEPEND="
	${COMMON_DEPEND}
	x11-themes/hicolor-icon-theme
	gnome? ( gnome-base/gvfs )
"

DEPEND="
	${COMMON_DEPEND}
	test? ( x11-misc/xvfb-run )
	vala? ( $(vala_depend) )
"

# TODO: there are probably more atoms in DEPEND which should be in BDEPEND now
BDEPEND="
	>=dev-lang/perl-5.30.3
	dev-libs/libxslt
	dev-util/gdbus-codegen
	>=sys-devel/gettext-0.21
	doc? (
		dev-libs/gobject-introspection[doctool]
		dev-util/gi-docgen
	)
	virtual/pkgconfig
"

DOCS=( "AUTHORS" "NEWS" "README" "README.i18n" )

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
	python-single-r1_pkg_setup
	use lua && lua-single_pkg_setup

	if has_version ">=media-libs/babl-9999" || has_version ">=media-libs/gegl-9999"; then
		ewarn "Please make sure to rebuid media-libs/babl-9999 and media-libs/gegl-9999 packages"
		ewarn "before building media-gfx/gimp-9999 to have their latest master branch versions."
	fi
}

src_prepare() {
	default

	# Fix Gimp  and GimpUI devel doc installation paths
	sed -i -e "s/'doc'/'gtk-doc'/" devel-docs/reference/gimp/meson.build || die
	sed -i -e "s/'doc'/'gtk-doc'/" devel-docs/reference/gimp-ui/meson.build || die

	# Fix pygimp.interp python implementation path.
	# Meson @PYTHON_PATH@ use sandbox path e.g.:
	# '/var/tmp/portage/media-gfx/gimp-2.99.12/temp/python3.10/bin/python3'
	sed -i -e 's/@PYTHON_EXE@/'${EPYTHON}'/' plug-ins/python/pygimp.interp.in || die

	# Set proper intallation path of documentation logo
	sed -i -e "s/'gimp-@0@'.format(gimp_app_version)/'gimp-${PVR}'/" gimp-data/images/logo/meson.build || die

	# Force disable x11_target if USE="-X" is setup. See bug 943164 for additional info
	use !X && { sed -i -e 's/x11_target = /x11_target = false #/' meson.build || die; }
}

src_configure() {
	# defang automagic dependencies. Bug 943164
	use wayland || append-cflags -DGENTOO_GTK_HIDE_WAYLAND
	use X || append-cflags -DGENTOO_GTK_HIDE_X11

	use vala && vala_setup

	local emesonargs=(
		-Denable-default-bin=enabled

		-Dcheck-update=no
		-Ddebug-self-in-build=false
		-Denable-multiproc=true
		-Dappdata-test=disabled
		-Dbug-report-url=https://bugs.gentoo.org/
		-Dilbm=disabled
		-Dlibbacktrace=false
		-Dwebkit-unmaintained=false
		$(meson_feature aalib aa)
		$(meson_feature alsa)
		$(meson_feature doc gi-docgen)
		$(meson_feature fits)
		$(meson_feature heif)
		$(meson_feature javascript)
		$(meson_feature jpeg2k jpeg2000)
		$(meson_feature jpegxl jpeg-xl)
		$(meson_feature mng)
		$(meson_feature openexr)
		$(meson_feature openmp)
		$(meson_feature postscript ghostscript)
		$(meson_feature test headless-tests)
		$(meson_feature udev gudev)
		$(meson_feature vala)
		$(meson_feature webp)
		$(meson_feature wmf)
		$(meson_feature X xcursor)
		$(meson_feature xpm)
		$(meson_use lua)
		$(meson_use unwind libunwind)
		$(meson_use vector-icons)
	)

	meson_src_configure
}

src_compile() {
	export XDG_DATA_DIRS="${EPREFIX}"/usr/share  # bug 587004
	meson_src_compile
}

# for https://bugs.gentoo.org/664938
_rename_plugins() {
	einfo 'Renaming plug-ins to not collide with pre-2.10.6 file layout (bug #664938)...'
	local prename=gimp-org-
	(
		cd "${ED}"/usr/$(get_libdir)/gimp/3.0/plug-ins || exit 1
		for plugin_slash in $(ls -d1 */); do
			plugin=${plugin_slash%/}
			if [[ -f ${plugin}/${plugin} ]]; then
				# NOTE: Folder and file name need to match for Gimp to load that plug-in
				#       so "file-svg/file-svg" becomes "${prename}file-svg/${prename}file-svg"
				mv ${plugin}/{,${prename}}${plugin} || exit 1
				mv {,${prename}}${plugin} || exit 1
			fi
		done
	)
}

src_test() {
	local -x LD_LIBRARY_PATH="${BUILD_DIR}/libgimp:${LD_LIBRARY_PATH}"
	meson_src_test
}

src_install() {
	meson_src_install

	python_optimize "${ED}/usr/$(get_libdir)/gimp"
	python_fix_shebang "${ED}/usr/$(get_libdir)/gimp"

	# Create symlinks for Gimp exec in /usr/bin
	dosym "${ESYSROOT}"/usr/bin/gimp-3.0 /usr/bin/gimp
	dosym "${ESYSROOT}"/usr/bin/gimp-console-3.0 /usr/bin/gimp-console
	dosym "${ESYSROOT}"/usr/bin/gimp-script-fu-interpreter-3.0 /usr/bin/gimp-script-fu-interpreter
	dosym "${ESYSROOT}"/usr/bin/gimp-test-clipboard-3.0 /usr/bin/gimp-test-clipboard
	dosym "${ESYSROOT}"/usr/bin/gimptool-3.0 /usr/bin/gimptool

	_rename_plugins || die
}

pkg_postinst() {
	xdg_pkg_postinst
}

pkg_postrm() {
	xdg_pkg_postrm
}
