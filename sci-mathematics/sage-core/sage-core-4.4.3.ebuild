# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="3"

PYTHON_DEPEND="2:2.6"
PYTHON_USE_WITH="sqlite"

inherit distutils eutils flag-o-matic python sage

MY_P="sage-${PV}"

DESCRIPTION="Sage's core componenents"
HOMEPAGE="http://www.sagemath.org"
SRC_URI="mirror://sage/spkg/standard/${MY_P}.spkg -> ${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~ppc ~x86"
IUSE="testsuite"

RESTRICT="mirror"

# TODO: add dependencies
DEPEND="|| ( =dev-lang/python-2.6.4-r99
		=dev-lang/python-2.6.5-r99 )
	>=dev-lang/R-2.10.1[lapack,readline]
	dev-libs/gmp
	>=dev-libs/ntl-5.5.2
	>=dev-libs/mpfr-2.4.2
	>=dev-lisp/ecls-10.2.1
	>=dev-python/cython-0.12.1
	>=dev-python/jinja-2.1.1
	>=dev-python/numpy-1.3.0[lapack]
	>=dev-python/rpy-2.0.6
	media-libs/gd
	media-libs/libpng
	>=net-zope/zodb-3.7.0
	>=sci-libs/flint-1.5.0[ntl]
	>=sci-libs/fplll-3.0.12
	=sci-libs/givaro-3.2*
	>=sci-libs/gsl-1.10
	>=sci-libs/iml-1.0.1
	>=sci-libs/lapack-atlas-3.8.3
	>=sci-libs/libcliquer-1.2.5
	>=sci-libs/linbox-1.1.6[ntl,sage]
	>=sci-libs/m4ri-20100221
	>=sci-libs/mpfi-1.4
	|| ( >=sci-mathematics/pari-2.3.5[data,gmp]
	     >=sci-mathematics/pari-2.3.5[data,mpir] )
	>=sci-libs/pynac-0.2.0_p3
	>=sci-libs/symmetrica-2.0
	>=sci-libs/zn_poly-0.9
	>=sci-mathematics/eclib-20080310_p10
	>=sci-mathematics/ecm-6.2.1
	>=sci-mathematics/polybori-0.6.4[sage]
	>=sci-mathematics/ratpoints-2.1.3
	~sci-mathematics/sage-clib-${PV}
	~sci-mathematics/sage-singular-3.1.0.4.20100214
	~sci-mathematics/sage-base-1.0
	~sci-mathematics/sage-scripts-${PV}
	>=sys-libs/readline-6.0
	virtual/cblas"
RDEPEND="${DEPEND}"

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	# switch to lapack-atlas as some dependencies of sage are linked against it
	# specifically because of clapack.
	OLD_IMPLEM=$(eselect lapack show | cut -d: -f2)
	einfo "Switching to lapack-atlas with eselect."
	eselect lapack set atlas

	# make sure we are using Python 2.6 and check use flags
	python_set_active_version 2.6
	python_pkg_setup
}

