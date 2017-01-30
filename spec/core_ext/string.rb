class String
  # remove this when ruby 2.2 is no longer supported and we can use <<~
  def lstrip_lines
    gsub(/^ +/, '')
  end
end
