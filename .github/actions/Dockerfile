FROM squidfunk/mkdocs-material:8.4.4

RUN apk add --no-cache --update nodejs npm
RUN pip install mkdocs -r requirements.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
