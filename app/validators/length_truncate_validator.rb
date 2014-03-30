# Validator that truncates an ActiveRecord property value based upon a
# configurable maximum size. For example:
#
# validates :title, :length_truncate => { :maximum => 10 }
class LengthTruncateValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    ml = options[:maximum]
    record.send("#{attribute}=", value.mb_chars.slice(0,ml)) if value.mb_chars.length > ml unless value.nil? or ml.nil?
  end

  class << self
    def maximum(record_class, attribute)
      ltv = record_class.validators_on(attribute).detect { |v| v.is_a?(LengthTruncateValidator) }
      ltv.options[:maximum] unless ltv.nil?
    end
  end
end