#!/bin/bash

docker rm -f resty-limit
docker build -t nekocode/resty-limit:latest .
docker run -d -p 8080:80 --name resty-limit -e RATE_LIMIT=false nekocode/resty-limit:latest
