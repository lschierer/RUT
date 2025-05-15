FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
COPY . /app
WORKDIR /app

FROM base AS prod-deps
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --recursive --prod --frozen-lockfile

FROM perl
WORKDIR /opt/schierer.org

# Copy the frontend application
COPY ./packages/frontend ./
COPY --from=prod-deps /app/node_modules ./node_modules
# Copy infrastructure files (if needed)
COPY ./packages/infrastructure ./infrastructure/

# Install dependencies from the frontend directory
#RUN cpanm --installdeps -n .
RUN ./bin/perldeps.sh

EXPOSE 3000
CMD ./schierer.org.pl prefork
