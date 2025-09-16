FROM ruby:3.4.5

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD ["bin/portfolio"]
