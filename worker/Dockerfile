FROM nodered/node-red:5.0.9-24@sha256:2ccd38b4066648bd5e17430c50a2f8102c566a82fd4f2fc5c342e61664d6896f

USER root

COPY --chmod=0444 settings.js flows.json /opt/cordato/
COPY --chmod=0555 docker/entrypoint.sh /opt/cordato/entrypoint.sh
COPY --chmod=0444 flows/audio/audio.js /opt/cordato/flows/audio/audio.js

RUN chmod 0755 /opt /opt/cordato \
    /opt/cordato/flows /opt/cordato/flows/audio \
    && chmod 0555 /opt/cordato/entrypoint.sh

ENV TZ=UTC
USER node-red

RUN test -r /opt/cordato/settings.js \
    && test -r /opt/cordato/flows/audio/audio.js \
    && test -r /opt/cordato/flows.json \
    && test -r /opt/cordato/entrypoint.sh \
    && test -x /opt/cordato/entrypoint.sh

EXPOSE 1880
ENTRYPOINT ["/opt/cordato/entrypoint.sh"]
