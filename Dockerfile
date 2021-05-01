FROM crystallang/crystal:1.0.0

# Install Dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y --no-install-recommends libpq-dev libsqlite3-dev libmysqlclient-dev libreadline-dev git curl vim netcat

WORKDIR /opt/micrate

# Build Amber
ENV PATH /opt/micrate/bin:$PATH
COPY . /opt/micrate
RUN shards build micrate

CMD ["micrate", "up"]
