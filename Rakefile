# Rake tasks for Jekyll
# Inspired by https://github.com/imathis/octopress/blob/master/Rakefile

require 'rake/clean'
require 'redcloth'
require 'stringex'
require 'jekyll'
require 'rake'
require 'rdoc'
require 'date'
require 'yaml'
require 'tmpdir'

I18n.config.available_locales = :en

POSTS_DIR = '_posts'
BOOKS_DIR = '_books'
FRAGMENTS_DIR = '_fragments'
BUILD_DIR = '_site'
DEPLOY_DIR = '_deploy'
DEPLOY_BRANCH = 'gh-pages'

CLEAN.include BUILD_DIR
CLOBBER.include DEPLOY_DIR

desc 'Build the site'
task :build do
  sh 'jekyll', 'build'
end

desc 'Start web server to preview site'
task :preview do
  sh 'jekyll', 'serve', '--watch', '--drafts',
     '--port', ENV.fetch('PORT', '4000')
end

desc 'Create a new draft'
task :new_draft, :title do |t, args|
  title = args[:title] || 'New Draft'
  filename = File.join('_drafts', "#{title.to_url}.md")

  puts "==> Creating new draft: #{filename}"
  open(filename, 'w') do |f|
    f << "---\n"
    f << "layout: post\n"
    f << "title: \"#{title.to_html(true)}\"\n"
    f << "comments: false\n"
    f << "categories:\n"
    f << "---\n"
    f << "\n"
    f << "Add awesome content here.\n"
  end
end

desc 'Create a new post'
task :new_post, :title do |t, args|
  title = args[:title] || 'New Post'

  timestamp = Time.now.strftime('%Y-%m-%d')
  filename = File.join(POSTS_DIR, "#{timestamp}-#{title.to_url}.md")

  puts "==> Creating new post: #{filename}"
  open(filename, 'w') do |f|
    f.write "---\n"
    f.write "layout: post\n"
    f.write "title: \"#{title.to_html(true)}\"\n"
    f.write "categories:\n"
    f.write "---\n"
    f.write "\n"
    f.write "Add awesome post content here.\n"
  end
end

desc 'Create a new book review'
task :new_book, :title do |t, args|
  title = args[:title] || 'New Book Review'

  timestamp = Time.now.strftime('%Y-%m-%d')
  filename = File.join(BOOKS_DIR, "#{timestamp}-#{title.to_url}.md")

  puts "==> Creating new book review: #{filename}"
  open(filename, 'w') do |f|
    f.write "---\n"
    f.write "layout: book\n"
    f.write "title: \"#{title.to_html(true)}\"\n"
    f.write "categories:\n"
    f.write "---\n"
    f.write "\n"
    f.write "Add awesome post content here.\n"
  end
end

desc 'Create a new fragment'
task :new_fragment, :title do |t, args|
  title = args[:title] || 'New Fragment'

  timestamp = Time.now.strftime('%Y-%m-%d')
  filename = File.join(FRAGMENTS_DIR, "#{timestamp}-#{title.to_url}.md")

  puts "==> Creating new fragment: #{filename}"
  open(filename, 'w') do |f|
    f.write "---\n"
    f.write "layout: post\n"
    f.write "title: \"#{title.to_html(true)}\"\n"
    f.write "categories:\n"
    f.write "---\n"
    f.write "\n"
    f.write "Add awesome post content here.\n"
  end
end


desc 'Create a new page'
task :new_page, :title do |t, args|
  title = args[:title] || 'New Page'
  filename = File.join(title.to_url, 'index.md')

  puts "==> Creating new page: #{filename}"
  mkdir_p title.to_url
  open(filename, 'w') do |f|
    f.write "---\n"
    f.write "layout: page\n"
    f.write "title: \"#{title.to_html(true)}\"\n"
    f.write "---\n"
    f.write "\n"
    f.write "Add awesome page content here.\n"
  end
end


desc "Generate blog files"
task :generate do
  Jekyll::Site.new(Jekyll.configuration({
    "source"      => ".",
    "destination" => "_site"
  })).process
end


desc "Generate and publish blog to gh-pages"
task :publish => [:generate] do
  Dir.mktmpdir do |tmp|
    system "mv _site/* #{tmp}"
    system "git checkout -B #{DEPLOY_BRANCH}"
    system "rm -rf *"
    system "mv #{tmp}/* ."
    message = "Site updated at #{Time.now.utc}"
    system "git add ."
    system "git commit -am #{message.shellescape}"
    system "git push origin gh-pages --force"
    system "git checkout master"
    system "rm -rf _site/"
    system "echo yolo"
  end
end

task :default => :publish
