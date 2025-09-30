zARG PYTHON_VERSION=3.13
FROM httpd:2.4.65 AS apache
FROM python:${PYTHON_VERSION} AS python

ENV MOD_WSGI_VERSION=5.0.2
ENV HTTPD_PREFIX=/usr/local/apache2
ENV PATH=/usr/local/apache2/bin:$PATH
WORKDIR $HTTPD_PREFIX

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates libaprutil1-ldap libldap-common bzip2 dpkg-dev gcc gnupg libapr1-dev libaprutil1-dev libbrotli-dev libcurl4-openssl-dev libjansson-dev liblua5.2-dev  libnghttp2-dev libpcre3-dev libssl-dev libxml2-dev make patch zlib1g-dev curl && \
    apt-get install -y --no-install-recommends wireguard-tools iptables iproute2 sudo && \
	rm -rf /var/lib/apt/lists/*

STOPSIGNAL SIGWINCH
COPY --from=apache /usr/local/apache2 /usr/local/apache2
COPY --from=apache /usr/local/bin/httpd-foreground /usr/local/bin/httpd-foreground

RUN mkdir /usr/local/src/mod_wsgi -p && \
    cd /usr/local/src/mod_wsgi && \
    curl -L https://github.com/GrahamDumpleton/mod_wsgi/archive/refs/tags/$MOD_WSGI_VERSION.tar.gz | tar xz --strip-components=1 && \
    ./configure --with-apxs=/usr/local/apache2/bin/apxs && \
    make -j $(nproc) && make install && \
    cd /usr/local/apache2/conf && \
    echo "LoadModule wsgi_module modules/mod_wsgi.so" >> httpd.conf && \
    echo "Include conf/sites/*.conf" >> httpd.conf && \
    mkdir sites && \
    rm -rf /usr/local/src/mod_wsgi

CMD ["httpd-foreground"]