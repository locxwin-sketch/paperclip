FROM node:lts-trixie-slim AS base
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git wget ripgrep python3 \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable

FROM base AS deps
WORKDIR /app
RUN git clone --depth 1 https://github.com/paperclipai/paperclip.git . \
  && pnpm install --frozen-lockfile

FROM base AS build
WORKDIR /app
COPY --from=deps /app /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential \
  && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
RUN pnpm --filter @paperclipai/ui build \
  && pnpm --filter @paperclipai/plugin-sdk build \
  && pnpm --filter @paperclipai/server build \
  && test -f server/dist/index.js

FROM base AS production
WORKDIR /app
COPY --from=build /app /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssh-client jq gosu \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /paperclip

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

ENV NODE_ENV=production \
  HOME=/paperclip \
  HOST=0.0.0.0 \
  PORT=3100 \
  SERVE_UI=true \
  PAPERCLIP_HOME=/paperclip \
  PAPERCLIP_INSTANCE_ID=default \
  PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
  PAPERCLIP_DEPLOYMENT_MODE=authenticated \
  PAPERCLIP_DEPLOYMENT_EXPOSURE=public

EXPOSE 3100

CMD ["start.sh"]