src_prepare() {
	############################################################################
	# Fixes to Sage's build system
	############################################################################

	# Fix startup issue and python-2.6.5 problem
	append-flags -fno-strict-aliasing -DNDEBUG

	# fix build file to make it compile without other Sage componenents
	epatch "${FILESDIR}"/${PN}-4.3.4-site-packages.patch

	# use already installed csage
	rm -rf c_lib || die "rm failed"

	# fix paths for sigular - TODO: remove once singular is moved out of Sage
	sed -i \
		-e "s:SAGE_ROOT[[:space:]]*+[[:space:]]*\([\'\"]\)/local/include/singular\([^\1]*\)\1:\1${SAGE_LOCAL}/include/singular\2\1:g" \
		-e "s:SAGE_ROOT[[:space:]]*+[[:space:]]*\([\'\"]\)/local/include/libsingular.h\1:\1${SAGE_LOCAL}/include/libsingular.h\1:g" \
		module_list.py || die "sed failed"

	# fix paths for various libraries (including fix for png14)
	sed -i \
		-e "s:SAGE_ROOT[[:space:]]*+[[:space:]]*\([\'\"]\)/local/include/\([^\1]*\)\1:\1/usr/include/\2\1:g" \
		-e "s:SAGE_LOCAL + \"/share/polybori/flags.conf\":\"/usr/share/polybori/flags.conf\":g" \
		-e "s:SAGE_ROOT+'/local/lib/python/site-packages/numpy/core/include':'$(python_get_sitedir)/numpy/core/include':g" \
		-e "s:sage/c_lib/include/:/usr/share/include/csage/:g" \
		-e "s:png12:png:g" \
		module_list.py || die "sed failed"

	# set path to system Cython
	sed -i "s:SAGE_LOCAL + '/lib/python/site-packages/Cython/Includes/':'$(python_get_sitedir)/Cython/Includes/':g" \
		setup.py || die "sed failed"

	# TODO: once Singular is installed to standard dirs, remove the following
	sed -i \
		-e "s:m.library_dirs += \['%s/lib' % SAGE_LOCAL\]:m.library_dirs += \['${SAGE_LOCAL}/$(get_libdir)','%s/lib' % SAGE_LOCAL\]:g" \
		-e "s:include_dirs = \['%s/include'%SAGE_LOCAL:include_dirs = \['${SAGE_LOCAL}/include','%s/include'%SAGE_LOCAL:g" \
		setup.py

	# rebuild in place
	sed -i "s:SAGE_DEVEL + 'sage/sage/ext/interpreters':'sage/ext/interpreters':g" \
		setup.py || die "sed failed"

	# TODO: why does Sage fail with commentator ?

	############################################################################
	# Fixes to Sage itself
	############################################################################

	# run maxima with ecl
	sed -i \
		-e "s:maxima-noreadline:maxima -l ecl:g" \
		-e "s:maxima --very-quiet:maxima -l ecl --very-quiet:g" \
		sage/interfaces/maxima.py || die "sed failed"

	# Ticket #7803:
	# apply patches fixing deprecation warning which interfers with test output
	epatch "${FILESDIR}"/${PN}-4.3.3-combinat-sets-deprecation.patch

	# use delaunay from matplotlib (see ticket #6946)
	epatch "${FILESDIR}"/${PN}-4.3.3-delaunay-from-matplotlib.patch

	# use arpack from scipy (see also scipy ticket #231)
	epatch "${FILESDIR}"/${PN}-4.3.3-arpack-from-scipy.patch

	# fix include paths
	sed -i \
		-e "s:'%s/include/csage'%SAGE_LOCAL:'/usr/include/csage':g" \
		-e "s:'%s/sage/sage/ext'%SAGE_DEVEL:'sage/ext':g" \
		setup.py || die "sed failed"
	sed -i "s:'%s/local/include/csage/'%SAGE_ROOT:'/usr/include/csage/':g" \
		sage/misc/cython.py || die "sed failed"

	# Adopt Ticket #8316 to replace jinja-1 with jinja-2
	epatch "${FILESDIR}"/${PN}-4.4.2-jinja2.patch

	# Fix portage QA warning. Potentially prevent some leaking.
	epatch "${FILESDIR}"/${PN}-4.4.2-flint.patch

	# Replace gmp with mpir
# 	sage_package ${P} \
# 		sed -i "s:gmp\.h:mpir.h:g" \
# 			module_list.py \
# 			sage/libs/gmp/types.pxd \
# 			sage/combinat/partitions_c.cc \
# 			sage/combinat/partitions_c.h \
# 			sage/combinat/partitions.pyx \
# 			sage/ext/cdefs.pxi \
# 			sage/libs/gmp/mpf.pxd \
# 			sage/libs/gmp/mpn.pxd \
# 			sage/libs/gmp/mpq.pxd \
# 			sage/libs/gmp/mpz.pxd \
# 			sage/libs/gmp/random.pxd \
# 			sage/libs/gmp/types.pxd \
# 			sage/libs/linbox/matrix_rational_dense_linbox.cpp \
# 			sage/misc/cython.py \
# 			sage/rings/memory.pyx \
# 			sage/rings/bernmm/bern_modp.cpp \
# 			sage/rings/bernmm/bern_rat.cpp \
# 			sage/rings/bernmm/bern_rat.h \
# 			sage/rings/bernmm/bernmm-test.cpp \
# 			sage/rings/integer.pyx || die "sed failed"

# 	sage_package ${P} \
# 		sed -i \
# 			-e "s:'gmp':'mpir':g" \
# 			-e "s:\"gmp\":\"mpir\":g" \
# 			-e "s:'gmpxx':'mpirxx':g" \
# 			-e "s:\"gmpxx\":\"mpirxx\":g" \
# 			module_list.py sage/misc/cython.py || die "sed failed"

	# fix jmol's and sage3d's path
	sed -i \
		-e "s:sage.misc.misc.SAGE_LOCAL, \"bin/jmol\":\"/usr/bin/jmol\":g" \
		-e "s:sage.misc.misc.SAGE_LOCAL, \"bin/sage3d\":\"/usr/bin/sage3d\":g" \
		sage/plot/plot3d/base.pyx || die "sed failed"

	# make sure line endings are unix ones so as not to confuse python-2.6.5
	edos2unix sage/libs/mpmath/ext_impl.pxd
	edos2unix sage/libs/mpmath/ext_main.pyx
	edos2unix sage/libs/mpmath/ext_main.pxd
	edos2unix sage/libs/mpmath/ext_libmp.pyx

	# do not forget to run distutils
	distutils_src_prepare
}

src_configure() {
	# set Sage's version string
	export SAGE_VERSION=${PV}

	# these variables are still needed; remove them once Singular is removed
	# from Sage
	export SAGE_ROOT
	export SAGE_LOCAL

	# files are not built unless they are touched
	find sage -name "*pyx" -exec touch '{}' \; || die "find failed"
}

src_install() {
	if use testsuite ; then
		insinto "${SAGE_ROOT}"/devel/sage-main
		doins -r sage || die "doins failed"
	fi

	distutils_src_install

	# prevent false positive reports from revdep-rebuild
	insinto /etc/revdep-rebuild
	doins "${FILESDIR}"/50sage-core || die "doins failed"
}

pkg_postinst() {
	# Restoring the original lapack settings.
	einfo "Restoring your original lapack settings with eselect"
	eselect lapack set ${OLD_IMPLEM}
}