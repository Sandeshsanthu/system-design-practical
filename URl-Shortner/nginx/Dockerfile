FROM nginx:alpine

# 1. Clear out default templates and configurations
RUN rm -rf /etc/nginx/conf.d/* /usr/share/nginx/html/*

# 2. Copy your custom main configuration and frontend assets into place
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./frontend /usr/share/nginx/html

# 3. Grant proper permissions to the unprivileged nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx

# 4. Switch context to the unprivileged user for runtime security
USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
