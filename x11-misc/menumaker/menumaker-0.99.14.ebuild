# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit autotools python-single-r1

DESCRIPTION="Utility that scans through the system and generates a menu of installed programs"
HOMEPAGE="https://menumaker.sourceforge.net/"
SRC_URI="https://downloads.sourceforge.net/${PN}/${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="amd64 ~ppc x86"

IUSE="doc"

RDEPEND="${PYTHON_DEPS}"
DEPEND="${RDEPEND}
	doc? ( sys-apps/texinfo )"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

PATCHES=(
	"${FILESDIR}"/${PN}-0.99.12-AM_PATH_PYTHON.patch
)

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	ECONF_SOURCE="${S}" econf PYTHON="${EPYTHON}"
}

src_compile() {
	default
	use doc && emake html
}

src_install() {
	default
	use doc && emake DESTDIR="${D}" install-html
	python_optimize
	python_fix_shebang "${ED}"/usr/bin/mmaker
}
