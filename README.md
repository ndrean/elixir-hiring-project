# Fly.io Elixir Hiring Project

## General

Generated a new project since the "official" one used webpack.

Locally, use `libcluster` and `dns_cluster` on Fly.io.

To **deploy** this on Fly.io, a central SQLite is used on a node labelled "PRIMARY_REGION" where every write/read is made.

Project achieved in 7h.

Usage:

```bash
PORT=4000 FLY_REGION=ord iex --sname "a" --cookie secret -S mix phx.server
PORT=4001 FLY_REGION=cdg iex --sname "b" --cookie secret -S mix phx.server
...
```

## Additions - changes

`Libcluster` with "localEPDM" to cluster the nodes.

An SQLITE DB for persistence with a unique table COUNTER, with two records: `region`, `count`.

For the deployment, a primary node is defined where every write/read is made. Done via `:erpc.call` (could not made `liteFS` work).

Every change of the GenServer state is saved in the database.

On mount, the socket state is populated by reading the DB and broadcasted to update users view.

On leave, the state is updated

## Fly.io

```bash
# stop when you have to deploy
fly launch
# remove release_command from fly.toml
fly consul attach
fly deploy
```

```bash
#env.sh.eex
ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
export RELEASE_DISTRIBUTION="name"
export RELEASE_NODE=$FLY_APP_NAME@$ip
```

```dockerfile
#Dockerfile - Debian based.
{RUNNER}
apt-get install fuse
RUN apt-get install ca-certificates fuse3...
COPY --from=flyio/litefs:0.5 /usr/local/bin/litefs /usr/local/bin/litefs
COPY litefs.yml /etc/litefs.yml

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/liveview_counter ./
# USER nobody
ENV ECTO_IPV6 true
ENV ERL_AFLAGS "-proto_dist inet6_tcp"
ENTRYPOINT litefs mount
```

```elixir
def start(_type, _args) do
    MyApp.Release.migrate()
    children = [ {DNSCluster, query: System.get_env("DNS_CLUSTER_QUERY") || :ignore},...]
```

```elixir
#config/runtime.exs
  config :my_app, dns_cluster_query: System.get_env("DNS_CLUSTER_QUERY")
```

```yml
#litejs.yml
fuse:
  # This is the mount directory that applications will use to access their SQLite databases.
  dir: "/data/mydata"

data:
  # path to internal data storage
  dir: "/data/litefs"

proxy:
  addr: ":8081"
  target: "localhost:8080"
  #  SQLite database filename
  db: "my_app_prod.db"
  passthrough:
    - "*.ico"
    - "*.png"

exec:
  - cmd: "/app/bin/server -addr :8080 -dsn /data/mydata" <- ??

lease:
  type: "consul"
  advertise-url: "http://${HOSTNAME}.vm.${FLY_APP_NAME}.internal:20202"
  candidate: ${FLY_REGION == PRIMARY_REGION}
  promote: true

  consul:
    url: "${FLY_CONSUL_URL}"
    key: "litefs/${FLY_APP_NAME}"
```

```toml
#fly.toml
primary_region="cdg"
#[deploy] release_command = "/app/bin/migrate"

[mounts]
source="mydata"
destination="/data"

[env]
PHX_HOST = "my-app.fly.dev"
DNS_CLUSTER_QUERY="my-app.internal"
DATABASE_PATH="/data/mydata/my_app_prod.db"
PORT="8080"
```

```bash
> fly ssh console -s -C df
Connecting to fdaa:0:57e6:a7b:aebf:700a:d1cb:2... complete
Filesystem     1K-blocks   Used Available Use% Mounted on
devtmpfs           98380      0     98380   0% /dev
/dev/vda         8154588 681300   7037476   9% /
shm               111340      0    111340   0% /dev/shm
tmpfs             111340      0    111340   0% /sys/fs/cgroup
/dev/vdb         1009132     40    940484   1% /data
litefs           1009132     40    940484   1% /data/mydat
```

```bash
>fly status
Machines
PROCESS	ID            	VERSION	REGION	STATE  	ROLE   	CHECKS	LAST UPDATED
app    	1857507c2dd2d8	6      	cdg   	started	primary	      	2023-10-30T10:23:42Z

>fly volumes list
ID                  	STATE  	NAME  	SIZE	REGION	ZONE	ENCRYPTED	ATTACHED VM   	CREATED AT
vol_0vdg0y9n18e9lq6v	created	mydata	1GB 	cdg   	9937	true     	1857507c2dd2d8	34 minutes ago
vol_p4m9pjpy6emn7x1v	created	litefs	1GB 	cdg   	c49c	true     	              	17 minutes ago

>fly ssh console -s -C df
Filesystem     1K-blocks   Used Available Use% Mounted on
devtmpfs           98380      0     98380   0% /dev
/dev/vda         8154588 681364   7037412   9% /
shm               111340      0    111340   0% /dev/shm
tmpfs             111340      0    111340   0% /sys/fs/cgroup
/dev/vdb          997076     40    929044   1% /data
litefs            997076     40    929044   1% /data/mydata
```
