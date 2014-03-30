class CreateDocuments < ActiveRecord::Migration
  def change
    create_table :documents do |t|
      # GUID for the Document
      t.string :guid

      # Content type of the Document
      # e.g. text/html, application/pdf, application/msword
      t.string :content_type

      # URL for the Document content
      # e.g. http://www.ci.watertown.ma.us/requesttracker.asp
      t.string :content_url, :limit => 510 # 2X the default

      # Persisted URL for the Document content
      # e.g. https://s3.amazonaws.com/hostname.production.watertown-town-ma/20a14f24f08773663840306bf8f06875
      t.string :persisted_url

      # HTTP Last-Modified
      # e.g. Fri, 30 Sep 2011 19:56:57 GMT
      t.date :last_modified

      # Extracted text of the referenced URL
      # e.g. might be HTML or text from PDF, PowerPoint
      t.text :extracted_text

      # Analysis of the extracted text
      t.text :analyzed_text

      # Title for the Document if one can be extracted
      # e.g. Watertown, MA - Official Website - Auditor
      t.string :title

      # Classification of the Document
      # e.g. agenda, minutes, notice, warning, etc.
      t.string :classification

      # Legislative body that created the Document
      # e.g. Town Council, Select Board, Planning Board
      t.string :legislative_body

      # Documents sometimes are published in DRAFT status
      # e.g. DRAFT, PROPOSAL
      t.string :status

      # The likely relevant date for this document
      # e.g. Fri, 30 Sep 2011 19:56:57 GMT
      t.date :likely_date

      # Processing state
      t.string :state

      # Processing state details
      t.text :state_details

      t.references :municipality
      t.timestamps
    end

    add_index(:documents, :guid)
    add_index(:documents, :content_type)
    add_index(:documents, :classification)
    add_index(:documents, :legislative_body)
    add_index(:documents, :likely_date)
    add_index(:documents, :status)
  end
end
