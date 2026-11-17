# Rack consumes this body incrementally. Passing a block to Active Storage keeps
# the original out of a single in-memory String, with no conversion or signed URL.
class MaterialDownloadBody
  def initialize(blob)
    @blob = blob
  end

  def each
    return enum_for(:each) unless block_given?

    @blob.download { |chunk| yield chunk }
  end
end
