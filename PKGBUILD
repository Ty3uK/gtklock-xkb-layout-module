pkgname=gtklock-xkb-layout-module
pkgver=1.0.1
pkgrel=1
pkgdesc="gtklock module to display current keyboard layout on a lock-screen"
url="https://github.com/Ty3uK/gtklock-xkb-layout-module"
arch=('x86_64')
license=('GPL-3.0-only')
depends=('gtk3' 'gtklock' 'wayland' 'libxkbcommon')
makedepends=('zig')
source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('985278d3c29a9a7f6bce3e04427518f116369eccdea7005baa4c3fcec3132251')
_archive="$pkgname-$pkgver"

build() {
    cd "${srcdir}/$_archive"
    zig build --release=small
}

package() {
    mkdir -p "${pkgdir}/usr/lib/gtklock"
    cp -a "${srcdir}/$_archive/zig-out/lib/xkb-layout-module.so" "${pkgdir}/usr/lib/gtklock/"
}
