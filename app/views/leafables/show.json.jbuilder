json.partial! "leaves/leaf", leaf: @leaf

json.set!(leafable_json_key(@leaf)) do
  json.partial! leafable_json_partial(@leaf), **leafable_json_locals(@leaf)
end
