# algoliasearch 1.x は add_trust_ca で同梱の古い ca-bundle.crt のみを信頼するため、
# Algolia の現行証明書 (Sectigo) の検証に失敗する。システムの CA も併せて読み込む。
begin
  require 'httpclient'
rescue LoadError
  return
end

module AlgoliaSystemCA
  def add_trust_ca(trust_ca_file_or_hashed_dir)
    unless @system_ca_loaded
      @system_ca_loaded = true
      set_default_paths
    end
    super
  end
end

HTTPClient::SSLConfig.prepend(AlgoliaSystemCA)
