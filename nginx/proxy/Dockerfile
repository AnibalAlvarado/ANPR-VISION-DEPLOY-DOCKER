FROM ubuntu:22.04
RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*
COPY conf.d /etc/nginx/conf.d
COPY certs /etc/nginx/certs
# webroot en /var/www/certbot se monta por volumen desde ./nginx/html
CMD ["nginx", "-g", "daemon off;"]
