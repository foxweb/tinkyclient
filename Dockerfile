FROM ruby:3.0.1

ENV ${TINKOFF_OPENAPI_TOKEN}
WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD bin/portfolio
