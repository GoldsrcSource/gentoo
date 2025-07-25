# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LUA_COMPAT=( lua5-{1..4} luajit )
PYTHON_COMPAT=( python3_{10..13} )
DISTUTILS_EXT=1
DISTUTILS_OPTIONAL="true"
DISTUTILS_USE_PEP517="setuptools"
GENTOO_DEPEND_ON_PERL="no"
MY_P="${P/_/-}"

inherit autotools lua perl-module distutils-r1 flag-o-matic

DESCRIPTION="A data logging and graphing system for time series data"
HOMEPAGE="https://oss.oetiker.ch/rrdtool/"
# upstream dist doesnt include python tests
SRC_URI="
	https://github.com/oetiker/rrdtool-1.x/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.gh.tar.gz
"
S="${WORKDIR}/rrdtool-1.x-${PV}"

LICENSE="GPL-2"
SLOT="0/8.0.0"
KEYWORDS="~alpha amd64 arm arm64 ~hppa ~loong ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux"
IUSE="dbi doc examples graph lua perl python rados rrdcached rrdcgi ruby static-libs tcl tcpd test"

RESTRICT="!test? ( test )"

# perl? ( graph ) bug #940931
REQUIRED_USE="
	perl? ( graph )
	python? ( ${PYTHON_REQUIRED_USE} )
	lua? ( ${LUA_REQUIRED_USE} )
"

PDEPEND="ruby? ( ~dev-ruby/rrdtool-bindings-${PV} )"

RDEPEND="
	dev-libs/glib:2[static-libs(+)?]
	dev-libs/libxml2:2=[static-libs(+)?]
	dbi? ( dev-db/libdbi[static-libs(+)?] )
	graph? (
		media-libs/libpng:0=[static-libs(+)?]
		x11-libs/cairo[svg(+),static-libs(+)?]
		x11-libs/pango
	)
	lua? ( ${LUA_DEPS} )
	perl? ( dev-lang/perl:= )
	python? ( ${PYTHON_DEPS} )
	rados? ( sys-cluster/ceph )
	rrdcached? (
		acct-group/rrdcached
		acct-user/rrdcached
	)
	tcl? ( dev-lang/tcl:0= )
	tcpd? ( sys-apps/tcp-wrappers )
"

DEPEND="${RDEPEND}"

BDEPEND="
	sys-apps/groff
	virtual/pkgconfig
	app-alternatives/awk
	python? (
		${DISTUTILS_DEPS}
		$(python_gen_cond_dep 'dev-python/setuptools[${PYTHON_USEDEP}]')
	)
	test? (
		app-alternatives/bc
		lua? ( ${LUA_DEPS} )
	)
"

PATCHES=(
	"${FILESDIR}"/${PN}-1.7.0-disable-rrd_graph-cgi.patch
	"${FILESDIR}"/${PN}-1.7.1-configure.ac.patch
)

src_prepare() {
	default

	# Bug #456810
	local mysedargs=(
		-e 's|$LUA_CFLAGS|IGNORE_THIS_BAD_TEST|g'
		-e 's|^sleep 1$||g'
		-e '/^dnl.*png/s|^dnl||g'
		-i configure.ac
	)

	sed "${mysedargs[@]}" || die

	# Python bindings are built and installed manually
	local mysedargs=(
		-e '/^all-local:/s| @COMP_PYTHON@||'
		-i bindings/Makefile.am
	)

	sed "${mysedargs[@]}" || die

	if ! use graph ; then
		# Makefile needs to be adjusted for disabling 'graph' feature
		local mysedargs=(
			-e '/^TESTS =/,/^$/ {
				s:rpn[0-9]*::g;
				s:create-with-source-4::;
				s:xport1::;
				s:dcounter1::;
				s:vformatter1::;
				s:graph[0-9]*::g;
			}'
			-i tests/Makefile.am
		)

		sed "${mysedargs[@]}" || die

		# Remove graph test from lua
		sed -i -e '/Testing rrd.graphv/,$ d' bindings/lua/test.lua{,50}.bottom || die
	fi

	# Makefile needs to be adjusted for disabling 'rrdcached' feature
	if ! use rrdcached ; then
		local mysedargs=(
			-e '/^TESTS =/,/^$/ {
				s:list1::;
			}'
			-i tests/Makefile.am
		)

		sed "${mysedargs[@]}" || die
	fi

	eautoreconf
}

