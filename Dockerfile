FROM node:8.11.1-alpine

ENV PORT=80
ENV DB_CONNECTION_STRING=mongodb://admin_valerio:password_valerio@valerio-cloud-phoenix-kata.valeriodelsarto.it/valerio-cloud-phoenix-kata

RUN apk add --no-cache git

RUN mkdir /app && cd /app && git clone https://github.com/xpeppers/cloud-phoenix-kata.git

WORKDIR /app/cloud-phoenix-kata

RUN npm install

EXPOSE 80

CMD [ "npm", "start" ]