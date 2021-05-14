# **** Prepare build stage ****
FROM alpine:latest as build
RUN apk update &&\
    apk upgrade &&\ 
    apk add --no-cache linux-headers alpine-sdk cmake tcl openssl-dev zlib-dev bash wget unzip
	
# **** Get srt and fixed sls from github ****
WORKDIR /tmp
RUN git clone https://github.com/gamerdf/srt-live-server.git

ARG commit_hash=1.4.3
RUN wget --no-check-certificate -O master.zip https://github.com/Haivision/srt/archive/refs/tags/v${commit_hash}.zip && \
unzip ./master.zip && \
ls -ls && \
rm ./master.zip && \
mv srt-${commit_hash} srt

# **** Make SRT ****
WORKDIR /tmp/srt
RUN ./configure && make && make install

# **** Make SLS ****
WORKDIR /tmp/srt-live-server
RUN make

# **** Build final image ****
FROM alpine:latest
ENV LD_LIBRARY_PATH /lib:/usr/lib:/usr/local/lib64
RUN apk update &&\
    apk upgrade &&\
    apk add --no-cache openssl cmake libressl-dev bash tcl supervisor libstdc++ nano htop &&\
    mkdir -p /etc/srt &&\
    mkdir -p /etc/srt/logs &&\
    mkdir -p /var/log/supervisor
	
# **** Copy SRT apps to local ****
COPY --from=build /usr/local/bin/srt-* /usr/local/bin/
COPY --from=build /usr/local/lib64/libsrt* /usr/local/lib64/
COPY --from=build /tmp/srt-live-server/bin/* /usr/local/bin/

# **** Mapping Volume ****
VOLUME /etc/srt/logs

# **** Copy default settings ****
COPY sls.conf /etc/srt/sls.conf
COPY supervisord.conf /etc/srt/supervisord.conf

# **** Mapping ports ****
EXPOSE 8000:8000/udp

# **** Start ****
CMD ["/usr/bin/supervisord", "-s", "-c", "/etc/srt/supervisord.conf"]
