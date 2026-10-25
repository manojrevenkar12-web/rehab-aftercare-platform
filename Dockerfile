# syntax=docker/dockerfile:1
# One image: the Rails API, the jobs worker (same image, `bin/jobs`) and the built console in public/.

FROM node:22-slim AS console
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
ARG VITE_DEMO=0
RUN VITE_DEMO=$VITE_DEMO npm run build

FROM ruby:3.3.6-slim AS gems
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev git libyaml-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development:test" BUNDLE_PATH=/usr/local/bundle
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/ruby/*/cache
COPY . .
RUN bundle exec bootsnap precompile app/ lib/

FROM ruby:3.3.6-slim
RUN apt-get update -qq && apt-get install -y --no-install-recommends libpq5 curl libyaml-0-2 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development:test" BUNDLE_PATH=/usr/local/bundle \
    RAILS_LOG_TO_STDOUT=1
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --from=gems /app /app
COPY --from=console /web/dist/ /app/public/
RUN rm -rf web node_modules spec evals reports tmp/* log/* && mkdir -p tmp/pids log \
 && useradd --create-home --uid 1000 app && chown -R app:app tmp log db
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -fs http://localhost:3000/up || exit 1
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
