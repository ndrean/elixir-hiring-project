# Fly.io Elixir Hiring Project

## General

Generated a new project since the "official" one used webpack.

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

Every change of the GenServer state is saved in the database.

On mount, the socket state is populated by reading the DB and broadcasted to update users view.

On leave, the state is updated
