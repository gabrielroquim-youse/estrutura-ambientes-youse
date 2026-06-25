FROM nginx:alpine

# Copia HTMLs estáticos
COPY html/ /usr/share/nginx/html/

# Template de nginx.conf processado por envsubst no boot
# (variaveis: PREVIEW_ID, ORDER_SERVICE_HOST)
COPY default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80
