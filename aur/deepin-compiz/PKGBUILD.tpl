# Maintainer: Xu Fasheng <fasheng.xu[AT]gmail.com>
# Contributor: Ryon Sherman <ryon.sherman@gmail.com>
# Contributor: Iven Hsu <ivenvd AT gmail>
# Contributor: Nathan Hulse <nat.hulse@gmail.com>

pkgname=deepin-compiz
pkgver=0.9.8_{% pkgver %}
pkgrel=1
pkgdesc='A forked compiz for Linux Deepin desktop environment'
arch=('i686' 'x86_64')
license=('GPL' 'LGPL' 'MIT')
url="http://www.linuxdeepin.com/"
depends=('boost' 'xorg-server' 'libxcomposite' 'startup-notification' 'librsvg' 'dbus' 'mesa' 'libxslt' 'fuse' 'glibmm' 'libxrender' 'gmock' 'libwnck' 'pygtk' 'desktop-file-utils' 'pyrex' 'protobuf' 'dconf' 'gtk2')
makedepends=('intltool' 'cmake')
provides=('compiz=0.9')
conflicts=('compiz-bzr' 'compiz-core' 'compiz-fusion-plugins-main' 'compiz-fusion-plugins-extra' 'compiz-decorator-gtk' 'compiz-decorator-kde' 'libcompizconfig' 'compizconfig-python' 'compizconfig-backend-gconf' 'compiz-bcop' 'ccsm')
replaces=('compiz-bzr' 'compiz-core' 'compiz-fusion-plugins-main' 'compiz-fusion-plugins-extra' 'compiz-decorator-gtk' 'compiz-decorator-kde' 'libcompizconfig' 'compizconfig-python' 'compizconfig-backend-gconf' 'compiz-bcop' 'ccsm')
install='compiz.install'

_fileurl={% fileurl %}
source=("${_fileurl}"
    "fix-boost-interfaces.patch")
md5sums=('{% md5 %}'
    'fb78a696aaabc856de3aeef98202a0d7')

_filename="$(basename "${_fileurl}")"
_filename="${_filename%-*.tar.gz}"
_innerdir="${_filename/_/-}"

prepare() {
    cd "${srcdir}/${_innerdir}"

    export PYTHON="/usr/bin/python2"

    find -type f \( -name 'CMakeLists.txt' -or -name '*.cmake' \) -exec sed -e 's/COMMAND python/COMMAND python2/g' -i {} \;
    find compizconfig/ccsm -type f -exec sed -e 's|^#!.*python|#!/usr/bin/env python2|g' -i {} \;

    patch -p1 < ../fix-boost-interfaces.patch

    mkdir build; cd build
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DPYTHON_INCLUDE_DIR=/usr/include/python2.7 \
        -DPYTHON_LIBRARY=/usr/lib/libpython2.7.so \
        -DCMAKE_BUILD_TYPE="Release" \
        -DQT_QMAKE_EXECUTABLE=qmake-qt4 \
        -DCOMPIZ_DISABLE_SCHEMAS_INSTALL=On \
        -DCOMPIZ_BUILD_WITH_RPATH=Off \
        -DCOMPIZ_PACKAGING_ENABLED=On \
        -DBUILD_GTK="on" \
        -DBUILD_METACITY="off" \
        -DBUILD_KDE4="off" \
        -DUSE_GCONF="on" \
        -DUSE_GSETTINGS="on" \
        -DCOMPIZ_BUILD_TESTING=Off \
        -DCOMPIZ_WERROR=Off \
        -DCOMPIZ_DEFAULT_PLUGINS="composite,opengl,decor,resize,place,move"
}

build() {
    cd "${srcdir}/${_innerdir}/build"
    make
}

package() {
    cd "${srcdir}/${_innerdir}/build"
    make DESTDIR="${pkgdir}" install

    # Stupid findcompiz_install needs COMPIZ_DESTDIR and install needs DESTDIR
    # make findcompiz_install
    CMAKE_DIR=$(cmake --system-information | grep '^CMAKE_ROOT' | awk -F\" '{print $2}')
    install -dm755 "${pkgdir}${CMAKE_DIR}/Modules/"
    install -m644 ../cmake/FindCompiz.cmake "${pkgdir}${CMAKE_DIR}/Modules/"

    # Add documentation
    install -dm755 "${pkgdir}/usr/share/doc/compiz/"
    install ../{AUTHORS,NEWS,README} "${pkgdir}/usr/share/doc/compiz/"

    # Amend XDG .desktop file to load the compizconfig plugin with compiz
    sed -i 's/Exec\=compiz/Exec\=compiz ccp/' "${pkgdir}/usr/share/applications/compiz.desktop"

    # Merge the gconf schema files
    if [ -d "${pkgdir}/usr/share/gconf/schemas" ]; then
        gconf-merge-schema "${pkgdir}/usr/share/gconf/schemas/compiz.schemas.in" "{$pkgdir}"/usr/share/gconf/schemas/*.schemas
        sed -i '/<schemalist\/>/d' "${pkgdir}/usr/share/gconf/schemas/compiz.schemas.in"
        rm -f "${pkgdir}"/usr/share/gconf/schemas/*.schemas
        mv "${pkgdir}/usr/share/gconf/schemas/compiz.schemas.in" "${pkgdir}/usr/share/gconf/schemas/compiz.schemas"
    fi

    # Add the pesky gsettings schema files manually
    if ls generated/glib-2.0/schemas/ | grep -qm1 .gschema.xml; then
        install -dm755 "${pkgdir}/usr/share/glib-2.0/schemas/"
        install -m644 generated/glib-2.0/schemas/*.gschema.xml "${pkgdir}/usr/share/glib-2.0/schemas/"
    fi
}