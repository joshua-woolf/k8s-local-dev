FROM node:20.11-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

FROM node:20.11-alpine

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .

USER node
EXPOSE 3000
CMD ["npm", "start"]
