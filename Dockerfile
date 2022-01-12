FROM ruby:3.1.0

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD bin/portfolio
