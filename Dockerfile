FROM ruby:4.0.4

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD ["bin/portfolio"]
