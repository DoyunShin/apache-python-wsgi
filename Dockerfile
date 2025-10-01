ARG PYTHON_VERSION=3.13
FROM httpd:2.4.65 AS apache
FROM python:${PYTHON_VERSION} AS python

ENV MOD_WSGI_VERSION=5.0.2
ENV HTTPD_PREFIX=/usr/local/apache2
ENV PATH=/usr/local/apache2/bin:$PATH
WORKDIR $HTTPD_PREFIX


STOPSIGNAL SIGWINCH
COPY --from=apache /usr/local/apache2 /usr/local/apache2
COPY --from=apache /usr/local/bin/httpd-foreground /usr/local/bin/httpd-foreground

RUN set -eux; \
    apt-get update; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get install --update -y --no-install-recommends bzip2 dpkg-dev gcc gnupg libapr1-dev libaprutil1-dev libbrotli-dev libcurl4-openssl-dev libjansson-dev liblua5.2-dev libnghttp2-dev libpcre2-dev libssl-dev libxml2-dev make patch wget zlib1g-dev curl; \
    mkdir /usr/local/src/mod_wsgi -p; \
    cd /usr/local/src/mod_wsgi; \
    curl -L https://github.com/GrahamDumpleton/mod_wsgi/archive/refs/tags/$MOD_WSGI_VERSION.tar.gz | tar xz --strip-components=1; \
    ./configure --with-apxs=/usr/local/apache2/bin/apxs; \
    make -j $(nproc) && make install; \
    cd /usr/local/apache2/conf; \
    echo "LoadModule wsgi_module modules/mod_wsgi.so" >> httpd.conf; \
    echo "Include conf/sites/*.conf" >> httpd.conf; \
    mkdir sites; \
    touch sites/default.conf; \
    rm -rf /usr/local/src/mod_wsgi; \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | grep '^[^ ]*: /' \
        | cut -d: -f1 \
        | sort -u \
        | xargs -r apt-mark manual \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get dist-clean;

CMD ["httpd-foreground"]