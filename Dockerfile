FROM ruby:3.4.6

WORKDIR /opt/app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD ["bin/portfolio"]
