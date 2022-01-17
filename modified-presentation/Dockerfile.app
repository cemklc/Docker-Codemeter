FROM  bitnami/minideb:stretch

LABEL description="Customer application image"

# default CodeMeter server container name.
ENV CODEMETER_HOST ""

# copy needed CodeMeter libraries
COPY deb/CodeMeter/usr/lib /usr/lib

# copy needed AxProtector libraries
COPY deb/AxProtector/usr/lib /usr/lib

# copy client protected application.
COPY data/go /app/go

WORKDIR /app
CMD ["/app/go"]







