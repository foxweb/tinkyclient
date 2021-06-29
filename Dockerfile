FROM ruby:3.0.1

RUN apt-get update -qq && \
    apt-get install --allow-unauthenticated -y \
    ssh vim bash

ENV APP_PATH /opt/app
RUN mkdir -p $APP_PATH

WORKDIR ${APP_PATH}

COPY Gemfile* ./

RUN gem install bundler -v 2.2.20
RUN GIT_SSL_NO_VERIFY=true bundle install

COPY ./ ./
