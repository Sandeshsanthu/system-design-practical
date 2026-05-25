FROM nginx:alpine

# Clear default configs and clear landing pages
RUN rm -rf /etc/nginx/conf.d/default.conf /usr/share/nginx/html/*

# Copy your custom configurations and front-end code assets
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./frontend /usr/share/nginx/html

# FIXED: Replaces the hidden root-owned pid reference with a writable /tmp/ path
RUN sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf && \
    chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
