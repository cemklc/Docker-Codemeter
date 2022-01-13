FROM  customer/app_base:latest

LABEL description="Customer client application image"

# default CodeMeter server container name.
ENV CODEMETER_HOST ""

# copy client protected application.
COPY data/go /app/go

WORKDIR /app
CMD ["/app/go"]
