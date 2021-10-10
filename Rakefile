# CAREFUL! Changes made to this file aren't tested
#
# If you need new functionality, consider putting it in lib/rake
# and also adding tests, then calling that code from here
#
require "fileutils"
require "tmpdir"
require 'hatchet/tasks'
ENV["BUILDPACK_LOG_FILE"] ||= "tmp/buildpack.log"

require_relative 'lib/rake/deploy_check'
require_relative 'lib/rake/tarballer'

S3_BUCKET_NAME  = "heroku-buildpack-ruby"
GCS_BUCKET_NAME = "rp-heroku-buildpack-ruby"
VENDOR_URL      = "https://s3.amazonaws.com/#{S3_BUCKET_NAME}"

def s3_tools_dir
  File.expand_path("../support/s3", __FILE__)
end

def s3_upload(tmpdir, name)
  sh("#{s3_tools_dir}/s3 put #{S3_BUCKET_NAME} #{name}.tgz #{tmpdir}/#{name}.tgz")
end

def gcs_upload(tmpdir, name)
  sh("gsutil cp #{name}.tgz #{tmpdir}/#{name}.tgz gs://#{GCS_BUCKET_NAME}")
end

def vendor_plugin(git_url, branch = nil)
  name = File.basename(git_url, File.extname(git_url))
  Dir.mktmpdir("#{name}-") do |tmpdir|
    FileUtils.rm_rf("#{tmpdir}/*")

    Dir.chdir(tmpdir) do
      sh "git clone #{git_url} ."
      sh "git checkout origin/#{branch}" if branch
      FileUtils.rm_rf("#{name}/.git")
      sh("tar czvf #{tmpdir}/#{name}.tgz *")
      gcs_upload(tmpdir, name)
    end
  end
end

def in_gem_env(gem_home, &block)
  old_gem_home = ENV['GEM_HOME']
  old_gem_path = ENV['GEM_PATH']
  ENV['GEM_HOME'] = ENV['GEM_PATH'] = gem_home.to_s

  yield

  ENV['GEM_HOME'] = old_gem_home
  ENV['GEM_PATH'] = old_gem_path
end

def install_gem(gem_name, version)
  name = "#{gem_name}-#{version}"
  Dir.mktmpdir("#{gem_name}-#{version}") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      in_gem_env(tmpdir) do
        sh("unset RUBYOPT; gem install #{gem_name} --version #{version} --no-document --env-shebang")
        sh("rm #{gem_name}-#{version}.gem")
        sh("rm -rf cache/#{gem_name}-#{version}.gem")
        sh("tar czvf #{tmpdir}/#{name}.tgz *")
        sh("cp #{tmpdir}/#{name}.tgz #{File.dirname(__FILE__)}")
      end
    end
  end
end

namespace :buildpack do
  desc "releases the next version of the buildpack"
  task :release do
    deploy = DeployCheck.new(github: "heroku/heroku-buildpack-ruby")
    puts "Attempting to deploy #{deploy.next_version}, overwrite with RELEASE_VERSION env var"
    deploy.check!

    if deploy.push_tag?
      sh("git tag -f #{deploy.next_version}") do |out, status|
        raise "Could not `git tag -f #{deploy.next_version}`: #{out}" unless status.success?
      end
      sh("git push --tags") do |out, status|
        raise "Could not `git push --tags`: #{out}" unless status.success?
      end
    end

    command = "heroku buildpacks:publish heroku/ruby #{deploy.next_version}"
    puts "Releasing to heroku: `#{command}`"
    exec(command)
  end
  desc "stage a tarball of the buildpack, this runs on github actions to deploy CNB"
  task :tarball do
    tarballer = Tarballer.new(name: "heroku-buildpack-ruby", directory: __dir__)
    tarballer.call
  end
end

desc "update plugins"
task "plugins:update" do
  vendor_plugin "https://github.com/heroku/rails_log_stdout.git", "legacy"
  vendor_plugin "https://github.com/pedro/rails3_serve_static_assets.git"
  vendor_plugin "https://github.com/hone/rails31_enable_runtime_asset_compilation.git"
end

desc "install vendored gem"
task "gem:install", :gem, :version do |t, args|
  gem     = args[:gem]
  version = args[:version]

  install_gem(gem, version)
end

desc "generate ruby versions manifest"
task "ruby:manifest" do
  require 'rexml/document'
  require 'yaml'

  document = REXML::Document.new(`curl https://#{S3_BUCKET_NAME}.s3.amazonaws.com`)
  rubies   = document.elements.to_a("//Contents/Key").map {|node| node.text }.select {|text| text.match(/^(ruby|rbx|jruby)-\\\\d+\\\\.\\\\d+\\\\.\\\\d+(-p\\\\d+)?/) }

  Dir.mktmpdir("ruby_versions-") do |tmpdir|
    name = 'ruby_versions.yml'
    File.open(name, 'w') {|file| file.puts(rubies.to_yaml) }
    sh("#{s3_tools_dir}/s3 put #{S3_BUCKET_NAME} #{name} #{name}")
  end
end

namespace :download do
  desc "Download Ruby build for STACK and VERSION (e.g. heroku-18, 2.6.7)"
  task :ruby do
    stack = ENV.fetch('STACK', 'heroku-18')
    sh("wget https://s3-external-1.amazonaws.com/heroku-buildpack-ruby/#{stack}/ruby-#{ENV['VERSION']}.tgz")
  end

  desc "Download Node default version"
  task :node do
    sh("wget #{LanguagePack::Helpers::Nodebin.node_lts['url']}")
  end

  desc "Download Yarn default version"
  task :yarn do
    sh("wget #{LanguagePack::Helpers::Nodebin.yarn['url']}")
  end
end

begin
  require 'rspec/core/rake_task'

  desc "Run specs"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = %w(-fd --color)
    #t.ruby_opts  = %w(-w)
  end
  task :default => :spec
rescue LoadError
end
