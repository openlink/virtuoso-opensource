FROM debian:buster-slim as build

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    flex \
    bison \
    gperf \
    gawk \
    m4 \
    make \
    openssl \
    libssl-dev \
    libreadline-dev \
    iproute2 \
    net-tools \
    libmagickwand-dev \
    lzma-dev \
    libbz2-dev \
    libxml2-dev \
    libpcre3-dev \
    libldap2-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Check versions
# RUN autoconf --version \
#     && automake --version \
#     && libtoolize --version \
#     && flex --version \
#     && bison --version \
#     && gperf --version \
#     && gawk --version \
#     && m4 --version \
#     && make --version \
#     && openssl version

# Download virtuoso
WORKDIR /build
COPY . .

# Build
ENV LC_ALL=C.UTF-8
RUN ./autogen.sh
#ENV CFLAGS="-O2 -m64"
RUN ./configure --with-readline --prefix=/opt/virtuoso
RUN make -j $(nproc)
RUN make install

FROM debian:buster-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libreadline7 \
    iproute2 \
    libldap-2.4-2 \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Copy virtuoso
COPY --from=build /opt/virtuoso /opt/virtuoso
ENV PATH="/opt/virtuoso/bin:${PATH}"

VOLUME /data
WORKDIR /data
EXPOSE 8890
EXPOSE 1111

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD virtuoso-t +wait +foreground +configfile /opt/virtuoso/var/lib/virtuoso/db/virtuoso.ini