src_configure() {
	export rd_cv_gcc_flag__Werror=no
	export rd_cv_ms_async=ok
	export RRDDOCDIR="${EPREFIX}/usr/share/doc/${PF}"

	# Bug #260380
	[[ ${CHOST} == *-solaris* ]] && append-flags -D__EXTENSIONS__

	# Enabling '-ffast-math' is known to cause problems.
	filter-flags -ffast-math

	# We will handle Lua bindings ourselves, upstream is not multi-impl-ready
	# and their Lua-detection logic depends on having the right version of the Lua
	# interpreter available at build time.
	local myeconfargs=(
		--disable-lua
		--disable-ruby
		--disable-ruby-site-install
		--disable-python
		$(usex !dbi '--disable-libdbi' '')
		$(usex !examples '--disable-examples' '')
		$(use_enable graph rrd_graph)
		$(use_enable perl perl-site-install)
		$(use_enable perl)
		$(usex !rados '--disable-librados' '')
		$(usex !rrdcached '--disable-rrdcached' '')
		$(use_enable rrdcgi)
		$(use_enable static-libs static)
		$(usex !tcpd '--disable-libwrap' '')
		$(use_enable tcl)
		$(use_enable tcl tcl-site)
		$(use_with tcl tcllib "${EPREFIX}"/usr/$(get_libdir))
		--with-perl-options="INSTALLDIRS=vendor"
	)

	econf "${myeconfargs[@]}"
}

lua_src_compile() {
	pushd "${BUILD_DIR}"/bindings/lua || die

	# We do need the CMOD-dir path here, otherwise libtool complains.
	# Use the real one (i.e. not within ${ED}) just in case.
	local myemakeargs=(
		LUA_CFLAGS="$(lua_get_CFLAGS)"
		LUA_INSTALL_CMOD="$(lua_get_cmod_dir)"
	)

	emake "${myemakeargs[@]}"

	popd || die
}

python_compile() {
	cd bindings/python || die
	distutils-r1_python_compile
}

src_compile() {
	default

	# Only copy sources now so that we do not
	# trigger librrd compilation multiple times.
	if use lua; then
		lua_copy_sources
		lua_foreach_impl lua_src_compile
	fi

	use python && distutils-r1_src_compile
}

lua_src_test() {
	pushd "${BUILD_DIR}"/bindings/lua || die
	LUA_CPATH="${PWD}/.libs/?.so" emake LUA="${LUA}" test
	popd || die
}

python_test() {
	LD_LIBRARY_PATH="${S}/src/.libs:${LD_LIBRARY_PATH}" eunittest
}

src_test() {
	export LC_ALL=C
	default

	if use lua; then
		lua_foreach_impl lua_src_test
	fi

	if use perl; then
		pushd bindings/perl-shared >/dev/null || die
		LD_LIBRARY_PATH="${S}/src/.libs:${LD_LIBRARY_PATH}" perl-module_src_test
		popd >/dev/null || die
		pushd bindings/perl-piped >/dev/null || die
		LD_LIBRARY_PATH="${S}/src/.libs:${LD_LIBRARY_PATH}" perl-module_src_test
		popd >/dev/null || die
	fi

	if use python && use graph ; then
		# All tests explicitly use graph
		pushd bindings/python >/dev/null || die
		distutils-r1_src_test
		popd >/dev/null || die
	fi
}

lua_src_install() {
	pushd "${BUILD_DIR}"/bindings/lua || die

	# This time we must prefix the CMOD-dir path with ${ED},
	# so that make does not try to violate the sandbox.
	local myemakeargs=(
		LUA_INSTALL_CMOD="${ED}/$(lua_get_cmod_dir)"
	)

	emake "${myemakeargs[@]}" install

	popd || die
}

src_install() {
	default

	if ! use doc; then
		rm -rf "${ED}"/usr/share/doc/"${PF}"/{html,txt} || die
	fi

	if use lua; then
		lua_foreach_impl lua_src_install
	fi

	if use perl; then
		perl_delete_localpod
		perl_delete_packlist
	fi

	use python && distutils-r1_src_install

	if use rrdcached; then
		newconfd "${FILESDIR}"/rrdcached.confd-r1 rrdcached
		newinitd "${FILESDIR}"/rrdcached.init-r1 rrdcached
	fi

	find "${ED}" -name '*.la' -delete || die
}
