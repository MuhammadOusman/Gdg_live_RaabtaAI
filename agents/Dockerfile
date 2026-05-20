FROM node:20-slim

# Install curl for easy debugging/health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --only=production

COPY . .

# Set dynamic port environment variable
ENV PORT=3000
EXPOSE 3000

CMD [ "node", "app.js" ]
