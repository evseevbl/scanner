FROM akorn/luarocks:lua5.1-alpine
RUN apk add gcc musl-dev linux-headers
RUN luarocks install redis-lua
