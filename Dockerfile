FROM ruby:4.0.3

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD ["bin/portfolio"]
