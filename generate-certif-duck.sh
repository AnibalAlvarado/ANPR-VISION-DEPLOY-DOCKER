docker run --rm \
  -v "$(pwd)"/letsencrypt:/etc/letsencrypt \
  -v "$(pwd)"/nginx/html:/var/www/certbot \
  certbot/certbot certonly --webroot \
  -w /var/www/certbot \
  -d anprvision.duckdns.org \
  --agree-tos -m anprvision@gmail.com --non-interactive

