#
# LinuxGSM ARK: Survival Evolved Dockerfile
#
# https://github.com/GameServerManagers/docker-gameserver
#

FROM gameservermanagers/linuxgsm:ubuntu-22.04
LABEL maintainer="LinuxGSM <me@danielgibbs.co.uk>"
ARG SHORTNAME=ark
ENV GAMESERVER=arkserver

WORKDIR /app

## Auto install game server requirements
RUN depshortname=$(curl --connect-timeout 10 -s https://raw.githubusercontent.com/GameServerManagers/LinuxGSM/master/lgsm/data/ubuntu-22.04.csv |awk -v shortname="ark" -F, '$1==shortname {$1=""; print $0}') \
  && if [ -n "${depshortname}" ]; then \
  echo "**** Install ${depshortname} ****" \
  && apt-get update \
  && apt-get install -y ${depshortname} \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
  && rm /data/config-lgsm/arkserver/_default.cfg \
  && wget https://raw.githubusercontent.com/gameguys919/unraidark/main/_default01.cfg -p /data/config-lgsm/arkserver/ \
  && mv /data/config-lgsm/arkserver/_default01.cfg /data/config-lgsm/arkserver/_default.cfg \
  && rm /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/GameUserSettings.ini \
  && wget https://raw.githubusercontent.com/gameguys919/unraidark/main/GameUserSettings01.ini -p /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/ \
  && wget https://raw.githubusercontent.com/gameguys919/unraidark/main/Game01.ini -p /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/ \
  && mv /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/GameUserSettings01.ini /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/GameUserSettings.ini \
  && mv /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/Game01.ini /data/serverfiles/ShooterGame/Saved/Config/LinuxServer/Game.ini \
  fi

HEALTHCHECK --interval=1m --timeout=1m --start-period=2m --retries=1 CMD /app/entrypoint-healthcheck.sh || exit 1

RUN date > /build-time.txt

ENTRYPOINT ["/bin/bash", "./entrypoint.sh"]
