json.id picture.id
json.caption picture.caption
json.image_attached picture.image.attached?
json.image_url picture.image.attached? ? rails_blob_path(picture.image, only_path: true) : nil
json.image_filename picture.image&.filename&.to_s
json.image_content_type picture.image&.content_type
json.image_byte_size picture.image&.byte_size
