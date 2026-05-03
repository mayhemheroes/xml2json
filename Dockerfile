# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 AS builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y g++ make

## Add source code to the build stage.
ADD . /xml2json
WORKDIR /xml2json

## TODO: ADD YOUR BUILD INSTRUCTIONS HERE.
RUN make

# Package Stage
FROM --platform=linux/amd64 ubuntu:20.04

## TODO: Change <Path in Builder Stage>
COPY --from=builder /xml2json/xml2json /

