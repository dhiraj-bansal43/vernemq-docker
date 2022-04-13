FROM erlang:23.3.2-alpine as build

RUN apk --no-cache --update --available upgrade 
RUN apk add snappy-dev git make gcc musl-dev curl patch g++ bsd-compat-headers openssl-dev
#RUN git clone --depth 1 --branch 1.12.3 https://github.com/vernemq/vernemq.git
RUN git clone https://github.com/vernemq/vernemq.git
WORKDIR /vernemq
RUN make rel

FROM alpine:3.14 as runtime

RUN apk --no-cache --update --available upgrade && \
    apk add --no-cache ncurses-libs openssl libstdc++ jq curl bash snappy-dev && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 -H -D -G vernemq -h /vernemq vernemq && \
    install -d -o vernemq -g vernemq /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH" \
    VERNEMQ_VERSION="1.14.0" 

WORKDIR /vernemq

COPY --chown=10000:10000 vernemq.sh /usr/sbin/start_vernemq
COPY --chown=10000:10000 vm.args /vernemq/etc/vm.args
COPY --from=build --chown=10000:10000 /vernemq/_build/default/rel/vernemq .

RUN ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109


VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq
CMD ["start_vernemq"]
