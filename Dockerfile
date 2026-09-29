FROM node:lts-trixie-slim AS base
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git wget ripgrep python3 build-essential \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable \
  && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

FROM base AS deps
WORKDIR /app
RUN git clone --depth 1 https://github.com/paperclipai/paperclip.git . \
  && pnpm install --no-frozen-lockfile

FROM base AS build
WORKDIR /app
COPY --from=deps /app /app
RUN pnpm --filter @paperclipai/ui build \
  && pnpm --filter @paperclipai/plugin-sdk build \
  && pnpm --filter @paperclipai/server build \
  && test -f server/dist/index.js

FROM base AS production
WORKDIR /app
COPY --from=build /app /app
RUN npm install -g @openai/codex@0.158.0 @anthropic-ai/claude-code@2.1.283 @google/gemini-cli@0.61.0
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssh-client jq gosu \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /paperclip \
  && usermod -d /paperclip node

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

ENV NODE_ENV=production \
  HOME=/paperclip \
  npm_config_cache=/tmp/.npm \
  XDG_CACHE_HOME=/tmp/.cache \
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
