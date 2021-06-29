FROM ruby:3.0.1

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD bin/portfolio
