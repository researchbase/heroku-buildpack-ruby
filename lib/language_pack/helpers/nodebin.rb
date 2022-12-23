require 'json'

class LanguagePack::Helpers::Nodebin
  def self.hardcoded_node_lts
    version = "16.18.1"
    {
      "number" => version,
      "url"    => "https://storage.googleapis.com/rp-heroku-buildpack-ruby/nodebin/node/release/linux-x64/node-v#{version}-linux-x64.tar.gz"
    }
  end

  def self.hardcoded_yarn
    version = "1.22.19"
    {
      "number" => version,
      "url"    => "https://storage.googleapis.com/rp-heroku-buildpack-ruby/nodebin/yarn/release/yarn-v#{version}.tar.gz"
    }
  end

  def self.node_lts
    hardcoded_node_lts
  end

  def self.yarn
    hardcoded_yarn
  end
end
