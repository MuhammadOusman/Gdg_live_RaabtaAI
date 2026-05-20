FROM node:22-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --only=production

COPY . .

EXPOSE 8080

CMD [ "node", "app.js" ]