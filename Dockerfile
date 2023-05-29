# Start by building the application.
FROM node:18-buster-slim as pre-build
WORKDIR /app

COPY . .

RUN npm ci

FROM node:18-buster-slim as lint
WORKDIR /app

COPY . .
COPY --from=pre-build /app/node_modules /app/node_modules

RUN npm run lint

FROM node:18-buster-slim as test
WORKDIR /app
ARG CHROME_VERSION="google-chrome-stable"

COPY . .
COPY --from=pre-build /app/node_modules /app/node_modules
COPY --from=busybox:1.35.0-uclibc /bin/wget /bin/wget
RUN apt-get update && apt-get install -y gnupg2
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update -qqy \
  && apt-get -qqy install \
    ${CHROME_VERSION:-google-chrome-stable} \
  && rm /etc/apt/sources.list.d/google-chrome.list \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*
RUN npm test -- --browsers ChromeHeadlessNoSandbox


FROM node:18-buster-slim as build
WORKDIR /app

COPY . .
COPY --from=pre-build /app/node_modules /app/node_modules

RUN npm run build-storybook --prod


FROM nginx:1.22.1
WORKDIR /usr/share/nginx/html
RUN echo "types { application/javascript js mjs; }" > /etc/nginx/conf.d/mjs.conf
COPY --chown=nginx:nginx --from=build /app/storybook-static /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]