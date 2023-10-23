FROM node:18

WORKDIR /usr/app

COPY . /usr/app
ADD ./flow.json flow.json

EXPOSE 8888
EXPOSE 3569
EXPOSE 8701

RUN chmod +x /usr/app/start.sh

CMD ["./start.sh"]