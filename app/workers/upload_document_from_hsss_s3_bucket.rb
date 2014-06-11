# This worker copies the document at hsss_persisted_url (renamed in migration) to a new S3 bucket at persisted_url
class UploadDocumentFromHsssS3Bucket < Worker

  sidekiq_options queue: "low"
  sidekiq_options :retry => 1

  def run(document_id)
    document = Document.unscoped.find(document_id)

    # Calculate a unique key for the Document
    municipality = document.municipality
    key = "#{municipality.state.downcase}/#{municipality.name.downcase}/#{document.guid}"

    # Download the Document from renamed hsss_persisted_url S3 bucket
    response = @@http_client.get(document.hsss_persisted_url, :follow_redirect => true)
    if response.ok?
      # Upload the Document
      bucket = configure_s3_bucket
      file = bucket.files.create(:key    => key,
                                 :body   => response.body,
                                 :public => true)
      document.persisted_url = file.public_url.to_s
      document.save!
    else
      raise StandardError, "Error downloading file for upload (#{document.content_url}): (#{response.code})"
    end
  end

  # Configure and return an S3 bucket for Document storage.
  #
  # @return An S3 bucket for Document storage
  def configure_s3_bucket
    connection = Fog::Storage.new(:provider              => 'AWS',
                                  :aws_access_key_id     => Constants::S3_ACCESS_KEY_ID,
                                  :aws_secret_access_key => Constants::S3_SECRET_ACCESS_KEY)

    connection.directories.create(:key    => Constants::S3_BUCKET_NAME,
                                  :public => true)
  end
end
