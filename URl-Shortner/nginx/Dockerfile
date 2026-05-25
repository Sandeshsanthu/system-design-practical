FROM nginx:alpine

# Clear out any default configs and landing templates
RUN rm -rf /etc/nginx/conf.d/default.conf /usr/share/nginx/html/*

# ALTERED: Paths are now direct because we are running build from inside the nginx/ directory
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./frontend /usr/share/nginx/html

# FIXED: Re-routes hidden default root PID files to /tmp/ and fixes unprivileged ownership
RUN sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf && \
    chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
