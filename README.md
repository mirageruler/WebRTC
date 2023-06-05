# pion-to-pion
pion-to-pion is an example of two pion instances communicating directly!

The SDP offer and answer are exchanged automatically over HTTP.
The `answer` side acts like a HTTP server and should therefore be ran first.

## Instructions
make answer
```
Next, run `offer`:
make offer
```

You should see them connect and start to exchange messages.

## You can use Docker-compose to start this example:
```sh
docker-compose up -d
```

Now, you can see message exchanging, using `docker logs`.

RUN apk update \
 && apk add --no-cache \
        ca-certificates cmake g++ git make \
 && update-ca-certificates \
 && apk add vim