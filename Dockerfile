FROM golang:1.18-alpine as builder
RUN mkdir /build
WORKDIR /build
COPY . .

ENV GOOS=linux GOARCH=arm64 CGO_ENABLED=0
RUN go install -v ./...

FROM alpine:3.15

RUN apk update && \
    apk add --no-cache \
    ca-certificates \
    openssl-dev

WORKDIR /
COPY --from=builder /go/bin/* /usr/bin/
