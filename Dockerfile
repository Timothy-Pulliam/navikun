FROM node:20.11.1-alpine AS builder
WORKDIR /usr/src/app
# copy app source code and set permissions
COPY --chown=node:node . .
# building for production
RUN npm ci --only=production
EXPOSE 8080/tcp
# start process as node user
USER node
ENV NODE_ENV production
# node is not designed to run as PID 1, use dumb init to start node
CMD [ "npm", "run", "start" ]