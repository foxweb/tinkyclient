FROM ruby:3.0.2

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD bin/portfolio
