FROM nginx:alpine

# Clear the default landing page template
RUN rm -rf /etc/nginx/conf.d/default.conf /usr/share/nginx/html/*

# FIXED: Adjusted file path lookups to run directly from your project root folder context
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./frontend /usr/share/nginx/html

# FIXED: Explicitly changes the master process pid file to the unprivileged path
RUN touch /tmp/nginx.pid && chown -R nginx:nginx /tmp/nginx.pid /usr/share/nginx/html /var/cache/nginx

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
