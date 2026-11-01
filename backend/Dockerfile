FROM alpine:3.23@sha256:ff7f0c727dd796aa36787bfcd9a64bf35a6ce72a73451b3359fde849b6703d63 AS download

ARG TARGETARCH
ARG TARGETVARIANT

RUN apk add --no-cache ca-certificates curl unzip
RUN set -eu; \
    case "${TARGETARCH}/${TARGETVARIANT}" in \
      amd64/) platform=linux_amd64; checksum=7504ec99a85fe405fc9941b4d94bdea20733b53707c8251b66fd0daa1444347e ;; \
      arm64/|arm64/v8) platform=linux_arm64; checksum=341a249f97f4ff1ba8dfff81d357eb281cd346fbddae8b6ea43193f0647e036d ;; \
      arm/v7) platform=linux_armv7; checksum=c04fd7d05323efdb0c7a55e46e4aa0e8f69203b10604d17e350b30c6e5528ec9 ;; \
      *) printf 'Plataforma PocketBase não suportada.\n' >&2; exit 1 ;; \
    esac; \
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
      "https://ganigeorgiev.com/meta/pocketbase/pocketbase/download/v0.41.1/pocketbase_0.41.1_${platform}.zip" \
      --output /tmp/pocketbase.zip; \
    printf '%s  %s\n' "$checksum" /tmp/pocketbase.zip | sha256sum -c -; \
    unzip /tmp/pocketbase.zip pocketbase -d /out

FROM alpine:3.23@sha256:ff7f0c727dd796aa36787bfcd9a64bf35a6ce72a73451b3359fde849b6703d63

RUN apk add --no-cache ca-certificates \
    && addgroup -g 10001 pocketbase \
    && adduser -D -H -u 10001 -G pocketbase pocketbase \
    && mkdir -p /pb/pb_data /opt/cordato/no-hooks /opt/cordato/no-public \
    && chown 10001:10001 /pb/pb_data

COPY --from=download --chmod=0555 /out/pocketbase /usr/local/bin/pocketbase
COPY --chmod=0444 pb_migrations/ /opt/cordato/migrations/
RUN find /opt/cordato/migrations -type d -exec chmod 0555 {} +
COPY --chmod=0555 docker/entrypoint.sh /usr/local/bin/cordato-entrypoint

RUN test "$(pocketbase --version)" = 'pocketbase version 0.41.1'

ENV TZ=UTC
WORKDIR /pb
USER 10001:10001
EXPOSE 8090
ENTRYPOINT ["/usr/local/bin/cordato-entrypoint"]
