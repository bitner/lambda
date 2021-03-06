FROM lambci/lambda:build-python3.6 as builder

ARG http_proxy
ARG CURL_VERSION=7.63.0
ARG GDAL_VERSION=2.4.0
ARG GEOS_VERSION=3.7.1
ARG PROJ_VERSION=5.1.0
ARG LASZIP_VERSION=3.2.9
ARG GEOTIFF_VERSION=1.4.3
ARG PDAL_VERSION=1.8.0
ARG DESTDIR="/build"
ARG PREFIX="/usr"

RUN \
  rpm --rebuilddb && \
  yum makecache fast && \
  yum install -y \
    automake16 \
    libpng-devel \
    nasm wget tar gcc zlib-devel gcc-c++ curl-devel zip libjpeg-devel rsync git ssh bzip2 automake \
        glib2-devel libtiff-devel pkg-config libcurl-devel;   # required for pkg-config

RUN \
    wget https://github.com/Kitware/CMake/releases/download/v3.13.2/cmake-3.13.2.tar.gz; \
    tar -zxvf cmake-3.13.2.tar.gz; \
    cd cmake-3.13.2; \
    ./bootstrap --prefix=/usr ;\
    make ;\
    make install DESTDIR=/


RUN \
    wget https://github.com/LASzip/LASzip/releases/download/$LASZIP_VERSION/laszip-src-$LASZIP_VERSION.tar.gz; \
    tar -xzvf laszip-src-$LASZIP_VERSION.tar.gz; \
    cd laszip-src-$LASZIP_VERSION;\
    cmake -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_STATIC_LIBS=OFF \
        -DCMAKE_INSTALL_LIBDIR=lib \
    ; \
    make; make install; make install DESTDIR= ; cd ..; \
    rm -rf laszip-src-${LASZIP_VERSION} laszip-src-$LASZIP_VERSION.tar.gz;

RUN \
    wget http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2; \
    tar xjf geos*bz2; \
    cd geos*; \
    ./configure --prefix=$PREFIX CFLAGS="-O2 -Os"; \
    make; make install; make install DESTDIR= ;\
    cd ..; \
    rm -rf geos*;

RUN \
    wget http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz; \
    tar -zvxf proj-$PROJ_VERSION.tar.gz; \
    cd proj-$PROJ_VERSION; \
    ./configure --prefix=$PREFIX; \
    make; make install; make install DESTDIR=; cd ..; \
    rm -rf proj-$PROJ_VERSION proj-$PROJ_VERSION.tar.gz

RUN \
    wget https://download.osgeo.org/geotiff/libgeotiff/libgeotiff-$GEOTIFF_VERSION.tar.gz; \
    tar -xzvf libgeotiff-$GEOTIFF_VERSION.tar.gz; \
    cd libgeotiff-$GEOTIFF_VERSION; \
    ./configure \
        --prefix=$PREFIX --with-proj=/build/usr ;\
    make; make install; make install DESTDIR=; cd ..; \
    rm -rf libgeotiff-$GEOTIFF_VERSION.tar.gz libgeotiff-$GEOTIFF_VERSION;

# GDAL
RUN \
    wget http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz; \
    tar -xzvf gdal-$GDAL_VERSION.tar.gz; \
    cd gdal-$GDAL_VERSION; \
    ./configure \
        --prefix=$PREFIX \
        --with-geotiff=$DESTDIR/usr \
        --with-tiff=/usr \
        --with-curl=yes \
        --without-python \
        --with-geos=$DESTDIR/usr/bin/geos-config \
        --with-hide-internal-symbols=yes \
        CFLAGS="-O2 -Os" CXXFLAGS="-O2 -Os"; \
    make ; make install; make install DESTDIR= ; \
    cd $BUILD; rm -rf gdal-$GDAL_VERSION*

RUN \
    git clone https://github.com/PDAL/PDAL.git; \
    cd PDAL; \
    mkdir -p _build; \
    cd _build; \
    cmake .. \
        -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="-std=c++11" \
        -DCMAKE_MAKE_PROGRAM=make \
        -DBUILD_PLUGIN_I3S=ON \
        -DWITH_LASZIP=ON \
        -DCMAKE_LIBRARY_PATH:FILEPATH="$DESTDIR/usr/lib" \
        -DCMAKE_INCLUDE_PATH:FILEPATH="$DESTDIR/usr/include" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DWITH_TESTS=OFF \
        -DCMAKE_INSTALL_LIBDIR=lib \
    ; \
    make ; make install; make install DESTDIR= ;

RUN rm /build/usr/lib/*.la ; rm /build/usr/lib/*.a
RUN ldconfig
ADD package-pdal.sh /

