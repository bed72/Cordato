FROM nodered/node-red:5.0.9-24@sha256:2ccd38b4066648bd5e17430c50a2f8102c566a82fd4f2fc5c342e61664d6896f

COPY --chmod=0444 settings.js flows.json /opt/cordato/
COPY --chmod=0555 docker/entrypoint.sh /opt/cordato/entrypoint.sh

ENV TZ=UTC
USER node-red
EXPOSE 1880
ENTRYPOINT ["/opt/cordato/entrypoint.sh"]
