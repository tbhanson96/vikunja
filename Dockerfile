# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM docker.io/library/node:24.18.0-alpine AS frontendbuilder

WORKDIR /build

ENV PNPM_CACHE_FOLDER=.cache/pnpm/
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV CYPRESS_INSTALL_BINARY=0

COPY frontend/pnpm-lock.yaml frontend/package.json frontend/.npmrc ./
RUN npm install -g corepack && corepack enable && \
    pnpm install --frozen-lockfile

COPY frontend/ ./

ARG RELEASE_VERSION=dev
RUN echo "{\"VERSION\": \"${RELEASE_VERSION/-g/-}\"}" > src/version.json && pnpm run build

FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.26-alpine AS apibuilder

RUN apk add --no-cache build-base ca-certificates git nodejs npm && \
    go install github.com/magefile/mage@latest

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . ./
COPY --from=frontendbuilder /build/dist ./frontend/dist

ARG TARGETOS
ARG TARGETARCH
ARG RELEASE_VERSION=dev

ENV CGO_ENABLED=1
ENV GOOS=${TARGETOS}
ENV GOARCH=${TARGETARCH}
ENV RELEASE_VERSION=${RELEASE_VERSION}
ENV PATH=/root/go/bin:${PATH}

RUN mage build

FROM docker.io/library/alpine:3.22

LABEL org.opencontainers.image.authors="maintainers@vikunja.io"
LABEL org.opencontainers.image.url="https://vikunja.io"
LABEL org.opencontainers.image.documentation="https://vikunja.io/docs"
LABEL org.opencontainers.image.source="https://github.com/tbhanson96/vikunja"
LABEL org.opencontainers.image.licenses="AGPLv3"
LABEL org.opencontainers.image.title="Vikunja"

WORKDIR /app/vikunja
ENTRYPOINT ["/app/vikunja/vikunja"]
EXPOSE 3456

RUN apk add --no-cache ca-certificates
COPY --from=apibuilder /src/vikunja /app/vikunja/vikunja

USER 1000

ENV VIKUNJA_SERVICE_ROOTPATH=/app/vikunja/
ENV VIKUNJA_DATABASE_PATH=/db/vikunja.db
