# mlerner.github.io

Hello! This is the Github repo that backs [https://www.micahlerner.com](https://www.micahlerner.com), using [Github Pages](https://pages.github.com/).

The site is built and deployed with [Jekyll](https://jekyllrb.com/). 

## Developing

The first step in making changes to the site is running `bundle install`. This assumes that you have [Ruby](https://www.ruby-lang.org/en/) and the [bundler](https://bundler.io/) gem installed.

To start the Jekyll server locally, you can run `bundle exec jekyll serve -l -o`. See the [Jekyll docs](https://jekyllrb.com/docs/usage/) for more on usage.

To publish changes (assuming you have permissions), run `bundle exec rake publish`.