FROM postgres:15-alpine AS postgres

FROM hexpm/elixir:1.17.2-erlang-27.0.1-alpine-3.20.2

COPY --from=postgres /usr/local/bin/pg_dump /usr/local/bin/pg_dump