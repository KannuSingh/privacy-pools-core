FROM node:23 AS sdk-builder
WORKDIR /build
COPY ./package.json ./yarn.lock ./tsconfig.base.json .
COPY ./packages/sdk/package.json  ./packages/sdk/tsconfig.build.json ./packages/sdk/
RUN yarn install
COPY ./packages/sdk/configs/ ./packages/sdk/configs/
COPY ./packages/sdk/src/ ./packages/sdk/src/
RUN cd ./packages/sdk && yarn install && yarn build

FROM sdk-builder AS final
COPY ./packages/relayer/package.json ./packages/relayer/tsconfig.build.json ./packages/relayer/
RUN yarn install
COPY ./packages/relayer/src/ ./packages/relayer/src/
RUN cd ./packages/relayer && yarn install && yarn build
WORKDIR packages/relayer
EXPOSE 3000:3000
ENTRYPOINT ["node", "./dist/src/index.js"]
