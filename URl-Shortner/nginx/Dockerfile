FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

# Relative to the ./URl-Shortner context directory
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY frontend /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
